# Architecture

Codex Rhythm is a native macOS menu-bar application organized around explicit product features and infrastructure boundaries. The source tree follows one dependency direction: the app composes features and services; features consume domain models; services own external side effects.

## Source layout

```text
Sources/CodexRhythm/
├── App/                         Application entry point and lifecycle orchestration
├── Domain/
│   └── Quota/                   Usage snapshots, windows, and reset-credit values
├── Features/
│   ├── ControlCenter/           SwiftUI presentation and view model
│   └── TimerAssistant/          Scheduling policy, state, and persistence
├── Services/
│   ├── CodexAPI/                Authenticated quota acquisition
│   ├── CodexCLI/                Timer-start and quota-reset operations
│   └── LocalUsage/              SQLite telemetry fallback adapter
└── Support/
    └── Logging/                 Local diagnostic logging
```

Bundle metadata lives in `SupportingFiles/`; runtime assets live in `Resources/`. Build tooling, documentation, and tests are kept outside production sources.

## Runtime flow

```text
~/.codex/auth.json ──> CredentialsProvider ──> HTTPClient
                                                │
                  UsagePayloadDecoder <─────────┤
            ResetCreditsPayloadDecoder <────────┘
                         │
                         └──> CodexUsageService ──> UsageSnapshot
                                      ▲                   │
local SQLite telemetry ──> LocalUsageSnapshotReader      ├──> ControlCenterViewModel
                                                          └──> TimerAssistantPolicy
                                                                     │
                                                     CLI services + verification
```

## Responsibilities

### App

`CodexRhythmApplication.swift` is the explicit process entry point. `ApplicationDelegate.swift` owns lifecycle concerns and coordinates the menu-bar item, control center, refresh timer, wake handling, notifications, and service calls.

### Domain

The quota domain is split into three focused value-model files. `QuotaWindow.swift` owns window classification and percentage normalization, `UsageSnapshot.swift` models an observation and its provenance, and `ResetCredit.swift` models redeemable reset inventory. The domain has no network, JSON, SQLite, or UI dependencies.

### Features

The control-center feature separates observable state in `ControlCenterViewModel.swift` from rendering in `ControlCenterView.swift`.

The timer-assistant feature keeps deterministic scheduling and confirmation rules in `TimerAssistantPolicy.swift`. `TimerAssistantStore.swift` owns persistence and backward-compatible preference migration.

### Services

`CodexUsageService.swift` is a small orchestration layer. Authentication-file loading, request construction, transport validation, usage decoding, and reset-credit decoding are separate collaborators under `CodexAPI/`.

`LocalUsage/` isolates the fallback path into a SQLite command adapter, a telemetry field reader, a row decoder, and a repository that selects the newest valid snapshot. `TimerStartService.swift` and `QuotaResetService.swift` isolate process execution and validate structured receipts instead of treating process launch as success.

### Support

`AppLogger.swift` is the single diagnostic logging boundary. Authentication material and raw authenticated responses must never be logged.

## Safety invariants

- Automatic actions require fresh official quota data.
- Local fallback data can inform the UI but cannot authorize a timer start.
- A future reset timestamp at 0% usage is not sufficient proof of a real window.
- A start is confirmed by positive usage or three stable timestamps over time.
- Weekly reserve, deduplication, cooldown, and retry limits are evaluated before automatic execution.
- Credentials remain in memory and are never written to application logs.

## Persistence compatibility

The bundle identifier changed when the product became Codex Rhythm. `TimerAssistantStore` migrates the previous preference domain on first launch. Historical `WindowStarter.*` keys are intentionally treated as a stable persisted schema; renaming them without another migration would reset user configuration.

## Verification

`Tests/CodexRhythmTests/Regression/CodexRhythmRegressionTests.swift` exercises typed API decoding, telemetry fallback decoding, window classification, percentage clamping, scheduling, placeholder rejection, stable-window confirmation, reset-credit decoding, and forecast generation without network access.

`scripts/build.sh` discovers production Swift files recursively. `scripts/test.sh` compiles only the pure production units required by the deterministic regression suite.
