# Session Handoff — gumimap-v2

Last updated: 2026-06-22

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `fix/map-pin-top-clip` |
| Next branch | (create before first code change on next task) |
| Working tree | Clean after map pin arc-direction fix |
| Last verified | xcodebuild + iOS 26.5 simulator launch (2026-06-22) |

## Shipped on `fix/map-pin-top-clip` (pending merge)

### Map pin top clipping fix (`fix/map-pin-top-clip`)

- **`MapPinLayout`** — shared geometry: 6pt internal head inset + 4pt canvas padding so the round head is never flush with the bitmap edge
- **`MapPinStyle`** — warm yellow fill (`#FAE37A`) + soft blue border (`#4A85C7`), 2pt stroke
- **`MapPinLayout`** — single closed path (circle arc + tail) so border does not double-stroke at the junction; arc uses `clockwise: true` (UIKit y-down coords) so the full round head renders instead of only the tail
- **`KakaoMapPinImageRenderer`** — fill + stroke rendering at 3× scale; style id `v12-unified`
- **`MapPinPointer` / `SavedPlaceMapPin`** — same layout and colors for map + SwiftUI preview parity

**Key paths:** `MapPinLayout.swift`, `KakaoMapPinImageRenderer.swift`, `MapPinPointer.swift`, `SavedPlaceMapPin.swift`

## Shipped on `fix/grok-sse-live-activity` (pending merge)

### Grok SSE live activity restore (`fix/grok-sse-live-activity`)

- **Discovery detail** — SSE progress checklist visible again while Grok enrichment runs (before 등록하기 unlocks)
- **`PlaceDetailViewModel`** — `progressLog`, `currentProgress`, `showProgress`; wires `onProgress` from `GrokPlaceSearchService`
- **Post-registration background enrichment** — `PlaceEnrichmentService` tracks per-saved-place SSE progress; saved detail shows same checklist while enrichment completes
- **`PlaceEnrichmentService`** — `@Observable`; uses `.environment(PlaceEnrichmentService.self)` for live UI updates

**Key paths:** `PlaceDetailView.swift`, `PlaceDetailViewModel.swift`, `PlaceEnrichmentService.swift`, `RootView.swift`

## Next Task — Backlog

Pick up from backlog below.

- Map sheet edit parity — add "정보 수정" to `MapPlaceSheet` `...` menu (detail view already has it)
- Saved detail Grok re-enrichment
- Place detail map preview
- Kakao REST API search gaps (e.g. 와일드차일드)
- Fix `run-simulator.sh` UDID fallback edge cases

## Merged / Shipped on `main`

### Map pins — round head + short tail (`feat/map-teardrop-pin` → merged 2026-06-20)

- **`MapPinPointer`** — filled circle head + short pointed tail; tip anchors at bottom center (`anchorPoint` 0.5, 1.0)
- **`KakaoMapPinImageRenderer`** — borderless solid fill; green (가본 곳) / blue (가고 싶은 곳); no category icon; style id `v7-short`
- **`SavedPlaceMapPin`** — SwiftUI preview matches Kakao marker (28×26pt)

**Key paths:** `MapPinPointer.swift`, `KakaoMapPinImageRenderer.swift`, `SavedPlaceMapPin.swift`

### List ↔ map linking (`feat/list-map-link` → merged 2026-06-20)

- **List card map button** — trailing `map` icon → map tab, animated zoom to pin (level 17, 700ms), sheet after zoom completes
- **`MapTabView.onAppear`** — consumes `pendingMapFocusPlaceId` when remounting from list tab (fixes missed `onChange`)
- **Saved detail** — "지도에서 보기" pops nav and focuses map + sheet
- **Map sheet** — "상세 보기" dismisses sheet and pushes saved `PlaceDetailView`
- **`TabRouter.openSavedPlaceOnMap(id:)`** — clears nav path, sets `pendingMapFocusPlaceId`

**Key paths:** `TabRouter.swift`, `KakaoMapView.swift`, `MapTabView.swift`, `ListTabView.swift`, `MapPlaceSheet.swift`, `PlaceDetailView.swift`

### Discovery saved badge + business hours (`feat/saved-badge-hours-format` → merged 2026-06-20)

- **Discovery detail:** "가본 곳/가고 싶은 곳에 저장됨" banner; register row disabled with checkmark when already saved
- **`PlaceStore.savedListKind(forKakaoPlaceId:)`** — lookup across both lists
- **`BusinessHoursParser.formatDisplay`** — weekday grouping (`월–금  10:00 – 22:00`), `매일` shortcut; applied in `GrokPlaceDetail.visibleFieldRows`

**Key paths:** `PlaceStore.swift`, `BusinessHoursParser.swift`, `GrokPlaceDetail.swift`, `PlaceDetailViewModel.swift`, `PlaceDetailView.swift`

### Saved place info edit (`feat/saved-place-info-edit` → merged 2026-06-20)

- **Saved detail `...` menu:** "정보 수정" (alongside 리스트 변경 / 삭제)
- **`SavedPlaceEditSheet`** — edits name, address, category, phone, 6 enrichment fields, reviews
- **`PlaceStore.update(savedPlaceId:draft:)`** — persists baseline + enrichment; posts `savedPlaceInfoUpdated`
- List/map auto-refresh via SwiftData `@Query`

**Key paths:** `SavedPlaceEditSheet.swift`, `PlaceStore.swift`, `PlaceDetailView.swift`, `GrokPlaceDetail.swift`

### Kakao Map + saved pins (`feat/kakao-map-sdk` → merged 2026-06-20)

- **KakaoMapsSDK-SPM** (2.12.14) — replaces Apple MapKit on main map tab
- **`KAKAO_NATIVE_APP_KEY`** — `SDKInitializer.InitSDK(appKey:)` at app launch via `KakaoMapSDKBootstrap`
- **`KakaoMapView`** — `UIViewRepresentable` + inline `Coordinator`; 구미 center **level 12**; `viewRect` sync; saved-place `Poi` pins with animated focus
- All `SavedPlace` records as Kakao `Poi`; tap → **`MapPlaceSheet`** (medium/large detents)
- Floating toolbar unchanged (overlaid at bottom)

**Key paths:** `KakaoMapView.swift`, `KakaoMapSDKBootstrap.swift`, `KakaoMapPinImageRenderer.swift`, `MapPlaceSheet.swift`, `MapTabView.swift`, `SavedPlaceMapPin.swift`, `MapPinPointer.swift`, `Secrets.swift`, `gumimap_v2App.swift`

### List place cards & header (`feat/list-place-card-demo` → merged 2026-06-20)

- **`SavedPlaceCard`** — category icon (44pt) + name, short category, address, enrichment teaser
- **`PlaceCategoryIcon`** — Kakao category → SF Symbol + tint
- **`ListTabView`** — `ScrollView` + card rows (replaces plain text list rows)
- **`ListHeaderPromptLibrary`** — 8 curated two-tone lines per sub-tab (가본 곳 / 가고 싶은 곳)
- **`ListHeaderStore`** + **`StyledListHeader`** — random rotation on map→list entry; per-tab cache on sub-tab switch
- 영업중 badge when `grokDetail.isCurrentlyOpen`; insight line: 분위기 → 특징

**Key paths:** `SavedPlaceCard.swift`, `PlaceCategoryIcon.swift`, `ListHeaderPromptLibrary.swift`, `ListHeaderStore.swift`, `StyledListHeader.swift`, `ListTabView.swift`, `RootView.swift`

### Place detail polish (`feat/list-place-card-demo` → merged 2026-06-20)

- Removed **header subtitle** under navigation title (address no longer duplicated)
- Grok enrichment still runs; additional info cards appear with staggered reveal when ready
- SSE progress checklist was removed here, then restored on `fix/grok-sse-live-activity`
- Register row still shows **영업중** badge and disables during load

**Key paths:** `PlaceDetailView.swift`, `PlaceDetailViewModel.swift`, `GrokPlaceSearchService.swift`

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
  - `GrokPlaceSearchService` → xAI Responses API SSE (no UI progress log)
  - UI shows 6 curated fields: 영업시간, 브레이크타임, 휴무일, 주차, 분위기, 특징
  - Extra fields + reviews stored in model; reviews shown as bullet card
  - `businessHours` used for **영업중** badge on register row
- Staggered reveal after fetch completes

## What Is on the App Now

- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** Kakao live search → tap result → discovery detail with Grok enrichment → 등록하기 → list tab saved detail
- **List tabs:** 가본 곳 / 가고 싶은 곳 — two-tone header prompt + icon place cards; tap card → saved detail; map icon → map tab + zoom + sheet
- **Discovery detail:** large title + Kakao baseline cards → additional info; already-saved banner + disabled register row; formatted business hours
- **Saved detail:** `...` menu → 정보 수정, 리스트 변경, or 삭제; "지도에서 보기" → map focus + sheet
- **Map tab:** full-screen Kakao Map centered on 구미 (level 12); round-head pins with short tail (green = 가본 곳, blue = 가고 싶은 곳); tap pin → bottom sheet (주소·추가정보·상세 보기·리스트 변경/삭제)
- API keys in `Config/secrets.local.env` (gitignored); template at `Config/secrets.example.env`

## Key Paths

| Path | Purpose |
|------|---------|
| `Config/secrets.local.env` | Local API keys (gitignored) |
| `Config/secrets.example.env` | Key name template |
| `scripts/generate-secrets.sh` | Build-time secrets generation |
| `gumimap-v2/Config/Secrets.swift` | Runtime secrets accessor |
| `gumimap-v2/Models/SavedPlace.swift` | SwiftData saved place model |
| `gumimap-v2/Services/PlaceStore.swift` | Register, update, delete, move, enrichment update |
| `gumimap-v2/Services/PlaceEnrichmentService.swift` | Background Grok enrichment |
| `gumimap-v2/Services/ListHeaderStore.swift` | List header prompt rotation |
| `gumimap-v2/Services/KakaoLocalService.swift` | Kakao Local API client |
| `gumimap-v2/Services/GrokPlaceSearchService.swift` | Grok SSE single search |
| `gumimap-v2/Models/GrokPlaceDetail.swift` | Enrichment model + visible field mapping |
| `gumimap-v2/Models/ListHeaderPromptLibrary.swift` | Curated list header copy pool |
| `gumimap-v2/Services/BusinessHoursParser.swift` | Open-now + hours display formatting |
| `gumimap-v2/Features/PlaceDetail/` | Detail screen, edit sheet, view model, list-kind sheet |
| `gumimap-v2/Features/Map/` | Kakao map tab, pins, place sheet |
| `gumimap-v2/Features/Search/` | Search UI + `Place` model |
| `gumimap-v2/Features/List/` | List tab, cards, styled header |
| `gumimap-v2/App/RootView.swift` | Navigation root |
| `gumimap-v2/Navigation/` | Routes, toolbar, tab router |
| `scripts/run-simulator.sh` | Build, install, launch |
| `AGENTS.md` | Agent index and hard rules |
| `docs/HANDOFF.md` | This file |