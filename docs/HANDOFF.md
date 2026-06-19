# Session Handoff — gumimap-v2

Last updated: 2026-06-19

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `feature/floating-toolbar` |
| Working tree | List-mode animated toolbar with visited/wishlist sub-tabs |
| Last verified | xcodebuild + iOS 26.5 simulator launch succeeded |

## Merged / Shipped

- Initial agent workflow rules: `AGENTS.md`, `docs/agent-workflow.md`, `.cursor/rules/`, `scripts/run-simulator.sh`

## What Is on the App Now

- `RootView` with custom floating pill toolbar
- Map mode: `[pin][list] | [search]`
- List mode: `[back][visited][wishlist] | [search]` with spring transition
- Placeholder `MapTabView` / `ListTabView` (가본 곳 / 가고 싶은 곳)
- Search button is UI-only placeholder
- Original `ContentView` + `Item` SwiftData template unchanged (not wired in)

## Next Tasks

- Wire MapKit into `MapTabView`
- Wire list data into `ListTabView` (or reuse `ContentView`)
- Implement search action
- Simulator: update runtime to iOS 26.5 or lower deployment target if needed

## Key Paths

| Path | Purpose |
|------|---------|
| `gumimap-v2/gumimap_v2App.swift` | App entry point |
| `gumimap-v2/ContentView.swift` | Root view |
| `AGENTS.md` | Agent index and hard rules |
| `docs/agent-workflow.md` | Detailed workflow rules |
| `docs/HANDOFF.md` | This file — update after each completed task |
| `scripts/run-simulator.sh` | Build, install, and launch in simulator |