# Session Handoff — gumimap-v2

Last updated: 2026-06-20

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `main` |
| Next branch | `feat/place-register` (create before first code change) |
| Working tree | Clean; `feat/place-detail-sheet` merged into `main` |
| Last verified | xcodebuild + iOS 26.5 simulator launch (2026-06-20) |

## Next Task — 등록하기

Wire the fixed bottom **등록하기** button in `PlaceDetailView`:

- `PlaceDetailViewModel.register()` is a TODO stub
- Persist `Place` + optional `GrokPlaceDetail` (enrichment fields/reviews)
- Surface saved places in `ListTabView` sub-tabs (`visited` / `wishlist`) — currently placeholders
- Decide storage: SwiftData (project already has `Item.swift` scaffold) vs new model

**Key entry points**

| Path | Notes |
|------|-------|
| `gumimap-v2/Features/PlaceDetail/PlaceDetailViewModel.swift` | `register()` |
| `gumimap-v2/Features/PlaceDetail/PlaceDetailView.swift` | `registerButton` |
| `gumimap-v2/Features/List/ListTabView.swift` | List sub-tab UI |
| `gumimap-v2/Navigation/ListSubTab.swift` | `.visited` / `.wishlist` |
| `gumimap-v2/Features/Search/Place.swift` | Search result model to persist |

## Merged / Shipped on `main`

### App shell & navigation

- `RootView` entry; floating pill toolbar (Lucide icons, map/list modes, list sub-tabs)
- `NavigationStack` search push + `InteractivePopEnabler` swipe-back
- Toolbar size bump (icons 24pt, tap targets 40pt)

### Search (`feat/search-overlay` + `feat/kakao-search-api`)

- `SearchTabView` + `SearchViewModel` with 350ms debounce
- **Kakao Local API** keyword search (`KakaoLocalService`)
- `Place` model; 구미 지역 한정 (center + 20km radius, `SearchRegion`)
- Secrets pipeline: `Config/secrets.local.env` → `scripts/generate-secrets.sh` → `Secrets.generated.swift`

### Place detail (`feat/place-detail-sheet` → merged 2026-06-20)

- `AppRoute.placeDetail(Place)` push from search results
- **Kakao baseline** shown immediately (address, category, phone, 카카오맵 링크)
- **Grok enrichment** — single web search per place (`{이름} 구미`, reasoning `medium`)
  - `GrokPlaceSearchService` → xAI Responses API SSE
  - Production-friendly progress copy (no Grok/JSON jargon)
  - UI shows 6 curated fields: 영업시간, 브레이크타임, 휴무일, 주차, 분위기, 특징
  - Extra fields + reviews stored in model; reviews shown as bullet card
  - `businessHours` used for **영업중** badge on register row (not shown as its own row)
- Staggered reveal after SSE completes; **등록하기** button UI ready (no persistence yet)
- xAI key: `XAI_API_KEY` → `Secrets.xaiAPIKey`

## What Is on the App Now

- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** Kakao live search → tap result → `PlaceDetailView` with Grok enrichment
- Placeholder `MapTabView` / `ListTabView` (no saved data yet)
- API keys in `Config/secrets.local.env` (gitignored); template at `Config/secrets.example.env`

## Other Backlog

- Wire MapKit into `MapTabView`
- Place detail polish (map preview, business hours formatting)
- Fix `run-simulator.sh` UDID fallback edge cases

## Key Paths

| Path | Purpose |
|------|---------|
| `Config/secrets.local.env` | Local API keys (gitignored) |
| `Config/secrets.example.env` | Key name template |
| `scripts/generate-secrets.sh` | Build-time secrets generation |
| `gumimap-v2/Config/Secrets.swift` | Runtime secrets accessor |
| `gumimap-v2/Services/KakaoLocalService.swift` | Kakao Local API client |
| `gumimap-v2/Services/GrokPlaceSearchService.swift` | Grok SSE single search |
| `gumimap-v2/Models/GrokPlaceDetail.swift` | Enrichment model + visible field mapping |
| `gumimap-v2/Models/GrokSearchProgress.swift` | SSE progress messages |
| `gumimap-v2/Services/BusinessHoursParser.swift` | Open-now from hours + break time |
| `gumimap-v2/Features/PlaceDetail/` | Detail screen + view model |
| `gumimap-v2/Features/Search/` | Search UI + `Place` model |
| `gumimap-v2/App/RootView.swift` | Navigation root |
| `gumimap-v2/Navigation/` | Routes, toolbar, tab router |
| `scripts/run-simulator.sh` | Build, install, launch |
| `AGENTS.md` | Agent index and hard rules |
| `docs/HANDOFF.md` | This file |