# TestFlight: Empty Marketing Version — Issue & Resolution

Last updated: 2026-06-27  
Branch: `fix/fastlane-empty-marketing-version`  
Verified CI run: [TestFlight workflow #28280345028](https://github.com/Gaoridang/gumimap-v2/actions/runs/28280345028)

---

## Issue

### Summary

After merging build-only TestFlight versioning (`chore/testflight-build-only-versioning`), pushes to `main` failed during `fastlane beta` with an App Store Connect API error: **`versionString` is required**. The lane logged an empty marketing version (`Using marketing version  (build N)`), so `ensure_version!` could not create or update the version train.

### Symptoms

| Observation | Detail |
|-------------|--------|
| CI failure | `TestFlight` workflow failed on **Deploy to TestFlight** (~10–20s), not during compile |
| Fastlane log | `Using marketing version  (build 3)` — version string missing between words |
| API error | `The provided entity is missing a required attribute 'versionString'` at `ensure_asc_version` → `app.ensure_version!` |
| Local Mac | Same empty read possible when running `bundle exec fastlane beta` from repo root |
| Last known good | Builds on `0.0.9` before pre-release reset to `0.0.1` in `project.pbxproj` |

### Example failure (CI)

```
[08:33:10]: --- Step: get_version_number ---
[08:33:11]: Using marketing version  (build 3)
...
Unable to find Xcode build setting: MARKETING_VERSION
...
versionString is required
```

Run reference: [failed workflow #28156979107](https://github.com/Gaoridang/gumimap-v2/actions/runs/28156979107)

### Root causes (layered)

1. **`get_version_number` unreliable for objectVersion 77**  
   This project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ folder layout). Fastlane’s `get_version_number` often returns an empty string even though `MARKETING_VERSION = 0.0.1` is set on the `gumimap-v2` target in `project.pbxproj`.

2. **Wrong working directory inside lanes**  
   Fastlane `chdir`s into `fastlane/` before running lanes. A relative `xcodeproj: "gumimap-v2.xcodeproj"` resolved to a non-existent path (`fastlane/gumimap-v2.xcodeproj`).

3. **`xcodeproj` gem `resolve_build_setting` gap on CI**  
   `ProjectMarketingVersion.read` initially relied only on `config.resolve_build_setting("MARKETING_VERSION")`, which returned empty on GitHub runners despite direct `build_settings` values being present.

4. **Lane ordering**  
   Reading the version after `install_api_signing` / `update_code_signing_settings` increased failure rates (signing mutation + broken reader).

5. **Invalid Fastlane parameters**  
   `increment_version_number` and `increment_build_number` were called with `target:` — not supported by the installed Fastlane version (`Could not find option 'target'`).

6. **Verification script gaps (discovered during Mac test)**  
   `scripts/verify-marketing-version.sh` was not executable in CI and needed `bundle exec` + `minitest` in the Gemfile.

### Impact

- No TestFlight uploads from `main` after the build-only versioning merge (2026-06-25).
- Safe dev flow blocked at the final **merge → TestFlight → device check** step.
- Manual `workflow_dispatch` on the fix branch reproduced the same errors until all layers above were addressed.

### Reproduction

```bash
# From repo root (Homebrew Ruby 3.4 + bundle)
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
cd gumimap-v2   # fastlane working dir — relative xcodeproj breaks
bundle exec fastlane run get_version_number xcodeproj:gumimap-v2.xcodeproj target:gumimap-v2
# → file not found under fastlane/

# Contract checks (no ASC secrets needed)
bash scripts/verify-marketing-version.sh
bundle exec fastlane signing_controlled_error_check   # expects controlled signing message
```

Full local upload still requires `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH`.

---

## Resolution

### Summary

Replace Fastlane’s version read with a dedicated **`ProjectMarketingVersion`** helper, use an **absolute `xcodeproj` path**, resolve versions **before** signing changes, and align increment actions with supported parameters. Add a **pre-deploy verification script** in CI.

### Fixes (by commit theme)

| # | Change | Why |
|---|--------|-----|
| 1 | `fastlane/lib/project_marketing_version.rb` | Read `MARKETING_VERSION` via `xcodeproj`, with direct `build_settings` fallback |
| 2 | `read_project_marketing_version` uses helper only | Avoid empty `get_version_number` inside lane context |
| 3 | `XCODEPROJ = File.expand_path("../gumimap-v2.xcodeproj", __dir__)` | Correct path after Fastlane `chdir` to `fastlane/` |
| 4 | `prepare_version_numbers` before `install_api_signing` | Version read happens on unmutated `pbxproj` |
| 5 | Drop `target:` from `increment_version_number` / `increment_build_number` | Match Fastlane 2.236 API |
| 6 | `scripts/verify-marketing-version.sh` + CI step | Catch regressions before `fastlane beta` |
| 7 | `Gemfile` → `minitest` (development), `bundle exec` in verify script | Specs run consistently on Mac and CI |
| 8 | `bash scripts/verify-marketing-version.sh` in workflow | Avoid executable-bit drift on checkout |

### Key files

| Path | Role |
|------|------|
| `fastlane/Fastfile` | Lane order, absolute paths, `read_project_marketing_version` |
| `fastlane/lib/project_marketing_version.rb` | Reliable MARKETING_VERSION read for objectVersion 77 |
| `fastlane/spec/marketing_version_spec.rb` | Fastfile structure contract |
| `fastlane/spec/get_version_number_runtime_spec.rb` | Runtime read + optional action check |
| `scripts/verify-marketing-version.sh` | CI + local preflight |
| `.github/workflows/testflight.yml` | Verify step before deploy |

### Verification

**Local (Mac, 2026-06-27)**

```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
bash scripts/verify-testflight-signing-contract.sh
bash scripts/verify-marketing-version.sh
# Marketing version verification passed. Logs in /tmp/fastlane-verify
```

**CI (fix branch, workflow_dispatch)**

| Step | Result |
|------|--------|
| Verify controlled signing error path | ✅ |
| Verify marketing version resolution | ✅ |
| Deploy to TestFlight (`fastlane beta`) | ✅ — **0.0.1 (3)** uploaded in ~2m 35s |

Success run: https://github.com/Gaoridang/gumimap-v2/actions/runs/28280345028

### Expected behavior after merge

- `main` push (non-docs paths) → TestFlight keeps **marketing version** from `project.pbxproj` (`0.0.1`), **build number +1** per upload.
- Empty `versionString` / `ensure_version!` failures should not recur while `MARKETING_VERSION` remains set on the app target.

### Rollout

1. Open PR: `fix/fastlane-empty-marketing-version` → `main`
2. Confirm PR Build ✅
3. Merge → TestFlight on `main` should upload automatically
4. Confirm on device: **TestFlight → 0.0.1 (build N)**

### Local full beta (optional)

Add ASC fields to gitignored `Config/secrets.local.env` (see `Config/secrets.example.env`), then:

```bash
./scripts/run-testflight-local.sh
```

First run without `fastlane/signing` cache defaults to `ALLOW_CREATE_DISTRIBUTION_CERT=true`. Later runs reuse cache when present.

### Related

- Original regression introduced by build-only versioning on `main` (`d99f7e7`)
- Prior successful uploads used auto-bumped marketing version (`0.0.9`) before pre-release reset
- Signing cache / controlled-error path unchanged — see `docs/HANDOFF.md` TestFlight signing section