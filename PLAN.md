# AI Contact Card — Build Plan

> This is a living document. Update step status as work progresses.
> Claude Code: mark steps [x] when complete, add notes if needed.

## Phase 1: Foundation
Goal: Get data models working and display people/facts on screen.

- [x] **Step 1: Xcode project setup**
  Create Xcode project with SwiftUI + SwiftData. Verify it builds and runs on simulator showing the default template. Set deployment target to iOS 17.0.
  Files: `AIContactCardApp.swift`

- [x] **Step 2: SwiftData models**
  Create Person, Fact, and Entry models matching `docs/architecture.md` spec. Register them in the SwiftData model container. Verify build.
  Files: `Models/Person.swift`, `Models/Fact.swift`, `Models/Entry.swift`, update `AIContactCardApp.swift`

- [x] **Step 3: People list + detail views**
  Create PeopleListView showing all Person objects in a List with NavigationStack. Tapping navigates to PersonDetailView showing name, summary, and facts grouped by category. Add a TabView with People and Settings tabs as the root navigation.
  Files: `Views/PeopleListView.swift`, `Views/PersonDetailView.swift`, `Views/ContentView.swift`

- [x] **Step 4: Manual data entry**
  Add ability to create a Person (+ button → sheet with name field) and add Facts to a Person (+ button on detail → sheet with category picker + text field). This validates the data layer works end-to-end before adding AI.
  Files: `Components/AddPersonSheet.swift`, `Components/AddFactSheet.swift`, update detail view

## Phase 2: Voice + AI
Goal: Speak about someone, have AI extract structured data, store it.

- [x] **Step 5: Voice recording + transcription**
  Create VoiceService using Apple Speech framework. Request microphone + speech recognition permissions. Record audio, transcribe in real-time, return final transcript. Create RecordView with mic button and live transcript display.
  Files: `Services/VoiceService.swift`, `Views/RecordView.swift`, update `Info.plist` permissions

- [x] **Step 6: Cloudflare Worker proxy**
  Create the API proxy that accepts requests, adds the Claude API key for managed mode, and passes through for BYOK mode. Deploy to Cloudflare. Test with curl.
  Files: `proxy/src/index.js`, `proxy/wrangler.toml`, `proxy/package.json`

- [x] **Step 7: AIService + API client**
  Create APIClient for HTTP calls to the proxy. Create AIService with `extract()` and `query()` methods. Define response structs (ExtractionResult, ExtractedContact, ExtractedFact). Use prompts from `docs/prompts.md`. Handle errors gracefully.
  Files: `Services/AIService.swift`, `Utilities/APIClient.swift`

- [x] **Step 8: Ingest pipeline end-to-end**
  Wire RecordView → VoiceService → AIService.extract() → SwiftData storage. When user finishes recording, send transcript to AI, parse response, create/update Person and Fact objects. Show confirmation of what was extracted. This is the core feature — test thoroughly.
  Files: Update `Views/RecordView.swift`, possibly add `Components/ExtractionResultView.swift`

## Phase 3: Query + Contacts
Goal: Ask questions about your people. Integrate iPhone contacts.

- [x] **Step 9: Apple Contacts integration (read)**
  Create ContactSyncService that reads iPhone contacts via CNContactStore. Fetch name, nickname, organization, job title, emails, phones. Create ContactSummary struct. Request contacts permission and handle denial.
  Files: `Services/ContactSyncService.swift`, update `Info.plist` permissions

- [x] **Step 10: Contact matching in extraction**
  Update AIService.extract() prompt to include Apple Contacts as context. When AI identifies a match between a mentioned person and an existing contact, link the Person to the Apple Contact via contactIdentifier. Update extraction prompt in `docs/prompts.md`.
  Files: Update `Services/AIService.swift`, update `docs/prompts.md`

- [x] **Step 11: Chat view + query pipeline**
  Create ChatView with a conversation-style interface. User types or speaks a question. Send to AIService.query() with all stored People/Facts and Apple Contacts as context. Display AI response. Support both text and voice input.
  Files: `Views/ChatView.swift`, `Components/MessageBubble.swift`, update TabView

- [x] **Step 12: Write summaries back to contacts (optional)**
  If a Person is linked to an Apple Contact, add a button in PersonDetailView to write the AI-generated summary into that contact's Notes field. Make this opt-in per contact. Add a global toggle in Settings.
  Files: Update `Services/ContactSyncService.swift`, update `Views/PersonDetailView.swift`

## Phase 4: Credits + Polish
Goal: Billing works. Settings complete. App feels finished.

- [x] **Step 13: CreditManager**
  Create CreditManager as @Observable class. Store balance in UserDefaults. Methods: consume() → Bool, add(amount), grantFreeCreditsIfNeeded() (50 free on first launch). Properties: hasCredits, isLow. Wire into AIService so every API call checks credits first. Show purchase prompt when empty.
  Files: `Services/CreditManager.swift`, update `Services/AIService.swift`

- [x] **Step 14: StoreKit 2 credit packs**
  Add four consumable IAP products (100/600/1500/4000 credits). Create StoreKit Configuration File for testing. Implement purchase flow in CreditManager. Create CreditsView showing balance and purchase buttons with pricing.
  Files: Update `Services/CreditManager.swift`, `Views/CreditsView.swift`, add `AIContactCard/StoreKitConfig.storekit`

- [x] **Step 15: BYOK API key option**
  Add toggle in Settings between managed credits and BYOK. When BYOK, show SecureField for Anthropic API key. Store key in Keychain. Pass mode:"byok" to proxy. Skip credit checks when BYOK is active.
  Files: `Utilities/KeychainHelper.swift`, update `Views/SettingsView.swift`, update `Services/AIService.swift`

- [x] **Step 16: Settings view**
  Create SettingsView with sections: API mode (credits vs BYOK), credit balance + buy button, contact sync preferences, app info/version. Wire into TabView.
  Files: `Views/SettingsView.swift`, update `Views/ContentView.swift`

## Phase 5: Ship
Goal: App Store ready.

- [x] **Step 17: App icon + launch screen**
  Design and add app icon to asset catalog (1024x1024 master). Create a simple launch screen.
  Files: `Assets.xcassets`, `LaunchScreen`

- [x] **Step 18: Onboarding flow**
  First-launch experience: 3 swipeable screens explaining the app, then request microphone, speech, and contacts permissions in sequence. Grant 50 free credits. Navigate to main app. Use PageTabViewStyle.
  Files: `Views/OnboardingView.swift`, update `AIContactCardApp.swift`

- [x] **Step 19: Edge cases + error handling**
  Review all views for: empty states (no people, no facts, no credits), error states (API failure, network offline, permission denied), loading states during AI calls. Add retry for failed API calls. Add low-credit banner component.
  Files: `Components/EmptyStateView.swift`, `Components/CreditBanner.swift`, updates across views

## Phase 6: Security Hardening
Goal: Fix all vulnerabilities and compliance gaps before App Store submission.

### Mandatory — App Store Blockers

- [x] **Step 20: Privacy Policy & Disclosure**
  Write a privacy policy covering: data collected (transcripts, contacts, facts), third-party processing (Anthropic Claude API, Cloudflare), data retention, user rights (access, deletion). Host it at a public URL. Add a link in SettingsView. Fix misleading onboarding text — replace "All processing stays on your device" with accurate disclosure that transcripts and contact names are sent to Anthropic's AI for processing. Add explicit consent step before first API call.
  Files: `Views/OnboardingView.swift`, `Views/SettingsView.swift`, privacy policy document

- [ ] **Step 21: Proxy Authentication**
  Add request signing to prevent unauthorized use of the proxy. Generate a shared secret, embed it in the app, sign each request with HMAC-SHA256. Proxy validates signature before forwarding. This prevents anyone without the app from using your API key.
  Files: `proxy/src/index.js`, `Utilities/APIClient.swift`

- [ ] **Step 22: Proxy Rate Limiting & Model Whitelist**
  Add per-IP rate limiting using Cloudflare Workers KV (e.g. 30 requests/minute). Whitelist allowed models to `claude-sonnet-4-5-20250929` only — reject any other model value. Add request timeout via AbortController (30s).
  Files: `proxy/src/index.js`, `proxy/wrangler.toml`

- [ ] **Step 23: Server-Side Credit Enforcement**
  Move credit tracking to the proxy. Store per-device credit balances in Cloudflare KV. Proxy checks balance before forwarding to Claude API, deducts after response. App sends a device identifier with each request. This eliminates all client-side credit tampering.
  Files: `proxy/src/index.js`, `proxy/wrangler.toml`, `Utilities/APIClient.swift`, `Services/CreditManager.swift`, `Services/AIService.swift`

### High Priority — Significant Risk

- [ ] **Step 24: Server-Side Purchase Verification**
  When a StoreKit purchase completes, send the transaction JWS to the proxy for verification using Apple's App Store Server API. Proxy validates the signed transaction, then credits the device balance in KV. Remove client-side credit granting.
  Files: `proxy/src/index.js`, `Services/CreditManager.swift`

- [ ] **Step 25: Thread-Safe CreditManager**
  Convert CreditManager to a Swift Actor or add serial DispatchQueue to prevent race conditions on balance mutations. Ensure `hasCredits` check and `deduct()` are atomic — reserve credits before the API call, release or confirm after.
  Files: `Services/CreditManager.swift`, `Services/AIService.swift`

- [ ] **Step 26: Sanitize Error Messages**
  Map HTTP error codes to user-friendly messages. Never show raw API response bodies. Log full error details locally for debugging but display only generic messages in the UI (e.g. "Request failed — please try again").
  Files: `Utilities/APIClient.swift`, `Services/AIService.swift`

- [ ] **Step 27: StoreKit Transaction Deduplication**
  Store processed transaction IDs (in UserDefaults or Keychain) to prevent double-crediting on app restart. Check transaction ID before granting credits. Handle `Transaction.updates` edge cases (crash between verify and finish).
  Files: `Services/CreditManager.swift`

### Medium Priority — Should Address

- [ ] **Step 28: Prompt Injection Mitigation**
  Sanitize transcript and contact data before embedding in Claude prompts. Escape triple-quote sequences, limit transcript length with a hard character cap, use JSON encoding rather than string interpolation for structured data in prompts.
  Files: `Services/AIService.swift`

- [ ] **Step 29: Keychain Hardening**
  Add `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to all Keychain operations so API keys cannot be extracted via device backup/restore. Clear BYOK key from @State memory when SettingsView disappears.
  Files: `Utilities/KeychainHelper.swift`, `Views/SettingsView.swift`

- [ ] **Step 30: Data Management & GDPR Compliance**
  Add data export (JSON) in Settings so users can download all their stored data. Add "Delete All Data" option. Add data retention — auto-delete Entry (transcript) records older than 90 days. Show transcript deletion option per-entry.
  Files: `Views/SettingsView.swift`, new `Utilities/DataExporter.swift`

- [ ] **Step 31: Remove CORS & Tighten Proxy Headers**
  Remove `Access-Control-Allow-Origin: *` from proxy (not a web API). Add User-Agent validation to only accept requests from the iOS app. Remove any unnecessary response headers.
  Files: `proxy/src/index.js`

- [ ] **Step 32: Free Credits Abuse Prevention**
  Tie free credit grant to a server-side device ID check (via proxy + KV). Each device gets free credits once, enforced server-side. Cannot be reset by reinstalling the app.
  Files: `proxy/src/index.js`, `Services/CreditManager.swift`

---

## Phase 7: Ship

- [ ] **Step 33: TestFlight beta**
  Archive in Xcode, upload to App Store Connect. Set up TestFlight. Create IAP products in App Store Connect matching StoreKit config. Invite beta testers.
  Manual process — no code changes.

- [ ] **Step 34: App Store submission**
  Write App Store description, keywords. Link privacy policy URL. Take screenshots on multiple device sizes. Submit for review.
  Files: Marketing copy — Claude can help draft these.

---

## Notes
- Commit to git after every completed step
- Use `/clear` in Claude Code between steps to keep context fresh
- If a step fails, revert the git commit and retry with a refined approach
- Update `docs/known-issues.md` whenever Claude Code makes a repeated mistake
