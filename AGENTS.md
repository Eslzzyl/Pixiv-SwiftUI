# AGENTS.md

## Build Commands

Prefer Debug build for development and debugging.

### Quick Build Commands
```bash
# macOS Debug build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# iOS Simulator Debug build (iPhone 17)
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# Full verbose build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=macOS' build
```

### Using Build Script

This is mainly for product release. Do not actively use these scripts unless requested by the user.

```bash
./scripts/build.sh              # Build both IPA and DMG
./scripts/build.sh --ipa-only   # iOS only
./scripts/build.sh --dmg-only   # macOS only
./scripts/build.sh --clean      # Clean build
./scripts/build.sh -v           # Verbose output
```

### Notes
- No unit test target exists in this project
- SwiftLint installed via Homebrew and project plugin (`.swiftlint.yml`)

## SwiftLint

Both Homebrew installation and project plugin are available. Use whichever is convenient.

### Commands
```bash
# Run linting and show all issues
swiftlint lint

# Show only errors
swiftlint lint 2>&1 | grep ": error:"

# Show errors and warnings
swiftlint lint 2>&1 | grep -E "(error:|warning:)"

# Autofix safe issues (some require manual review)
swiftlint --fix
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

### Common Rules
- `identifier_name`: Variable names 3-40 characters
- `line_length`: Max 160 characters
- `cyclomatic_complexity`: Max 10 (suppress if needed for ranking functions)
- `force_unwrapping`: Avoid forced unwrapping
- `empty_count`: Use `isEmpty` instead of `count == 0`

## Code Standards

### Language & Environment
- **Language**: Swift 6.0
- **Frameworks**: SwiftUI, SwiftData, Observation
- **Platforms**: iOS 18+, macOS 15+

### Import Order
```swift
import SwiftUI
import Observation
import SwiftData
import Foundation
// App module imports last
```

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
- **Indentation**: 4 spaces (not tabs)
- **Line length**: Maximum 120 characters
- **Spacing**: Space after commas, around operators
- **Braces**: Same-line style (K&R)

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
- All public APIs require Chinese comments
- Complex business logic requires Chinese comments
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

## General Guidelines
- Reply in the same language as the user
- Debug logs can be added; don't remove existing logs
- Reference flutter/ and aapi.py for implementation patterns
- Unless the user explicitly requests, you should not actively modify Localizable.xcstrings.
