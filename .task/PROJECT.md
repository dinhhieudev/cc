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
-->

## Verify Command

<!-- The exact shell command that proves the build/typecheck is clean. -->
<!-- Example:
- npm run typecheck
- swift build
- xcodebuild -scheme App -destination 'generic/platform=iOS' build
-->
<!-- execute-agent and fix-agent MUST run this before reporting done. -->

## Language

<!-- Output language for prose agents write into .task/*.md and their final reports. -->
<!-- Allowed values: en (default), vi. Read by agents and bin/ scripts — value must follow the colon on the same line. -->
<!-- Headings, file names, task slugs, and code always stay English. -->

Language: en
