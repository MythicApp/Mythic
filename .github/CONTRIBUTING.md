# Contributing to Mythic

Thank you for helping build a great macOS game launcher! Please read this guide before opening a PR.

---

## Code of Conduct

Please read and understand our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

---

## Quick Start

**Requirements:**
- Xcode 16+
- Swift 6.0+

**To build:**
1. Open `Mythic.xcodeproj`
2. Build the `Mythic` scheme

---

## Contribution Workflow

1. **Discuss first:** Create an issue or comment on an existing one before making large changes
2. **Fork & branch:** Fork the repository and create a feature branch
3. **Commit:** Use [Conventional Commits](https://conventionalcommits.org) format
4. **Open a PR:** Keep PRs focused and small with clear summaries
5. **Include visuals:** Add screenshots or videos for UI changes

---

## Commit and PR Conventions

### Conventional Commits Format

Use the [Conventional Commits](https://conventionalcommits.org) specification:

**Examples:**
- `feat(`LibraryView`): add vertical grid scrolling`
- `fix: prevent nil version crash`
- `chore(ci): speed up build`

**Breaking changes:** Use `!` after the scope:
- `feat(api)!: remove deprecated endpoints`

Prefer using backticks when referencing in-code values, e.g., \`ContentView\`

### Pull Request Titles

Title your PR using the same convention and [reference related issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue#linking-a-pull-request-to-an-issue-using-a-keyword):
- `feat(`LibraryView`): add grid view (fixes #123, #456)`

---

## CI Requirements

All PRs must pass:

- **SwiftLint:** Configured via `.swiftlint.yml` (see [here](.github/workflows/swiftlint.yml).)
- **Build:** Xcode build on macOS (see [here](.github/workflows/build.yml).)

**Tip:** [Install SwiftLint locally](https://github.com/realm/SwiftLint#installation) to catch issues before pushing.

---

## Code Style Guidelines

### General Principles

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use **Model-View-ViewModel (MVVM)** architecture (see [example](Mythic/Views/Onboarding))
- Write **dynamic and reusable code** that adapts to different contexts
- **Search existing code** before creating new methods to reduce duplication
- Store structs, enums, and other similar data structures in **class extensions**

### Swift & SwiftUI Best Practices

#### Naming
- Use **descriptive names** — avoid shorthand like `e`; use `example` instead
- Only add **singleton variables** to global scope:
  ```swift
  nonisolated(unsafe) let workspace: NSWorkspace = .shared // ✅
  var isInstallingGame: Bool = false // ❌
  ```

#### Declarations
- Prefer **explicit types and referencing using `.`, e.g. `.init()`, `.shared`**:
  ```swift
  let example: String = .init() // ✅
  let example = String() // ❌
  ```
- Prefer expressing generic types' protocol conformance using `where`, as opposed to direct colon usage

#### Views
- **Prefer creating new view types** over using `@ViewBuilder`.
- Use **SwiftUI only**
  - AppKit workarounds are allowed only if:
    - Functionality is unavailable in SwiftUI
    - Implementation is isolated and reasonably sized
    - Functionality is necessary
- Avoid explicit `spacing:` and `frame` values where possible

#### Concurrency
- Use **Swift Concurrency** (`async`/`await`, `Task`, `@MainActor`)
- Avoid older APIs like `DispatchQueue.main.async`
- Adhere to **Swift 6 concurrency requirements** — avoid creating new `@unchecked` code
- Initialize `Task`s with appropriate `TaskPriority` for efficient scheduling
- Only execute code on main actor when necessary
- Mark UI entry points with `@MainActor`

#### Logging
- Use **`OSLog`'s `Logger`** for logging.
- **Do not use `print()`**.

#### Documentation
- Document public types and important functions:
  - `/** ... */` for multiple lines
  - `///` for single lines
  - See [Apple's documentation guide](https://developer.apple.com/documentation/xcode/writing-symbol-documentation-in-your-source-files)
- Only comment when **clarification is necessary** — avoid obvious comments

### Code Organization

Follow the existing project structure:

- **Utilities/Globals/Extensions** → `Mythic/Utilities`
- **Views** → `Mythic/Views`
  - Components/Navigation/Onboarding/Unified subdirectories

### Dependencies

- Prefer **Swift Package Manager**
- Propose new dependencies in an issue **before** submitting a PR

---

## Localization

- **Source language:** English
- **Translations:** Managed via [Crowdin](https://crowdin.getmythic.app)
  - Strings are automatically added to [`Localizable.xcstrings`](Mythic/Localizable.xcstrings)

**For non-SwiftUI strings:** Wrap string literals in `String(localized:)`:
```swift
let message = String(localized: "Welcome to Mythic")
```

---

### File Headers

New Swift files should include this header:
```swift
<#Xcode default header#>

// Copyright © 2023-<#Current year#> vapidinfinity
```

*Note: This header should be automatically generated when creating files in Xcode.*

---

## Getting Help

Have questions?
- **GitHub Issues:** Open an issue for bugs or feature requests
- **Discord:** Join our community (link in [README](README.md))

---

if you actually read this you're cool bro 🗣️
