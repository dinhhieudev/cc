# Project Context

<!--
  Filled in once per project by the human. No agent or skill may overwrite this file;
  the only exception is the `save` skill, which may append human-approved bullets
  (PROJECT.md Candidates).

  Purpose: persistent project-level context that all agents/skills should know about
  without having to re-explore the codebase each time.

  DO NOT include secrets, tokens, passwords, or sensitive data.
-->

## Project

<!-- Project name and one-sentence description -->

## Platform

<!-- Mobile platform(s) this project targets. -->
<!-- Examples:
- iOS only (Swift/SwiftUI)
- Android only (Kotlin/Jetpack Compose)
- Flutter (iOS + Android)
- React Native (iOS + Android)
-->

## Environment & Build Matrix

<!-- Supported environments, build variants, schemes/flavors, and their API/config sources. -->
<!-- Examples:
- Environments: dev / staging / production
- iOS schemes: App-Dev, App-Staging, App-Release
- Android variants: debug, staging, release
- API/config selection: build configuration, not runtime hardcoding
-->

## Tech Stack

<!-- List main languages, frameworks, and tools -->
<!-- Example:
- Language: Swift 5.9
- UI: SwiftUI
- Persistence: SwiftData
- Architecture: MVVM
- Min target: iOS 17
-->

## Architecture Overview

<!-- Describe the top-level structure in 3-5 sentences -->
<!-- Where is the entry point? What are the main layers? -->

## Key Conventions

<!-- Patterns that must be followed -->
<!-- Example:
- ViewModels are @Observable, never ObservableObject
- Navigation uses NavigationStack with a path binding
- All async work goes through a Service layer
- Error handling: Result<T, AppError> at service boundary
-->

## Test Convention

<!-- Where tests live, what framework is used, and the risk-based test policy. -->
<!-- Examples:
- Flutter: test/ (unit), test/widget/ (widget) — add widget tests for new screens
- iOS: {TargetName}Tests/ (unit), {TargetName}UITests/ (UI) — unit tests for ViewModels
- Naming: {TypeName}Tests.swift / {type_name}_test.dart
- Business logic and bug fixes require regression tests when practical
- UI/navigation changes add widget/UI tests when the flow is stable and testable
- If tests are intentionally omitted, record the reason in Deviations from Plan
-->

## Device Matrix

<!-- Minimum emulator/simulator and real-device coverage for development and release. -->
<!-- Examples:
- iOS: minimum supported OS + current iPhone size class
- Android: minimum API + current Android version; one small and one large screen
- Real-device checks required for camera, location, notifications, biometrics, and performance
-->

## CI / PR Checks

<!-- Required checks before merge; include platform-specific jobs if applicable. -->
<!-- Examples:
- Lint, type check, unit tests, UI tests, debug build
- Release build only on release branches/tags
-->

## Release & Distribution

<!-- Versioning, signing, artifact distribution, crash symbols, and rollback/feature-flag rules. -->
<!-- Examples:
- iOS: TestFlight; Android: Play Internal Testing
- Never commit signing keys or production credentials
- Upload dSYM / mapping files with release artifacts
- Release notes and migration checks required for store releases
-->

## Security & Data Handling

<!-- What must not leave the repository and how external AI/tool payloads are sanitized. -->
<!-- Examples:
- Do not include customer data, production URLs with credentials, tokens, or certificates
- External AI attachments use an allowlist of source files
-->

## Source Layout

<!-- Main directories and what they contain -->
<!-- Example:
- Sources/App/         Entry point
- Sources/Features/    Screen-level views + VMs
- Sources/Services/    Business logic
- Sources/Models/      Data models
- Sources/UI/          Reusable components
-->

## Important Files

<!-- Files that context/execute/fix agents frequently need to know about -->
<!-- Example:
- Sources/App/AppModel.swift       Root state
- Sources/Services/APIClient.swift Networking layer
-->

## Known Constraints

<!-- Hard limits that plans must respect -->
<!-- Example:
- Must not break iOS 16 backward compat
- No third-party networking libraries
- Minimum supported OS version: iOS 16 / Android 8 (API 26)
- Offline/caching strategy: cache-first, background refresh
- Analytics events follow snake_case naming (e.g. screen_view, button_tap)
- New features gated behind a feature flag / remote config
- Tablet/foldable layouts not yet supported — phone-only for now
-->

## Type Check Command

<!-- Fast command that proves the codebase type-checks. Run after every attempt. -->
<!-- Examples:
- npm run typecheck
- dart analyze
- swiftc -typecheck Sources/**/*.swift
-->
<!-- execute-agent and fix-agent MUST run this before reporting done. -->

## Build Command

<!-- Full build command (slower). Run after type check passes. Skip if empty. -->
<!-- Examples:
- flutter build apk --debug
- xcodebuild -scheme App -destination 'generic/platform=iOS' build
-->

## Test Command

<!-- Test suite command. Run after a successful build when present. Skip if empty. -->
<!-- Examples:
- flutter test
- xcodebuild test -scheme AppTests -destination 'platform=iOS Simulator,name=iPhone 16'
-->

## Device Smoke Test Command

<!-- Optional command for emulator/simulator smoke tests or scripted UI tests. -->
<!-- Examples:
- maestro test .maestro/smoke.yaml
- xcodebuild test -scheme AppUITests -destination 'platform=iOS Simulator,...'
-->

## Language

<!-- Output language for prose agents write into .task/*.md and their final reports. -->
<!-- Allowed values: en (default), vi. Read by agents and bin/ scripts — value must follow the colon on the same line. -->
<!-- Headings, file names, task slugs, and code always stay English. -->

Language: en
