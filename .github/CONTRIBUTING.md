# Contributing to Mythic

> Thank you for helping build a great macOS game launcher. Please read this guide before opening a PR.

## Code of Conduct
- Ensure you’ve read and understand the [Code of Conduct](CODE_OF_CONDUCT.md).

## Quick Start
- Requirements: Xcode 26+, Swift 6.0+
- Open `Mythic.xcodeproj` and build the `Mythic` scheme.

## Workflow
- Discuss first: create an issue or comment on an existing one before large changes.
- Fork, create a feature branch, commit using Conventional Commits, then open a PR.
- Keep PRs focused and small; include a clear summary and screenshots/videos when UI changes.

## Commit and PR Conventions
- Use [Conventional Commits](https://conventionalcommits.org).
  - Examples: `feat(library): vertical grid scrolling`, `fix(engine): prevent nil version crash`, `chore(ci): speed up build`.
  - Use `!` for breaking changes: `feat(api)!: remove deprecated endpoints`.
- Title your PR with the same style and reference related issues (e.g., `(fixes #123)`).

## CI Requirements
- PRs must pass:
  - SwiftLint: configured via `.swiftlint.yml` (runs in `.github/workflows/swiftlint.yml`).
  - Build: Xcode build on macOS (see `.github/workflows/build.yml`).

- [Install & Run SwiftLint locally](https://github.com/realm/SwiftLint#installation) if available.

## Code Style (Swift + SwiftUI)
- Prefer Swift Concurrency (async/await, Task) over callbacks; mark UI entry points with `@MainActor`.
- Document public types and important functions with `/** ... */` (DocC comments).
- Organize code by existing structure:
  - Models → `Mythic/Models`
  - Utilities/Globals/Extensions → `Mythic/Utilities`
    - Engine/Legendary/Wine, etc. live under their existing folders—follow the current layout.
  - Views (Components/Navigation/Onboarding/Unified) → `Mythic/Views`
- Logging: prefer `OSLog`/`Logger` categories used in the project over `print`.
- Globals: if absolutely necessary, prefer adding to `Global.swift` following the existing pattern; avoid new singletons unless justified.
- Dependencies: prefer Swift Package Manager; propose new dependencies in an issue before submitting.

## Localization
- English is the source; translations are managed via [Crowdin](crowdin.getmythic.app). 

## License
- By contributing, you agree your contributions are licensed under GNU GPLv3 ([view license](../LICENSE.md)).
- New Swift files should start with a header like:
  ```swift
  <#Xcode default header#>
  
  // Copyright © 2025 vapidinfinity
  ```

## Getting Help
- Questions? Use GitHub Issues or join our Discord shown in the README.
