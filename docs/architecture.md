# Technical Architecture

> Build reference. See `docs/prompts.md` for AI prompt text.
> See `docs/known-issues.md` for patterns to avoid.

## System Diagram

```
iPhone App (Swift / SwiftUI / SwiftData)
│
├── UI Layer ──────── Views (SwiftUI)
├── Service Layer ─── VoiceService, AIService, ContactSyncService, CreditManager
├── Data Layer ────── SwiftData (Person, Fact, Entry) + CNContactStore (read/write)
│
└── Network (HTTPS only)
    └── Cloudflare Worker proxy → Claude API (Anthropic)
```

## Tech Stack

| Layer            | Technology             | Min Version   |
|------------------|------------------------|---------------|
| Language         | Swift 5.9+             |               |
| UI               | SwiftUI                | iOS 17.0      |
| Local DB         | SwiftData              | iOS 17.0      |
| Speech-to-Text   | Apple Speech framework | iOS 17.0      |
| Contacts         | CNContactStore         | iOS 17.0      |
| In-App Purchase  | StoreKit 2             | iOS 17.0      |
| AI               | Claude API (Sonnet 4.5)| See AI Model Strategy |
| Proxy            | Cloudflare Worker (JS) |               |

Deployment target: **iOS 17.0**
Third-party Swift packages: **None. Apple frameworks only.**

---

## AI Model Strategy

### v1: Sonnet 4.5 for Everything

| | Model | Model String | Input/1M | Output/1M |
|---|---|---|---|---|
| **v1 (launch)** | Claude Sonnet 4.5 | `claude-sonnet-4-5-20250929` | $3.00 | $15.00 |

Pin to `claude-sonnet-4-5-20250929` — not a latest alias. Ensures consistent behaviour across app updates.

**Why Sonnet 4.5 over Haiku 4.5 ($1/$5):**
- Extraction from messy voice transcripts requires multi-person disambiguation ("Jerry" = "Jeremy Smith at Goldman"?) — Haiku misses wiring details on ambiguous input
- Query reasoning across hundreds of contacts needs consistent multi-step logic
- Cost difference per call is ~$0.01–0.05 — not material at consumer scale
- Extraction errors damage user trust permanently; saving pennies isn't worth it

**Why not Opus 4.5 ($5/$25):**
- Opus excels at long-horizon agentic tasks (multi-step planning, autonomous coding)
- This app sends single prompt → single response — Sonnet handles this pattern well
- 67% more expensive than Sonnet with marginal quality gain for this use case

### v2 Optimisation: Hybrid Model Routing

Once real usage data exists, route by task complexity:

| Task | Model | Trigger |
|---|---|---|
| Simple extraction (1-2 people, short transcript) | Haiku 4.5 | transcript < 200 words, no ambiguous names |
| Complex extraction (3+ people, disambiguation) | Sonnet 4.5 | transcript ≥ 200 words or multiple names |
| Direct fact lookup ("what's Jerry's email?") | Haiku 4.5 | question matches single-person pattern |
| Reasoning query ("who should I introduce to my investor?") | Sonnet 4.5 | open-ended or multi-person question |

This cuts API costs ~60% on simple tasks. Do not build this for v1.

### Structured Outputs

Use the Claude API structured outputs feature for extraction calls. This guarantees valid JSON conforming to your schema — no backtick stripping, no malformed JSON handling.

**Extraction calls** use `output_config.format` with a JSON schema:

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 2048,
  "messages": [{ "role": "user", "content": "..." }],
  "output_config": {
    "format": {
      "type": "json_schema",
      "schema": {
        "type": "object",
        "properties": {
          "contacts": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "name": { "type": "string" },
                "matched_person_id": { "type": ["string", "null"] },
                "matched_contact_id": { "type": ["string", "null"] },
                "aliases": { "type": "array", "items": { "type": "string" } },
                "facts": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "category": { "type": "string" },
                      "content": { "type": "string" }
                    },
                    "required": ["category", "content"]
                  }
                }
              },
              "required": ["name", "aliases", "facts"]
            }
          }
        },
        "required": ["contacts"],
        "additionalProperties": false
      }
    }
  }
}
```

**Query calls** do NOT use structured outputs — they return free-form natural language text. Use standard `max_tokens` only.

### Cost Per Call (Sonnet 4.5)

| Action | Input tokens | Output tokens | Cost |
|---|---|---|---|
| Extraction (short, 200 contacts) | ~8,000 | ~500 | ~$0.03 |
| Extraction (long, 500 contacts) | ~20,000 | ~800 | ~$0.07 |
| Query (heavy user, 300 people + 500 contacts) | ~40,000 | ~300 | ~$0.12 |
| Query (light user, 50 people) | ~5,000 | ~200 | ~$0.02 |
| **Blended average per credit** | | | **~$0.05–0.08** |

### Credit Pack Margin Analysis

| Pack | User Pays | Apple Takes (30%) | You Receive | API Cost (600 calls × $0.06) | Your Margin |
|---|---|---|---|---|---|
| Standard (600 credits) | £4.99 | £1.50 | £3.49 | ~£2.88 | ~£0.61 |

Margins are thin on heavy users, positive on light users. Monitor average cost-per-call in production. Adjust credit amounts or pricing if blended average exceeds £0.005/credit.

---

## Data Models (SwiftData)

### Person

```swift
@Model
class Person {
    var id: UUID = UUID()
    var name: String
    var aliases: [String] = []
    var contactIdentifier: String? = nil   // links to CNContact.identifier
    var summary: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade)
    var facts: [Fact] = []
}
```

### Fact

```swift
@Model
class Fact {
    var id: UUID = UUID()
    var category: String       // see category list below
    var content: String        // one atomic fact
    var rawTranscript: String = ""
    var createdAt: Date = Date()

    var person: Person?
}
```

Valid categories: `work`, `family`, `interests`, `location`, `education`, `personality`, `relationship`, `health`, `events`, `appearance`, `preferences`, `other`

### Entry

```swift
@Model
class Entry {
    var id: UUID = UUID()
    var transcript: String
    var createdAt: Date = Date()
}
```

### Model Container Setup

Register all three models in `AIContactCardApp.swift`:

```swift
@main
struct AIContactCardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Person.self, Fact.self, Entry.self])
    }
}
```

---

## Apple Contacts Integration

### ContactSummary (passed to AI as context)

```swift
struct ContactSummary: Codable {
    let identifier: String
    let fullName: String
    let nickname: String
    let organization: String
    let jobTitle: String
    let emails: [String]
    let phones: [String]
}
```

### CNContactStore Keys to Fetch

```swift
let keysToFetch: [CNKeyDescriptor] = [
    CNContactIdentifierKey,
    CNContactGivenNameKey,
    CNContactFamilyNameKey,
    CNContactNicknameKey,
    CNContactOrganizationNameKey,
    CNContactJobTitleKey,
    CNContactEmailAddressesKey,
    CNContactPhoneNumbersKey,
    CNContactNoteKey
] as [CNKeyDescriptor]
```

### Contact Operations

| Operation         | Method                                     | When                          |
|-------------------|--------------------------------------------|-------------------------------|
| Request access    | `store.requestAccess(for: .contacts)`      | Before any contact access     |
| Fetch all         | `store.enumerateContacts(with:)`           | On app launch, cache results  |
| Write note        | `store.execute(CNSaveRequest)` with update | User opt-in per contact       |

---

## Service Layer

All services are `@Observable` classes injected into the SwiftUI environment from `AIContactCardApp.swift`.

### AIService

```swift
@Observable
class AIService {
    static let model = "claude-sonnet-4-5-20250929"

    func extract(transcript: String, people: [Person], contacts: [ContactSummary]) async throws -> ExtractionResult
    func query(question: String, people: [Person], contacts: [ContactSummary]) async throws -> String
}
```

`extract()` sends request with `output_config.format` (structured outputs). Response is guaranteed valid JSON matching ExtractionResult schema.

`query()` sends standard request. Response is free-form text in `data.content[0].text`.

### ExtractionResult (response from Claude API)

```swift
struct ExtractionResult: Codable {
    let contacts: [ExtractedContact]
}

struct ExtractedContact: Codable {
    let name: String
    let matchedPersonId: String?
    let matchedContactId: String?
    let aliases: [String]
    let facts: [ExtractedFact]
}

struct ExtractedFact: Codable {
    let category: String
    let content: String
}
```

JSON keys from the API use snake_case. Use `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`.

### VoiceService

```swift
@Observable
class VoiceService {
    var isRecording: Bool = false
    var transcript: String = ""

    func startRecording() throws
    func stopRecording() -> String
}
```

Uses `SFSpeechRecognizer` + `AVAudioEngine`. On-device, no network.

### ContactSyncService

```swift
@Observable
class ContactSyncService {
    var allContacts: [ContactSummary] = []

    func requestAccess() async -> Bool
    func fetchAllContacts()
    func updateContactNote(identifier: String, note: String) throws
}
```

### CreditManager

```swift
@Observable
class CreditManager {
    var balance: Int                    // UserDefaults key: "credit_balance"
    var hasCredits: Bool
    var isLow: Bool                    // balance > 0 && balance <= 15

    func consume() -> Bool             // deduct 1, return false if empty
    func add(_ amount: Int)
    func grantFreeCreditsIfNeeded()    // 50 free, flag: "free_credits_granted"
    func purchase(_ product: Product) async throws
}
```

### APIClient

```swift
struct APIClient {
    static let proxyURL = "https://ai-contact-card-proxy.YOUR-ACCOUNT.workers.dev"

    /// Standard call (query) — returns free-form text
    static func send(messages: [[String: Any]], mode: String, apiKey: String?) async throws -> Data

    /// Structured call (extraction) — includes output_config for guaranteed JSON
    static func sendStructured(messages: [[String: Any]], outputSchema: [String: Any], mode: String, apiKey: String?) async throws -> Data
}
```

Two methods. `send()` for queries (free-form response). `sendStructured()` for extraction (includes `output_config.format` in request body, proxy passes it through to Claude API).

---

## Core Flows

### Ingest Flow

```
RecordView.mic tap
→ VoiceService.startRecording()
→ VoiceService.stopRecording() → transcript
→ Save Entry(transcript) to SwiftData
→ CreditManager.consume() — false? show CreditsView, abort
→ AIService.extract(transcript, people, contacts)
    → APIClient.sendStructured() → proxy → Claude API (with output_config)
    → Response is guaranteed valid JSON
    → Decode ExtractionResult directly (no backtick stripping needed)
→ For each ExtractedContact:
    matchedPersonId != nil → find Person, append Facts
    matchedContactId != nil → create Person(contactIdentifier:), add Facts
    else → create new Person, add Facts
→ Show ExtractionResultView
```

### Query Flow

```
ChatView.send(question)
→ CreditManager.consume() — false? show CreditsView, abort
→ AIService.query(question, people, contacts)
    → APIClient.send() → proxy → Claude API (standard, no output_config)
    → Parse response: data.content[0].text → String
→ Append to chat messages array
→ Display in ChatView
```

### Contact Sync Flow

```
App launch → ContentView.onAppear
→ ContactSyncService.requestAccess()
→ ContactSyncService.fetchAllContacts()
→ allContacts cached in memory (re-fetched each launch)
```

---

## Cloudflare Worker Proxy

**File:** `proxy/src/index.js`

### Request Schema

```json
{
  "mode": "managed | byok",
  "apiKey": "sk-ant-... (byok only)",
  "messages": [{ "role": "user", "content": "..." }],
  "model": "claude-sonnet-4-5-20250929",
  "output_config": { ... } // optional, passed through for structured outputs
}
```

### Implementation

```javascript
export default {
  async fetch(request, env) {
    const { mode, apiKey, messages, model, output_config } = await request.json();
    const key = (mode === "byok" && apiKey) ? apiKey : env.CLAUDE_API_KEY;

    // Build request body — pass through output_config if present
    const body = {
      model: model || "claude-sonnet-4-5-20250929",
      max_tokens: 2048,
      messages,
    };
    if (output_config) {
      body.output_config = output_config;
    }

    return fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": key,
        "content-type": "application/json",
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });
  },
};
```

### wrangler.toml

```toml
name = "ai-contact-card-proxy"
main = "src/index.js"
compatibility_date = "2024-01-01"
```

### Secrets

```bash
wrangler secret put CLAUDE_API_KEY
```

---

## Credit System

### StoreKit 2 Products (Consumable)

| Product ID                          | Credits | Price  |
|-------------------------------------|---------|--------|
| `com.aicontactcard.credits.100`     | 100     | £0.99  |
| `com.aicontactcard.credits.600`     | 600     | £4.99  |
| `com.aicontactcard.credits.1500`    | 1,500   | £11.99 |
| `com.aicontactcard.credits.4000`    | 4,000   | £29.99 |

### Credit Logic

- 50 free on first launch (check `UserDefaults` flag `free_credits_granted`)
- `CreditManager.consume()` called before every AI call
- Returns false → present `CreditsView` as sheet, do not call API
- BYOK mode bypasses all credit checks

### Storage Keys

| Key                    | Store        | Value                    |
|------------------------|--------------|--------------------------|
| `credit_balance`       | UserDefaults | Int                      |
| `free_credits_granted` | UserDefaults | Bool                     |
| `api_mode`             | UserDefaults | String: "managed"/"byok" |
| `onboarding_complete`  | UserDefaults | Bool                     |
| BYOK API key           | Keychain     | String                   |

---

## Info.plist Permissions

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Record voice notes about people you know</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Convert your voice notes to text</string>
<key>NSContactsUsageDescription</key>
<string>Match people you mention with your existing contacts</string>
```

---

## Navigation Structure

```
AIContactCardApp
└── WindowGroup + .modelContainer
    └── if !onboarding_complete → OnboardingView
        else → ContentView (TabView)
            ├── Tab 1: RecordView (mic.fill)
            ├── Tab 2: ChatView (bubble.left.and.bubble.right.fill)
            ├── Tab 3: NavigationStack
            │   └── PeopleListView → PersonDetailView
            └── Tab 4: SettingsView (gear)
                    └── CreditsView (pushed or sheet)
```

---

## File Map

```
AIContactCard/
├── AIContactCardApp.swift
├── Models/
│   ├── Person.swift
│   ├── Fact.swift
│   └── Entry.swift
├── Services/
│   ├── AIService.swift
│   ├── VoiceService.swift
│   ├── ContactSyncService.swift
│   └── CreditManager.swift
├── Views/
│   ├── ContentView.swift
│   ├── RecordView.swift
│   ├── ChatView.swift
│   ├── PeopleListView.swift
│   ├── PersonDetailView.swift
│   ├── CreditsView.swift
│   ├── SettingsView.swift
│   └── OnboardingView.swift
├── Components/
│   ├── AddPersonSheet.swift
│   ├── AddFactSheet.swift
│   ├── MessageBubble.swift
│   ├── ExtractionResultView.swift
│   ├── CreditBanner.swift
│   └── EmptyStateView.swift
├── Utilities/
│   ├── APIClient.swift
│   └── KeychainHelper.swift
└── AIContactCard.storekit
```

---

## Prompt Size Budget

| Component                        | Tokens   |
|----------------------------------|----------|
| 500 Apple Contacts               | ~17,500  |
| 300 People + 1,000 Facts         | ~20,000  |
| Voice transcript                 | ~200–500 |
| System prompt                    | ~500     |
| **Total**                        | **~38K** |
| Claude Sonnet 4.5 context window | 200K (1M with beta header) |
| **Utilisation**                   | **~19%** |

No vector search needed for v1. v2 optimisation: add `NLEmbedding` pre-filter in front of AIService calls if users exceed 1,000+ contacts / 3,000+ facts.
