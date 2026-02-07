# Known Issues — Claude Code Patterns to Watch For

> **PURPOSE:** This file tracks patterns where Claude Code repeatedly makes mistakes
> in this project. Before coding any step, Claude Code should read this file.
> After encountering a repeated mistake, add it here immediately.
>
> This file is referenced in CLAUDE.md and is part of Claude Code's context.

## Swift / SwiftUI

- **Use `@Observable`, not `ObservableObject`**: We use the iOS 17+ `@Observable` macro from the Observation framework. Never use `ObservableObject`, `@Published`, or `@ObservedObject`. Use `@State` in views to hold `@Observable` objects if needed, or inject via `.environment()`.

- **Use `NavigationStack`, not `NavigationView`**: `NavigationView` is deprecated. Always use `NavigationStack` with `NavigationLink(value:)` and `.navigationDestination(for:)`.

- **SwiftData `@Query` is view-only**: Use `@Query` in SwiftUI views to fetch data. For writes, use `modelContext.insert()` and `modelContext.delete()`. Never try to use `@Query` inside a service class.

- **`@Model` classes must have default values**: Every property in a `@Model` class needs either a default value or to be set in `init()`. Optional properties should default to `nil`. Arrays should default to `[]`.

- **Don't use `\n` in SwiftUI Text**: If you need multiline text, use separate `Text` views in a `VStack`, not newline characters.

## SwiftData Specifics

- **Don't change model schemas casually**: Changing property names or types on `@Model` classes causes migration issues. If you must change a schema during development, delete the app from the simulator first to clear the database.

- **`@Relationship` needs explicit delete rules**: Always specify `.cascade` or `.nullify` on `@Relationship` properties. The default behaviour can be unpredictable.

- **Model container setup**: The `modelContainer` modifier goes on the `WindowGroup` in the App struct, not on individual views.

## Apple Frameworks

- **Speech framework doesn't work in Simulator**: Apple Speech requires a real device for actual transcription. In simulator, the UI should still work but transcription will fail silently or return empty. Handle this gracefully.

- **CNContactStore permission must be requested before access**: Always call `requestAccess(for: .contacts)` and check the result before calling `enumerateContacts`. Handle denial gracefully with an explanation.

- **StoreKit 2 testing requires a StoreKit Configuration File**: Create an `.storekit` file in Xcode for testing purchases in the simulator. Real purchases only work on TestFlight or production.

## API / Networking

- **Extraction uses structured outputs — no backtick stripping needed**: The extraction flow uses Claude's `output_config.format` with a JSON schema. The response is guaranteed valid JSON. Do NOT add code to strip markdown backticks or handle malformed JSON for extraction calls. Query calls return free-form text and do not use structured outputs.

- **Use the pinned model string**: Always use `claude-sonnet-4-5-20250929`, never a `latest` alias. This ensures consistent behaviour across app updates.

- **Handle network errors gracefully**: The proxy or Claude API may be slow or unavailable. Always wrap API calls in do/catch, show user-friendly errors, and offer retry.

- **Don't hardcode the proxy URL**: Store it as a constant in a config file or at the top of APIClient.swift so it's easy to change.

- **APIClient has two methods**: `send()` for query calls (free-form text response), `sendStructured()` for extraction calls (includes `output_config` in request body). Do not mix them up.

## General Claude Code Behaviour

- **Scope creep**: Claude Code tends to "improve" files outside the current task. If asked to work on ChatView, it may also refactor PeopleListView. Always specify: "Only modify [specific files]. Do not change any other files."

- **Over-engineering**: Claude Code may add abstraction layers, protocols, or generic types that aren't needed for this small app. Prefer concrete, simple implementations.

- **Deprecated API usage**: Claude's training data includes older Swift/SwiftUI patterns. Watch for: `@StateObject` (use `@State`), `ObservableObject` (use `@Observable`), `NavigationView` (use `NavigationStack`), `.task { }` misuse.

- **Missing imports**: Claude sometimes forgets to add `import SwiftData`, `import Contacts`, or `import Speech` at the top of files. Always check imports if you get "cannot find type" errors.

---

## How to Add New Issues

When Claude Code makes a mistake that you've corrected, add it here in the format:

```
- **Short description**: Detailed explanation of what went wrong and what the correct
  approach is. Include the wrong pattern and the right pattern if applicable.
```

Then mention the update to Claude Code so it reads the file on the next step.
