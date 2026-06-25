# PR Build Optimization (Strategy A + B)

## Summary

PR Build combines **DerivedData + SPM caching** (Strategy A) with **xcodebuild compile flags** (Strategy B).

| Scenario | Est. duration | vs. ~4 min baseline |
|----------|---------------|---------------------|
| Cold | ~2.5–3 min | 25–40% |
| Warm (typical Swift PR) | ~1.5–2.5 min | 40–60% |

## Cached paths

| Path | Purpose |
|------|---------|
| `/tmp/gumimap-v2-ci-build` | Xcode DerivedData |
| `/tmp/gumimap-v2-spm-packages` | SPM clones (`-clonedSourcePackagesDirPath`) |

Cache key hashes `project.pbxproj`, `Package.resolved`, and app/test Swift sources. Partial `restore-keys` reuse SPM + DerivedData when only Swift changes.

## Build flags (Strategy B)

- `generic/platform=iOS Simulator` destination
- `-jobs` + `-parallelizeTargets`
- `ONLY_ACTIVE_ARCH=YES`, `COMPILER_INDEX_STORE_ENABLE=NO`, reduced debug overhead

Override locally: `CI_USE_NAMED_DESTINATION=1`, `CI_DESTINATION=…`, `XCODE_BUILD_JOBS=4`.

## TestFlight trigger

`testflight.yml` uses `paths-ignore` for `docs/**`, `AGENTS.md`, and PR template — docs-only pushes to `main` do not deploy.

## Rollback

Revert `.github/workflows/pr-build.yml` and `scripts/ci-build.sh`. Delete `pr-build-v1-*` cache entries if needed.