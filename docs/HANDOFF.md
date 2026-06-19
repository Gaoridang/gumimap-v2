# Session Handoff — gumimap-v2

Last updated: 2026-06-19

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `feat/search-overlay` |
| Working tree | Spotlight search overlay with mock results implemented |
| Last verified | xcodebuild + iOS 26.5 simulator launch succeeded |

## Merged / Shipped

- Agent workflow rules: `AGENTS.md`, `docs/agent-workflow.md`, `.cursor/rules/`, `scripts/run-simulator.sh`
- Floating pill toolbar (Lucide icons, map/list modes, list sub-tabs)
- Spotlight search overlay (mock place results, toolbar-matched design)

## What Is on the App Now

- Entry: `RootView` (replaces `ContentView` at app launch)
- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
  - Back chevron has light circular background
  - Spring animation on mode switch; sub-tabs slide in from the right
- **List sub-tabs:** 가본 곳 (visited) / 가고 싶은 곳 (wishlist)
- Placeholder `MapTabView` / `ListTabView`
- Search opens upper Spotlight overlay with auto keyboard focus (fixed search bar position)
- Mock place search filters 10 Korean sample locations
- Tap outside dimmed area dismisses search and clears query
- Original `ContentView` + `Item` SwiftData template unchanged (not wired in)

## Next Tasks

- Wire MapKit into `MapTabView`
- Wire list data into `ListTabView` (or reuse `ContentView`)
- Wire Kakao Local API into search (replace mock data)
- Handle search result selection (map camera / save to list)
- Fix `run-simulator.sh` to target iOS 26.5 simulator by default

## Key Paths

| Path | Purpose |
|------|---------|
| `gumimap-v2/gumimap_v2App.swift` | App entry point |
| `gumimap-v2/App/RootView.swift` | Root view (content + toolbar) |
| `gumimap-v2/Navigation/FloatingToolbar.swift` | Pill toolbar UI and animations |
| `gumimap-v2/Navigation/TabRouter.swift` | Tab + list sub-tab state |
| `gumimap-v2/Navigation/ToolbarIcon.swift` | Lucide asset icon wrapper |
| `gumimap-v2/Features/Map/MapTabView.swift` | Map placeholder |
| `gumimap-v2/Features/List/ListTabView.swift` | List placeholder |
| `gumimap-v2/Features/Search/SearchOverlayView.swift` | Spotlight search UI |
| `gumimap-v2/Features/Search/SearchViewModel.swift` | Search state and filtering |
| `gumimap-v2/Features/Search/MockPlace.swift` | Mock place samples |
| `gumimap-v2/Assets.xcassets/toolbar-*.imageset/` | Lucide SVG toolbar icons |
| `scripts/run-simulator.sh` | Build, install, launch (use iOS 26.5 sim) |
| `AGENTS.md` | Agent index and hard rules |
| `docs/HANDOFF.md` | This file |