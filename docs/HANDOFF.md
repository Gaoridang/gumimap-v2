# Session Handoff — gumimap-v2

Last updated: 2026-06-20

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `feat/grok-place-enrichment` |
| Working tree | Grok enrichment streams live activity steps (search/query/sources) in place detail |
| Last verified | xcodebuild + iOS 26.5 simulator launch (UDID `33061315-12AA-4456-B68A-29E603FCF1FC`) |

## Merged / Shipped

- Agent workflow rules: `AGENTS.md`, `docs/agent-workflow.md`, `.cursor/rules/`, `scripts/run-simulator.sh`
- Floating pill toolbar (Lucide icons, map/list modes, list sub-tabs)
- Search flow (`feat/search-overlay` → `main`):
  - `NavigationStack` push to `SearchTabView`
  - Edge swipe-back via `InteractivePopEnabler`
  - Flat `systemGroupedBackground` UI (no overlay, no white cards)

## Shipped on `feat/kakao-search-api` (pending merge)

- **Kakao Local API keyword search** replaces mock data
  - `KakaoLocalService` → `GET /v2/local/search/keyword.json`
  - `Place` model (name, address, category, lat/lng)
  - `SearchViewModel`: 350ms debounce, loading/error states
  - `SearchTabView`: progress spinner, error message, category label
- **Secrets pipeline**
  - `scripts/generate-secrets.sh` reads `Config/secrets.local.env`
  - Build phase generates `gumimap-v2/Generated/Secrets.generated.swift` (gitignored)
  - `Secrets.swift` exposes `kakaoRestAPIKey`

## What Is on the App Now

- Entry: `RootView` (replaces `ContentView` at app launch)
- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** toolbar search button → `AppRoute.search` push → `SearchTabView`
  - Custom back button + interactive swipe-back
  - Auto keyboard focus on enter; query reset on leave
  - Live Kakao keyword search with debounce (구미 지역 한정: center + 20km radius)
- Placeholder `MapTabView` / `ListTabView`
- API keys in `Config/secrets.local.env` (gitignored); template at `Config/secrets.example.env`

## Demo — Place Detail Sheet + Grok (`feat/grok-place-enrichment`)

- Search result tap → `fullScreenCover` → `PlaceDetailSheet`
- Grok (`GrokPlaceService`) streams xAI Responses API (`grok-4.3` + `web_search`) and shows live activity feed in sheet
- `XAI_API_KEY` wired via `scripts/generate-secrets.sh` → `Secrets.xaiAPIKey`
- Bottom actions: 추가하기 (+ icon) + paperplane Kakao map link
- Layout stability: open-status row always reserved; enrichment skeleton matches final structure (no jump when Grok returns)

## Next Task

- User review of place detail demo → polish UI / merge
- MapKit mini-map in sheet + "지도에서 보기"
- Merge `feat/kakao-search-api` → `main` when ready

## Other Backlog

- Wire MapKit into `MapTabView`
- Wire list data into `ListTabView`
- Fix `run-simulator.sh` to target iOS 26.5 simulator by default (avoid 26.2 UDID mismatch)

## Key Paths

| Path | Purpose |
|------|---------|
| `Config/secrets.local.env` | Local API keys (gitignored) |
| `Config/secrets.example.env` | Key name template |
| `scripts/generate-secrets.sh` | Build-time secrets → `Generated/Secrets.generated.swift` |
| `gumimap-v2/Config/Secrets.swift` | Runtime secrets accessor |
| `gumimap-v2/Services/KakaoLocalService.swift` | Kakao Local API client |
| `gumimap-v2/Features/Search/Place.swift` | Search result model |
| `gumimap-v2/App/RootView.swift` | `NavigationStack` root + toolbar |
| `gumimap-v2/Navigation/TabRouter.swift` | Tab state + `path: [AppRoute]` |
| `gumimap-v2/Navigation/AppRoute.swift` | `.search` destination |
| `gumimap-v2/Navigation/InteractivePopEnabler.swift` | Swipe-back gesture fix |
| `gumimap-v2/Navigation/FloatingToolbar.swift` | Pill toolbar; search → `openSearch()` |
| `gumimap-v2/Features/Search/SearchTabView.swift` | Search screen UI |
| `gumimap-v2/Features/Search/SearchViewModel.swift` | Query + Kakao API results |
| `scripts/run-simulator.sh` | Build, install, launch (prefer iOS 26.5 UDID) |
| `AGENTS.md` | Agent index and hard rules |
| `docs/HANDOFF.md` | This file |