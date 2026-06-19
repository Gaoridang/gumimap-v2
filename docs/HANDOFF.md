# Session Handoff — gumimap-v2

Last updated: 2026-06-19

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `main` |
| Working tree | Search feature merged; mock data ready for Kakao API swap |
| Last verified | xcodebuild + iOS 26.5 simulator launch; swipe-back confirmed |

## Merged / Shipped

- Agent workflow rules: `AGENTS.md`, `docs/agent-workflow.md`, `.cursor/rules/`, `scripts/run-simulator.sh`
- Floating pill toolbar (Lucide icons, map/list modes, list sub-tabs)
- Search flow (`feat/search-overlay` → `main`):
  - `NavigationStack` push to `SearchTabView`
  - Edge swipe-back via `InteractivePopEnabler`
  - Flat `systemGroupedBackground` UI (no overlay, no white cards)
  - Mock place search (10 Korean samples)

## What Is on the App Now

- Entry: `RootView` (replaces `ContentView` at app launch)
- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** toolbar search button → `AppRoute.search` push → `SearchTabView`
  - Custom back button + interactive swipe-back
  - Auto keyboard focus on enter; query reset on leave
  - `SearchViewModel` filters `MockPlace.samples` locally
- Placeholder `MapTabView` / `ListTabView`
- API keys in `Config/secrets.local.env` (gitignored); template at `Config/secrets.example.env`

## Next Task — Kakao Local API

Replace mock search with [Kakao Local API keyword search](https://developers.kakao.com/docs/latest/en/local/dev-guide#search-by-keyword).

| Step | Action |
|------|--------|
| 1 | Create branch `feat/kakao-search-api` |
| 2 | Add `KakaoLocalService` (or similar) under `gumimap-v2/Services/` or `Features/Search/` |
| 3 | Read `KAKAO_REST_API_KEY` from `Config/secrets.local.env` at build/runtime (xcconfig or `Secrets` loader) |
| 4 | Call `GET https://dapi.kakao.com/v2/local/search/keyword.json` with `Authorization: KakaoAK {REST_API_KEY}` |
| 5 | Map response → replace `MockPlace` with real model (`Place` with name, address, lat/lng, category) |
| 6 | Update `SearchViewModel`: debounce query, loading/error states, async fetch |
| 7 | Wire result tap → map camera move (after MapKit is in place) or stub for now |
| 8 | Simulator verify + HANDOFF update + commit |

**Keys on disk (local only):** `KAKAO_NATIVE_APP_KEY`, `KAKAO_REST_API_KEY` — search needs REST key only for now.

## Other Backlog

- Wire MapKit into `MapTabView`
- Wire list data into `ListTabView`
- Fix `run-simulator.sh` to target iOS 26.5 simulator by default (avoid 26.2 UDID mismatch)

## Key Paths

| Path | Purpose |
|------|---------|
| `Config/secrets.local.env` | Local API keys (gitignored) |
| `Config/secrets.example.env` | Key name template |
| `gumimap-v2/App/RootView.swift` | `NavigationStack` root + toolbar |
| `gumimap-v2/Navigation/TabRouter.swift` | Tab state + `path: [AppRoute]` |
| `gumimap-v2/Navigation/AppRoute.swift` | `.search` destination |
| `gumimap-v2/Navigation/InteractivePopEnabler.swift` | Swipe-back gesture fix |
| `gumimap-v2/Navigation/FloatingToolbar.swift` | Pill toolbar; search → `openSearch()` |
| `gumimap-v2/Features/Search/SearchTabView.swift` | Search screen UI |
| `gumimap-v2/Features/Search/SearchViewModel.swift` | Query + results (mock today) |
| `gumimap-v2/Features/Search/MockPlace.swift` | Replace with Kakao response model |
| `scripts/run-simulator.sh` | Build, install, launch (prefer iOS 26.5 UDID) |
| `AGENTS.md` | Agent index and hard rules |
| `docs/HANDOFF.md` | This file |