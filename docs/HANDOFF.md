# Session Handoff — gumimap-v2

Last updated: 2026-06-20

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `feat/list-place-card-demo` |
| Next branch | (create before first code change on next task) |
| Working tree | Clean after list card finalize |
| Last verified | xcodebuild + iOS 26.5 simulator launch (2026-06-20) |

## Next Task — Backlog

Pick up from backlog below (map pins, Kakao search gaps, etc.).

## Merged / Shipped on `main`

### List place card — icon style (`feat/list-place-card-demo`)

- `SavedPlaceCard` — category icon + name, category, address, enrichment teaser
- `PlaceCategoryIcon` — Kakao category → SF Symbol + tint
- `ListTabView` — `ScrollView` + card rows (replaces plain text list rows)
- 영업중 badge when `grokDetail.isCurrentlyOpen`; insight line: 분위기 → 특징

**Key paths:** `SavedPlaceCard.swift`, `PlaceCategoryIcon.swift`, `ListTabView.swift`

### Saved place edit & delete (`feat/saved-place-edit-delete` → merged 2026-06-20)

- **Saved detail `...` menu:** "리스트 변경" and "삭제" (confirmation dialog)
- `PlaceStore.delete()` and `PlaceStore.moveListKind()` — move merges enrichment if target already exists
- `PlaceListKindSheet` — shared sheet for register + move; shows "현재" for active list
- `TabRouter.replaceSavedPlaceDetail()` — after move, switches sub-tab and replaces nav destination
- Plain `ellipsis` toolbar icon (no circle)

**Key paths:** `PlaceStore.swift`, `PlaceListKindSheet.swift`, `PlaceDetailView.swift`, `TabRouter.swift`

### Place detail header (`feat/place-detail-sticky-header` → merged 2026-06-20)

- Native large navigation title collapse (system scroll-to-inline header)
- Custom scroll overlay removed

### Background enrichment (`feat/place-enrichment-background` → merged 2026-06-20)

- Register button disabled during Grok loading (`추가 정보 확인 중`)
- `PlaceEnrichmentService` schedules background Grok fetch when saved without enrichment
- Saved detail auto-refreshes on `savedPlaceEnrichmentUpdated` notification

### Place registration (`feat/place-register` → merged 2026-06-20)

- **등록하기** opens `PlaceListKindSheet` (가본 곳 / 가고 싶은 곳)
- `SavedPlace` SwiftData model; upsert by composite id `kakaoPlaceId-listKind`
- After save: `TabRouter.completeRegistration` → list tab + sub-tab + saved detail push
- `PlaceDetailView` dual mode: `.discovery` (Grok fetch) / `.saved` (cached, no register button)
- `ListTabView` shows saved places per sub-tab via `@Query` (respects top safe area)

**Key paths:** `SavedPlace.swift`, `PlaceStore.swift`, `PlaceDetailViewModel.swift`, `ListTabView.swift`, `AppRoute.swift`

### App shell & navigation

- `RootView` entry; floating pill toolbar (Lucide icons, map/list modes, list sub-tabs)
- `NavigationStack` search push + `InteractivePopEnabler` swipe-back
- Toolbar size bump (icons 24pt, tap targets 40pt)

### Search (`feat/search-overlay` + `feat/kakao-search-api`)

- `SearchTabView` + `SearchViewModel` with 350ms debounce
- **Kakao Local API** keyword search (`KakaoLocalService`)
- `Place` model; 구미 지역 한정 (center + 20km radius, `SearchRegion`)
- Secrets pipeline: `Config/secrets.local.env` → `scripts/generate-secrets.sh` → `Secrets.generated.swift`

### Place detail & Grok enrichment (`feat/place-detail-sheet`)

- `AppRoute.placeDetail(Place)` push from search results
- **Kakao baseline** shown immediately (address, category, phone, 카카오맵 링크)
- **Grok enrichment** — single web search per place (`{이름} 구미`, reasoning `medium`)
  - `GrokPlaceSearchService` → xAI Responses API SSE
  - Production-friendly progress copy (no Grok/JSON jargon)
  - UI shows 6 curated fields: 영업시간, 브레이크타임, 휴무일, 주차, 분위기, 특징
  - Extra fields + reviews stored in model; reviews shown as bullet card
  - `businessHours` used for **영업중** badge on register row
- Staggered reveal after SSE completes

## What Is on the App Now

- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** Kakao live search → tap result → discovery detail with Grok enrichment → 등록하기 → list tab saved detail
- **List tabs:** 가본 곳 / 가고 싶은 곳 show icon place cards; tap card → saved detail
- **Saved detail:** `...` menu → 리스트 변경 or 삭제
- Placeholder `MapTabView`
- API keys in `Config/secrets.local.env` (gitignored); template at `Config/secrets.example.env`

## Other Backlog

- Wire MapKit into `MapTabView`
- Saved detail Grok re-enrichment
- Place detail polish (map preview, business hours formatting)
- "Already saved" badge on discovery detail
- Kakao REST API search gaps (e.g. 와일드차일드)
- Fix `run-simulator.sh` UDID fallback edge cases

## Key Paths

| Path | Purpose |
|------|---------|
| `Config/secrets.local.env` | Local API keys (gitignored) |
| `Config/secrets.example.env` | Key name template |
| `scripts/generate-secrets.sh` | Build-time secrets generation |
| `gumimap-v2/Config/Secrets.swift` | Runtime secrets accessor |
| `gumimap-v2/Models/SavedPlace.swift` | SwiftData saved place model |
| `gumimap-v2/Services/PlaceStore.swift` | Register, delete, move, enrichment update |
| `gumimap-v2/Services/PlaceEnrichmentService.swift` | Background Grok enrichment |
| `gumimap-v2/Services/KakaoLocalService.swift` | Kakao Local API client |
| `gumimap-v2/Services/GrokPlaceSearchService.swift` | Grok SSE single search |
| `gumimap-v2/Models/GrokPlaceDetail.swift` | Enrichment model + visible field mapping |
| `gumimap-v2/Models/GrokSearchProgress.swift` | SSE progress messages |
| `gumimap-v2/Services/BusinessHoursParser.swift` | Open-now from hours + break time |
| `gumimap-v2/Features/PlaceDetail/` | Detail screen, view model, list-kind sheet |
| `gumimap-v2/Features/Search/` | Search UI + `Place` model |
| `gumimap-v2/Features/List/ListTabView.swift` | Saved place list |
| `gumimap-v2/App/RootView.swift` | Navigation root |
| `gumimap-v2/Navigation/` | Routes, toolbar, tab router |
| `scripts/run-simulator.sh` | Build, install, launch |
| `AGENTS.md` | Agent index and hard rules |
| `docs/HANDOFF.md` | This file |