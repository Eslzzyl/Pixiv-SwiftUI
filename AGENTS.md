## Build Commands

```bash
# macOS build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# iOS Simulator build (iPhone 17)
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# Full verbose build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=macOS' build
```

## SwiftLint

Both Homebrew installation and project plugin are available. Use whichever is convenient.

```bash
# Autofix safe issues
swiftlint --fix

# Run linting and show all issues
swiftlint lint
```

### Suppressing Rules
Use comments to disable rules inline:
```swift
// swiftlint:disable identifier_name
let w = 100
// swiftlint:enable identifier_name

// Disable for entire file at top
// swiftlint:disable cyclomatic_complexity
```

## Code Standards

### Language & Environment
- **Language**: Swift 6.0
- **Frameworks**: SwiftUI, SwiftData, Observation
- **Platforms**: iOS 17+, macOS 14+

### Naming Conventions
- **Types** (classes, structs, enums): PascalCase (e.g., `IllustStore`, `UserModel`)
- **Properties & Methods**: camelCase (e.g., `isLoading`, `fetchData()`)
- **Store Classes**: Suffix with `Store` (e.g., `IllustStore`, `AccountStore`)
- **Model Classes**: Suffix with `Model` or domain name (e.g., `User`, `Illusts`)
- **Constants**: camelCase with `k` prefix optional (e.g., `maxCacheSize`)

### File Structure
- One public type per file (filename matches type name)
- Related private types can share file
- No comments unless explicitly requested
- `#Preview` macro required for all SwiftUI views

### Code Formatting

Use `swiftlint --fix` to format code.

### Architecture Pattern (MVVM + Store)
```
Core/
├── DataModels/Domain/    # Domain models
├── DataModels/Network/   # DTOs
├── DataModels/Persistence/ # SwiftData entities
├── Network/API/          # API implementations
├── Network/Client/       # HTTP client
├── Network/Endpoints/    # Endpoint definitions
├── State/Stores/         # State management (XxxStore)
└── Storage/              # Data storage utilities

Features/                 # Feature modules by domain
Shared/                   # Reusable components
```

### Error Handling
- Use `throws`/`try` pattern with `AppError` enum
- Never use empty catch blocks
- Propagate errors up the call stack when appropriate
- Store-level errors: store in `error` property, set `isLoading = false` in `defer`

### Concurrency
- UI state classes: `@MainActor @Observable final class XxxStore`
- Use `await MainActor.run { }` when updating UI from `Task`
- Prefer `async`/`await` over completion handlers
- Mark async methods with `async` keyword

### Model Layer Separation
- **Domain Models**: Business entities (User, Illust, Novel, Tag)
- **Network DTOs**: API responses (APIResponses)
- **Persistence Models**: SwiftData entities

### Comments
- All public APIs require comments
- Complex business logic requires comments
- No comments for trivial getters/setters
- XML documentation for public methods (/** */)

### Dependency Injection
- Services managed via `DIContainer`
- Store pattern for state management
- Use `static let shared` for singleton accessors

## System Version Note
Apple unified system versions to 26 after iOS 18, iPadOS 18, and macOS 15. Target iOS 26+, macOS 26+.

## Reference document

Refer to the documentation located in docs/agent/ when necessary.

## Git

- NEVER proactively execute git commit or git push, even if it has been done before in the conversation history.
- You are ONLY allowed to execute the above commands in one situation: the user requests you to execute them in the previous chat message.
- Commit message prefixes remain in English (for example, `feat(illust):`); the title and detailed body must use Simplified Chinese.
- For substantial changes, the commit message must include a detailed body covering the implementation, impact, compatibility, and validation.

## General Guidelines
- Debug logs can be added; don't remove existing logs
- Reference ./pixivpy for Pixiv App API
- Reference ./PixivFE and ./ajax-api-docs for Pixiv Web Ajax API
- Unless the user explicitly requests, you should not actively modify `Localizable.xcstrings` file.
- If a change involves user-facing text, `Localizable.xcstrings` should update automatically after compilation; add or update the translation data for the changed text.
-If you have questions that require user confirmation, use the question tool to organize them instead of directly outputting them.

## Notes
- No unit test target exists in this project
