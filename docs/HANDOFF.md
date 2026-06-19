# Session Handoff — gumimap-v2

Last updated: 2026-06-20

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `feat/place-detail-sheet` |
| Working tree | Search → place detail with Grok SSE enrichment |
| Last verified | xcodebuild + iOS 26.5 simulator launch |

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

## Shipped on `feat/place-detail-sheet`

- **Place detail via NavigationStack push** (`AppRoute.placeDetail(Place)`)
  - Search result tap → `PlaceDetailView`
  - Grok SSE enrichment via `GrokPlaceSearchService` (xAI Responses API stream)
  - Kakao baseline (address, category, phone, map link) shown immediately on open
  - Live SSE progress checklist unchanged (v1 pattern)
  - Grok-only fields (hours, open status) load async with skeleton → staggered reveal
  - JSON in collapsed disclosure; Grok failure is field-scoped with retry
- **xAI API key** added to secrets pipeline (`XAI_API_KEY` → `Secrets.xaiAPIKey`)

## What Is on the App Now

- Entry: `RootView` (replaces `ContentView` at app launch)
- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** toolbar search button → `AppRoute.search` push → `SearchTabView`
  - Custom back button + interactive swipe-back
  - Auto keyboard focus on enter; query reset on leave
  - Live Kakao keyword search with debounce (구미 지역 한정: center + 20km radius)
  - Result tap → `PlaceDetailView` with Grok SSE enrichment + animated JSON reveal
- Placeholder `MapTabView` / `ListTabView`
- API keys in `Config/secrets.local.env` (gitignored); template at `Config/secrets.example.env`

## Next Task

- Polish place detail UI (map preview, business hours formatting, open/closed badge)
- Merge `feat/kakao-search-api` → `main` when ready
- Merge `feat/place-detail-sheet` → `main` when ready

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
| `gumimap-v2/Services/GrokPlaceSearchService.swift` | Grok SSE place enrichment |
| `gumimap-v2/Models/GrokSearchProgress.swift` | SSE progress message model |
| `gumimap-v2/Models/GrokPlaceDetail.swift` | Grok JSON result model |
| `gumimap-v2/Features/PlaceDetail/PlaceDetailView.swift` | Detail screen + animations |
| `gumimap-v2/Features/PlaceDetail/PlaceDetailViewModel.swift` | Loading/progress/reveal state |
| `gumimap-v2/Features/Search/Place.swift` | Search result model |
| `gumimap-v2/App/RootView.swift` | `NavigationStack` root + toolbar |
| `gumimap-v2/Navigation/TabRouter.swift` | Tab state + `path: [AppRoute]` |
| `gumimap-v2/Navigation/AppRoute.swift` | `.search`, `.placeDetail(Place)` |
| `gumimap-v2/Navigation/InteractivePopEnabler.swift` | Swipe-back gesture fix |
| `gumimap-v2/Navigation/FloatingToolbar.swift` | Pill toolbar; search → `openSearch()` |
| `gumimap-v2/Features/Search/SearchTabView.swift` | Search screen UI |
| `gumimap-v2/Features/Search/SearchViewModel.swift` | Query + Kakao API results |
| `scripts/run-simulator.sh` | Build, install, launch (prefer iOS 26.5 UDID) |
| `AGENTS.md` | Agent index and hard rules |
| `docs/HANDOFF.md` | This file |