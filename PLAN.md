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

- [ ] **Step 9: Apple Contacts integration (read)**
  Create ContactSyncService that reads iPhone contacts via CNContactStore. Fetch name, nickname, organization, job title, emails, phones. Create ContactSummary struct. Request contacts permission and handle denial.
  Files: `Services/ContactSyncService.swift`, update `Info.plist` permissions

- [ ] **Step 10: Contact matching in extraction**
  Update AIService.extract() prompt to include Apple Contacts as context. When AI identifies a match between a mentioned person and an existing contact, link the Person to the Apple Contact via contactIdentifier. Update extraction prompt in `docs/prompts.md`.
  Files: Update `Services/AIService.swift`, update `docs/prompts.md`

- [ ] **Step 11: Chat view + query pipeline**
  Create ChatView with a conversation-style interface. User types or speaks a question. Send to AIService.query() with all stored People/Facts and Apple Contacts as context. Display AI response. Support both text and voice input.
  Files: `Views/ChatView.swift`, `Components/MessageBubble.swift`, update TabView

- [ ] **Step 12: Write summaries back to contacts (optional)**
  If a Person is linked to an Apple Contact, add a button in PersonDetailView to write the AI-generated summary into that contact's Notes field. Make this opt-in per contact. Add a global toggle in Settings.
  Files: Update `Services/ContactSyncService.swift`, update `Views/PersonDetailView.swift`

## Phase 4: Credits + Polish
Goal: Billing works. Settings complete. App feels finished.

- [ ] **Step 13: CreditManager**
  Create CreditManager as @Observable class. Store balance in UserDefaults. Methods: consume() → Bool, add(amount), grantFreeCreditsIfNeeded() (50 free on first launch). Properties: hasCredits, isLow. Wire into AIService so every API call checks credits first. Show purchase prompt when empty.
  Files: `Services/CreditManager.swift`, update `Services/AIService.swift`

- [ ] **Step 14: StoreKit 2 credit packs**
  Add four consumable IAP products (100/600/1500/4000 credits). Create StoreKit Configuration File for testing. Implement purchase flow in CreditManager. Create CreditsView showing balance and purchase buttons with pricing.
  Files: Update `Services/CreditManager.swift`, `Views/CreditsView.swift`, add `AIContactCard/StoreKitConfig.storekit`

- [ ] **Step 15: BYOK API key option**
  Add toggle in Settings between managed credits and BYOK. When BYOK, show SecureField for Anthropic API key. Store key in Keychain. Pass mode:"byok" to proxy. Skip credit checks when BYOK is active.
  Files: `Utilities/KeychainHelper.swift`, update `Views/SettingsView.swift`, update `Services/AIService.swift`

- [ ] **Step 16: Settings view**
  Create SettingsView with sections: API mode (credits vs BYOK), credit balance + buy button, contact sync preferences, app info/version. Wire into TabView.
  Files: `Views/SettingsView.swift`, update `Views/ContentView.swift`

## Phase 5: Ship
Goal: App Store ready.

- [ ] **Step 17: App icon + launch screen**
  Design and add app icon to asset catalog (1024x1024 master). Create a simple launch screen.
  Files: `Assets.xcassets`, `LaunchScreen`

- [ ] **Step 18: Onboarding flow**
  First-launch experience: 3 swipeable screens explaining the app, then request microphone, speech, and contacts permissions in sequence. Grant 50 free credits. Navigate to main app. Use PageTabViewStyle.
  Files: `Views/OnboardingView.swift`, update `AIContactCardApp.swift`

- [ ] **Step 19: Edge cases + error handling**
  Review all views for: empty states (no people, no facts, no credits), error states (API failure, network offline, permission denied), loading states during AI calls. Add retry for failed API calls. Add low-credit banner component.
  Files: `Components/EmptyStateView.swift`, `Components/CreditBanner.swift`, updates across views

- [ ] **Step 20: TestFlight beta**
  Archive in Xcode, upload to App Store Connect. Set up TestFlight. Create IAP products in App Store Connect matching StoreKit config. Invite beta testers.
  Manual process — no code changes.

- [ ] **Step 21: App Store submission**
  Write App Store description, keywords, privacy policy. Take screenshots on multiple device sizes. Submit for review.
  Files: Marketing copy — Claude can help draft these.

---

## Notes
- Commit to git after every completed step
- Use `/clear` in Claude Code between steps to keep context fresh
- If a step fails, revert the git commit and retry with a refined approach
- Update `docs/known-issues.md` whenever Claude Code makes a repeated mistake
