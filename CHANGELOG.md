# Changelog

## 3.5.0 - 2026-09-06

- Rename the application bundle, executable, identifiers, logs, and runtime labels to Codex Rhythm.
- Reorganize production sources, tests, resources, documentation, and automation into dedicated directories.
- Introduce explicit App, Domain, Features, Services, and Support source boundaries.
- Replace the former monolithic quota model and usage reader with focused domain, decoding, authentication, HTTP, SQLite, and telemetry components.
- Add regression coverage for typed API payloads and local telemetry fallback decoding.
- Rename legacy implementation types around the current timer-assistant vocabulary and split presentation, policy, and persistence responsibilities.
- Remove the unused legacy menu panel and legacy application delegate from the build.
- Migrate timer-assistant preferences from the former bundle identifier on first launch.
- Rewrite the English and Chinese READMEs around the current product and two-mode assistant.
- Add architecture, release, security, contribution, conduct, CI, issue, and pull-request documentation.
- Add a reproducible release packaging script with a SHA-256 checksum.
- Add a dedicated neutral graphite-and-green application icon.
- Add a long-form Chinese introduction suitable for publishing.
- Embed the MIT license and third-party notice in binary application bundles.

## 3.4.0 - 2026-09-06

- Add a “时间预测” action beside the five-hour quota title.
- Show the next three estimated reset times in a compact native popover.
- Base the forecast on the confirmed current reset time and successive five-hour cycles.
- Explain that sleep, connectivity, or delayed timer starts can push later resets back.

## 3.3.3 - 2026-09-04

- Stop treating the moving `now + 5h` timestamp returned at 0% usage as an active quota window.
- Allow manual and automatic timer starts when usage is truly idle.
- Confirm successful starts by observed usage or three stable reset timestamps within a five-hour ±10-minute tolerance.
- Persist confirmed real windows so restarts do not cause duplicate trigger requests.
- Hide placeholder countdowns and show “尚未开始计时” until a real window is detected.

## 3.3.2 - 2026-09-04

- Confirm a newly started five-hour window within a strict ten-minute reporting tolerance.
- Turn the available-reset badge into an explicit manual reset button with irreversible-action confirmation.
- Redeem resets through the bundled Codex app-server protocol with idempotent retry protection.
- Distinguish manual quota reset from the separate manual timer-start action.

## 3.3.1 - 2026-09-03

- Use the more substantial Terra model for timer-start requests and migrate the prior hidden Luna default.
- Require ChatGPT subscription authentication and a completed JSON usage receipt from the Codex CLI.
- Confirm a new five-hour reset timestamp through the official usage endpoint before reporting success.
- Keep unconfirmed attempts retryable instead of incorrectly marking their schedule slot as handled.

## 3.3.0 - 2026-09-01

- Replace the four internal automation modes with a single on/off switch and two user-facing choices: automatic watch and fixed time.
- Make automatic watch the default choice, checking every 10 minutes between 08:00 and 23:00 when enabled.
- Add editable active hours, check intervals, and up to two daily fixed check times.
- Keep quota countdowns in the quota card while the timer assistant reports only its own state and next check.
- Add a 15-minute post-success deduplication guard, weekly-quota protection, and migration from prior automatic settings.
- Redesign the assistant as a compact neutral frosted-glass panel with a one-click manual start action.

## 3.2.0 - 2026-08-28

- Replace the dark tinted glass theme with a neutral light frosted-glass system.
- Remove all blue, violet, cyan, and pink gradients from the control center.
- Use graphite typography, white translucent surfaces, warm orange quota accents, and green safety states.
- Force the native light appearance so system dark mode cannot turn the control center dark again.
- Verify both the compact and expanded policy layouts against the rendered application.

## 3.1.0 - 2026-08-28

- Upgrade the entire control center to a transparent native macOS glass material.
- Add active behind-window blur, restrained violet/cyan ambient light, translucent cards, edge highlights, and glass action controls.
- Replace the remaining system title bar with a seamless borderless glass window.
- Add custom refresh and close controls while retaining keyboard-accessible native inputs.
- Preserve contrast and status colors across the collapsed and expanded policy layouts.

## 3.0.0 - 2026-08-28

- Replace the inherited long-menu interface with the new Codex Rhythm control center.
- Add a compact menu-bar indicator, a standalone window, and a transient popover powered by SwiftUI.
- Introduce a circular 5-hour rhythm display, compact weekly status, reset badges, and live source state.
- Redesign window automation around four visual modes: off, notify, rehearsal, and automatic start.
- Move schedules, grace period, weekly protection, model, and CLI path into an expandable policy card.
- Separate the no-call safety check from the confirmed real window-start action.
- Open the control center when launched manually while keeping login launches in the background.

## 2.5.0 - 2026-08-28

- Add an experimental 5-hour window starter, disabled by default.
- Support reminder-only, dry-run, and explicitly confirmed automatic modes.
- Require fresh official usage data, no active 5-hour window, and a configurable weekly-quota reserve before automatic execution.
- Add configurable daily times, grace period, Codex CLI path, and model.
- Run automatic requests in an ephemeral read-only Codex session with timeout, cooldown, per-slot deduplication, and retry limits.
- Add wake-from-sleep checks, macOS notifications, manual no-call checks, and policy regression tests.

## 2.4.0 - 2026-07-26

- Read banked reset credits from Codex's dedicated reset-credit endpoint.
- Show the available reset count and every available `Full reset` expiry time.
- Sort banked resets by earliest expiry and keep redeemed or expired entries hidden.
- Keep quota-window countdowns separate from banked reset expiration dates.
- Treat banked reset failures as optional so normal quota monitoring keeps working.

## 2.3.0 - 2026-07-26

- Show the exact local reset timestamp directly under each quota meter.
- Keep the live reset countdown alongside the absolute date and time.
- Display an explicit unknown value when a quota window has no reset timestamp.
- Use isolated Swift module caches for reproducible local builds.

## 2.2.0 - 2026-07-13

- Identify 5-hour and weekly quotas by their window duration instead of API field order.
- Correctly show a weekly-only test window as `5h --% / W 100%`.
- Apply the same duration mapping to official API and local-log fallback data.
- Clamp malformed percentage values and preserve exhausted quota as 0% remaining.
- Add regression tests for single-window, exhausted, and malformed responses.

## 2.1.0 - 2026-07-10

- Add a native graphical quota panel with separate 5-hour and weekly meters.
- Show remaining percentage and live reset countdown under each meter.
- Color low remaining quota red, medium quota orange, and healthy quota blue.
- Keep exact reset timestamps and manual sync actions in the menu.

## 2.0.0 - 2026-07-10

- Read live quota data from the current Codex usage endpoint.
- Refresh automatically every 30 seconds.
- Fall back to recent local Codex response headers when necessary.
- Show the active data source and sync timestamp in the menu.
- Support the current Codex desktop application bundle path.
- Add source build, per-user install, and uninstall scripts.
