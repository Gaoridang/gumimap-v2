# Session Handoff — gumimap-v2

Last updated: 2026-06-20

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `feat/saved-place-edit-delete` |
| Next branch | (create before first code change on next task) |
| Working tree | Clean after commit |
| Last verified | xcodebuild + iOS 26.5 simulator launch (2026-06-20) |

## Next Task — Backlog

Pick up from backlog below (map pins, Kakao search gaps, etc.).

## Shipped on `feat/saved-place-edit-delete`

- **Saved detail menu only** for edit/delete (list swipe actions removed)
- **Saved detail menu (`...`):** "리스트 변경" and "삭제" with confirmation dialog
- `PlaceStore.delete()` and `PlaceStore.moveListKind()` — move merges enrichment if target already exists
- `PlaceRegistrationSheet` renamed/generalized to `PlaceListKindSheet` (register + move; shows "현재" for active list)
- `TabRouter.replaceSavedPlaceDetail()` — after move from detail, switches sub-tab and replaces nav destination

**Key paths**

| Path | Notes |
|------|-------|
| `gumimap-v2/Services/PlaceStore.swift` | delete, moveListKind |
| `gumimap-v2/Features/PlaceDetail/PlaceListKindSheet.swift` | List-kind picker sheet |
| `gumimap-v2/Features/List/ListTabView.swift` | Swipe delete/move |
| `gumimap-v2/Features/PlaceDetail/PlaceDetailView.swift` | Saved-place menu |
| `gumimap-v2/Navigation/TabRouter.swift` | `replaceSavedPlaceDetail` |

## Shipped on `feat/place-detail-sticky-header`

- `PlaceDetailView` uses native large navigation title collapse (system scroll-to-inline header)

## Shipped on `feat/place-enrichment-background`

- Register button disabled during Grok loading (`추가 정보 확인 중`) — prevents accidental sheet while enrichment runs
- `PlaceEnrichmentService` schedules background Grok fetch when a place is saved without enrichment
- Saved detail view auto-refreshes when background enrichment completes

## Shipped on `feat/place-register`

### Place registration flow

- **등록하기** button opens `PlaceListKindSheet` (가본 곳 / 가고 싶은 곳)
- `PlaceStore` persists `Place` + optional `GrokPlaceDetail` via SwiftData `SavedPlace`
- Upsert by composite id `kakaoPlaceId-listKind`
- After save: `TabRouter.completeRegistration` clears search stack → list tab + sub-tab → saved detail push
- `PlaceDetailView` dual mode: `.discovery` (Grok fetch) / `.saved` (cached enrichment, no register button)
- `ListTabView` shows saved places per sub-tab via `@Query` (respects top safe area)

**Key paths**

| Path | Notes |
|------|-------|
| `gumimap-v2/Models/SavedPlace.swift` | SwiftData model |
| `gumimap-v2/Services/PlaceStore.swift` | Register + lookup |
| `gumimap-v2/Features/PlaceDetail/PlaceListKindSheet.swift` | List-kind picker sheet |
| `gumimap-v2/Features/PlaceDetail/PlaceDetailViewModel.swift` | Discovery/saved modes |
| `gumimap-v2/Features/List/ListTabView.swift` | Saved place list |
| `gumimap-v2/Navigation/TabRouter.swift` | `completeRegistration` |
| `gumimap-v2/Navigation/AppRoute.swift` | `.savedPlaceDetail(id:)` |

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
- Staggered reveal after SSE completes

## What Is on the App Now

- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** Kakao live search → tap result → `PlaceDetailView` with Grok enrichment → 등록하기 → list tab saved detail
- **List tabs:** 가본 곳 / 가고 싶은 곳 show persisted places; tap row → saved detail; edit/delete via detail menu
- **Saved detail:** `...` menu for list change or delete
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