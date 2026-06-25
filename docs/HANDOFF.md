# Session Handoff — gumimap-v2

Last updated: 2026-06-25

## Resume Here

| Field | Value |
|-------|-------|
| Active branch | `chore/testflight-build-only-versioning` |
| Next branch | (create before first code change on next task) |
| GitHub repo | https://github.com/Gaoridang/gumimap-v2 (public) |
| Working tree | #37 merged — PR Build cache+flags; TestFlight skips docs-only pushes |
| Last verified | PR #37 merged; warm PR Build timing TBD |
| Dev environment | Windows (no local Xcode) → PR Build → merge → TestFlight |

### Safe dev flow (no local Xcode)

```
feat|fix|chore/<task>  →  push  →  PR  →  PR Build ✅  →  merge main  →  TestFlight  →  폰 확인
```

See `docs/agent-workflow.md` §9 for full rules.

## Shipped on `feat/random-restaurant-picker` (2026-06-24)

- **`RandomRestaurantButton`** — map main screen pill button "오늘 뭐 먹지?"; Kakao keyword search → random restaurant → discovery detail
- **`RandomRestaurantPicker`** — shuffled 구미 restaurant keywords, filters food categories
- **`TabRouter.openPlaceDetail(_:)`** — navigation helper for discovery detail push

**Key paths:** `RandomRestaurantButton.swift`, `RandomRestaurantPicker.swift`, `MapTabView.swift`, `TabRouter.swift`

## Shipped on `feat/testflight-ci` (2026-06-24)

- **Fastlane `beta` lane** — `cert` + `sigh` via App Store Connect API key, build number auto-increment, TestFlight upload
- **`.github/workflows/testflight.yml`** — `main` push + manual dispatch on `macos-26` / Xcode 26.5
- **Optional manual signing** — `scripts/ci-install-signing.sh` when `BUILD_CERTIFICATE_BASE64` secret is set
- **`scripts/export-signing-for-ci.sh`** — optional helper to export p12/profile for manual signing path
- **`ITSAppUsesNonExemptEncryption = NO`** — skips export-compliance prompt on upload

### GitHub Secrets (configured)

| Secret | Required | Source |
|--------|----------|--------|
| `ASC_KEY_ID` | Yes | App Store Connect API key |
| `ASC_ISSUER_ID` | Yes | App Store Connect → Users and Access |
| `ASC_KEY_CONTENT_BASE64` | Yes | `base64 -i AuthKey_XXX.p8 \| tr -d '\n'` (use `scripts/encode-asc-key-for-ci.sh`) |
| `KAKAO_NATIVE_APP_KEY` | Yes | `Config/secrets.local.env` |
| `KAKAO_REST_API_KEY` | Yes | `Config/secrets.local.env` |
| `XAI_API_KEY` | Yes | `Config/secrets.local.env` |

CI signing uses **Xcode automatic signing** + App Store Connect API key (`-allowProvisioningUpdates`), not manual p12.

**Key paths:** `fastlane/Fastfile`, `.github/workflows/testflight.yml`, `Gemfile`, `scripts/ci-install-signing.sh`

## Shipped on `fix/app-store-upload-icons` (2026-06-24)

- **App icons** — `AppIcon-1024.png` (+ dark/tinted) in `AppIcon.appiconset`; map-pin styling matches `MapPinStyle`
- **`INFOPLIST_KEY_CFBundleIconName = AppIcon`** — fixes App Store Connect 90713
- **`ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`** — ensures 120×120 / 152×152 compiled into bundle
- **`scripts/generate-app-icon.py`** — regenerates icon PNGs when design changes
- **KakaoMapsSDK dSYM** — vendor binary ships without dSYMs; "Upload Symbols Failed" is a warning only and does not block TestFlight upload

**Key paths:** `AppIcon.appiconset/`, `scripts/generate-app-icon.py`, `project.pbxproj`

## Merged on `main` — safe dev flow (`chore/safe-dev-flow` → #13, 2026-06-25)

- **`.github/workflows/pr-build.yml`** — simulator compile check on PRs to `main` and pushes to `feat/**` `fix/**` `chore/**` `refactor/**`
- **`scripts/ci-build.sh`** — shared CI build script (secrets + xcodebuild, no launch)
- **`.github/pull_request_template.md`** — PR summary + TestFlight verification checklist
- **`docs/agent-workflow.md` §9** — safe dev flow for Windows / no-Xcode workflow

**Key paths:** `.github/workflows/pr-build.yml`, `scripts/ci-build.sh`, `.github/pull_request_template.md`, `docs/agent-workflow.md`

## Merged on `main` — place detail map preview (`feat/place-detail-map-preview` → #14, 2026-06-25)

- **`PlaceDetailMapPreview`** — 180pt Kakao map embed at top of place detail; unified teardrop pin; pauses when scrolled off-screen
- **Saved detail** — tap preview → `TabRouter.openSavedPlaceOnMap` (replaces separate "지도에서 보기" row)
- **Discovery detail** — tap preview → opens 카카오맵 URL when available

**Key paths:** `PlaceDetailMapPreview.swift`, `PlaceDetailView.swift`

## Merged on `main` — saved enrichment on-demand (`fix/saved-enrichment-on-demand` → #15, 2026-06-25)

- **Saved detail enrichment** — no longer auto-starts on register or detail entry; runs only when user taps "추가정보 확인"
- **Registration** — saving without prior Grok fetch no longer schedules background enrichment; user opts in from saved detail

**Key paths:** `PlaceDetailViewModel.swift`, `PlaceDetailView.swift`

## Shipped on `main` — TestFlight CI signing (#26–#33, 2026-06-25)

**Problem:** TestFlight #33 failed with `ALLOW_CREATE_DISTRIBUTION_CERT=true` on cache miss. Apple portal held orphaned Distribution certs whose private keys were lost on ephemeral runners; `cert` hit the quota. GitHub Actions cache (`signing-v1`) was never seeded.

**Fix (merged):**
- `revoke_orphaned_distribution_certs` revokes portal `IOS_DISTRIBUTION` + `DISTRIBUTION` certs via ASC API before bootstrap `cert`
- `actions/cache/restore@v4` + `actions/cache/save@v4` with key `signing-v3-*` (content-hash) persists `fastlane/signing/`
- `SigningDecision.resolve` gates `cert()` behind `ALLOW_CREATE_DISTRIBUTION_CERT=="true"` exactly; otherwise `UI.user_error!` with bootstrap instructions (never calls Apple create API)
- `signing_controlled_error_check` lane + `signing-contract` workflow job verify controlled path on `workflow_dispatch` (bootstrap=false)
- `sigh(...)` passes only `api_key`, `app_identifier`, `force` (no keychain options)
- #29: cached p12 import uses keychain password for `set-key-partition-list`
- #33: `grep -qF` for `--- Step: cert ---` check (macOS grep treated dashes as flags)

**Verified:**
- Bootstrap #35–#37 seeded `signing-v3` cache (#28)
- Reuse: #39/#44 deploy — `Reusing cached distribution certificate`, no `--- Step: cert ---`, no quota phrase
- Controlled: #44 `signing-contract` job — `No reusable Distribution certificate is available for CI`, fastlane summary has no `cert` step

**Post-bootstrap:** Delete repo variable `ALLOW_CREATE_DISTRIBUTION_CERT` (or use workflow_dispatch with bootstrap=false) so later runs reuse cached signing:
```powershell
.\scripts\bootstrap-testflight-signing.ps1 -Phase disable
```

**Key paths:** `fastlane/Fastfile`, `fastlane/lib/signing_decision.rb`, `fastlane/spec/signing_decision_spec.rb`, `.github/workflows/testflight.yml`, `scripts/bootstrap-testflight-signing.ps1`, `scripts/verify-testflight-signing-contract.sh`

## In progress — TestFlight build-only versioning (`chore/testflight-build-only-versioning`)

- **`fastlane beta`** — keeps `MARKETING_VERSION` from `project.pbxproj`; only increments global build number from App Store Connect
- **`fastlane release`** — bumps marketing version (patch by default, or `MARKETING_VERSION` env) then uploads; use for App Store releases
- **TestFlight workflow** — `main` push → `beta`; manual dispatch with `release: true` → `release` lane (+ optional `marketing_version` input, e.g. `1.0.0`)

After a release deploy, commit the new `MARKETING_VERSION` in `project.pbxproj` so the repo stays in sync.

**Key paths:** `fastlane/Fastfile`, `.github/workflows/testflight.yml`

## Merged on `main` — PR Build optimization (`chore/pr-build-opt-ab-hybrid` → #37, 2026-06-25)

- **PR Build A+B** — DerivedData + SPM cache (`pr-build-v1-*` keys) + `ci-build.sh` compile flags (generic destination, parallel jobs, index store off)
- **TestFlight `paths-ignore`** — `docs/**`, `AGENTS.md`, PR template; docs-only HANDOFF updates no longer deploy

**Key paths:** `.github/workflows/pr-build.yml`, `.github/workflows/testflight.yml`, `scripts/ci-build.sh`, `docs/pr-build-optimization.md`

## Merged on `main` — pin colors + list filter (`feat/pin-colors-list-filter` → #35, 2026-06-25)

- **`MapPinStyle`** — 가본 곳 초록 / 가고 싶은 곳 파랑 teardrop 핀 (지도·상세 미리보기·SwiftUI 프리뷰)
- **`ListPlaceFilter` + `ListFilterStore` + `ListFilterBar`** — 리스트 탭 정렬(최신순·이름순), 카테고리 칩, 영업중 필터; 서브탭별 설정 유지
- **`ListPlaceMapButton`** — 리스트 종류에 맞는 핀 색상 타일
- **`SavedPlace.shortCategory` / `isOpenNow`** — 필터·카드 공용 헬퍼

**Key paths:** `MapPinLayout.swift`, `KakaoMapPinImageRenderer.swift`, `ListPlaceFilter.swift`, `ListFilterStore.swift`, `ListFilterBar.swift`, `ListTabView.swift`, `ListPlaceMapButton.swift`, `SavedPlace.swift`, `RootView.swift`

## Next Task — Backlog

Pick up from backlog below (use safe dev flow: branch → PR → PR Build → merge → TestFlight).

- Fix `run-simulator.sh` UDID fallback edge cases (Mac local dev only; low priority on Windows/TestFlight workflow)

### Backlog notes (2026-06-25)

- **Removed:** Map sheet edit parity, Kakao REST search gaps, saved detail auto-enrichment.

## Merged / Shipped on `main`

### List UX polish (`feat/list-default-wishlist` + `feat/list-map-button-style` → merged 2026-06-24)

- **`TabRouter`** — default `listSubTab` is `.wishlist`; `openList()` resets to 가고 싶은 곳 when entering from map
- **`ListPlaceMapButton`** — toolbar-pin icon on soft blue tile; matches category icon sizing on list cards

**Key paths:** `TabRouter.swift`, `ListPlaceMapButton.swift`, `ListTabView.swift`

### Optional additional info (`feat/optional-additional-info` → merged 2026-06-24)

- **Discovery detail** — Grok enrichment no longer auto-starts; "추가정보 확인" button triggers SSE progress + additional info cards
- **등록하기** — enabled immediately on Kakao baseline (no wait for Grok)
- **Saved detail** — same "추가정보 확인" button when enrichment is missing; schedules `PlaceEnrichmentService`
- **Spacing** — 추가정보 확인 grouped with baseline action buttons (14pt)

**Key paths:** `PlaceDetailView.swift`, `PlaceDetailViewModel.swift`

### Map pin unified teardrop (`fix/map-pin-top-clip` → merged 2026-06-22)

- **`MapPinLayout`** — shared geometry: 6pt internal head inset + 4pt canvas padding so the round head is never flush with the bitmap edge
- **`MapPinStyle`** — warm yellow fill (`#FAE37A`) + soft blue border (`#4A85C7`), 2pt stroke
- **`MapPinLayout`** — single closed path (circle arc + tail); arc uses `clockwise: true` (UIKit y-down coords) so the full round head renders instead of only the tail
- **`KakaoMapPinImageRenderer`** — fill + stroke rendering at 3× scale; style id `v12-unified`
- **`MapPinPointer` / `SavedPlaceMapPin`** — same layout and colors for map + SwiftUI preview parity

**Key paths:** `MapPinLayout.swift`, `KakaoMapPinImageRenderer.swift`, `MapPinPointer.swift`, `SavedPlaceMapPin.swift`

### Grok SSE live activity restore (`fix/grok-sse-live-activity` → merged 2026-06-22)

- **Discovery detail** — SSE progress checklist visible again while Grok enrichment runs (before 등록하기 unlocks)
- **`PlaceDetailViewModel`** — `progressLog`, `currentProgress`, `showProgress`; wires `onProgress` from `GrokPlaceSearchService`
- **Post-registration background enrichment** — `PlaceEnrichmentService` tracks per-saved-place SSE progress; saved detail shows same checklist while enrichment completes
- **`PlaceEnrichmentService`** — `@Observable`; uses `.environment(PlaceEnrichmentService.self)` for live UI updates

**Key paths:** `PlaceDetailView.swift`, `PlaceDetailViewModel.swift`, `PlaceEnrichmentService.swift`, `RootView.swift`

### Map pins — round head + short tail (`feat/map-teardrop-pin` → merged 2026-06-20, superseded by pin fix above)

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
  - `GrokPlaceSearchService` → xAI Responses API SSE with live progress checklist
  - UI shows 6 curated fields: 영업시간, 브레이크타임, 휴무일, 주차, 분위기, 특징
  - Extra fields + reviews stored in model; reviews shown as bullet card
  - `businessHours` used for **영업중** badge on register row
- Staggered reveal after fetch completes

## What Is on the App Now

- **Map mode toolbar:** `[pin][list] | [search]`
- **List mode toolbar:** `[back●][map-pin-check][bookmark] | [search]`
- **Search:** Kakao live search → tap result → discovery detail (Kakao baseline + optional "추가정보 확인") → 등록하기 anytime → list tab saved detail
- **List tabs:** 가고 싶은 곳 (default) / 가본 곳 — two-tone header prompt + filter bar (정렬·카테고리·영업중) + icon place cards; tap card → saved detail; map icon → map tab + zoom + sheet
- **Discovery detail:** large title + Kakao baseline cards → optional "추가정보 확인" → SSE progress + additional info; 등록하기 available immediately; already-saved banner when applicable
- **Saved detail:** `...` menu → 정보 수정, 리스트 변경, or 삭제; "추가정보 확인" when no enrichment; background enrichment progress when applicable; "지도에서 보기" → map focus + sheet
- **Map tab:** full-screen Kakao Map centered on 구미 (level 12); teardrop pins by list kind (green 가본 곳 / blue 가고 싶은 곳); tap pin → bottom sheet (주소·추가정보·상세 보기·리스트 변경/삭제)
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
| `gumimap-v2/Services/PlaceEnrichmentService.swift` | Background Grok enrichment + SSE progress |
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