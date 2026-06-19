# Agent Workflow Rules

**Applies to:** All AI agent sessions on `gumimap-v2`

## 1. Scope Boundary

- The project root is `gumimap-v2/` (the folder containing this `.xcodeproj`).
- **Never** reference, read, or modify files outside this directory.
- Do not import patterns, scripts, or configs from parent folders or sibling projects.
- All paths, scripts, and git commands run from `gumimap-v2/`.

## 2. Branch per Task

Create a branch **before the first code change** for each new implementation task.

| Prefix | Use for |
|--------|---------|
| `feat/` | New feature or UI |
| `fix/` | Bug fix |
| `refactor/` | Structural change, no behavior change |
| `chore/` | Tooling, docs, config |

```bash
git checkout main
git checkout -b <type>/<short-description>
```

Skip branching for read-only sessions (questions, reviews, planning) or when the user says to stay on the current branch.

## 3. Commit on Completion

Commit when:

1. All requested changes are implemented
2. Simulator verification passed (when applicable)
3. `docs/HANDOFF.md` is updated
4. There are uncommitted changes

```bash
git branch --show-current
git status
git add <relevant-files>
git commit -m "Short imperative summary"
```

Do not commit when the user explicitly says not to, or when the session was read-only.

## 4. Handoff Document

After each completed task, update `docs/HANDOFF.md`:

- Active branch and working tree state
- What was shipped in this task
- Next tasks and priorities
- Key file paths if new entry points were added

Keep it concise. See the template sections in `HANDOFF.md`.

## 5. Latest SwiftUI Code

Write modern SwiftUI for iOS 18+:

- `@Observable` over `ObservableObject` for new view models
- `@Environment` and `@Bindable` where appropriate
- Structured concurrency (`async`/`await`, `Task`, actors)
- Swift 6 concurrency safety (`@MainActor`, `Sendable`)
- Prefer native SwiftUI APIs over UIKit bridges unless required

## 6. Complex Tasks — Demo First

When a task is complex (new architecture, unfamiliar APIs, multi-screen flows, or significant UX decisions):

1. Launch sub-agents to research best practices and current SwiftUI patterns
2. Build a **minimal demo** that proves the approach
3. Present the demo to the user for review
4. Only proceed to full implementation after user approval

## 7. Simulator Verification

After completing work that touches app code, UI, assets, or build settings:

```bash
chmod +x scripts/run-simulator.sh
./scripts/run-simulator.sh
```

**Done when:** script exits 0 and `com.ijaejun.gumimap-v2` launches in the simulator.

## 8. No Unit Tests

- Do **not** write or modify files in `gumimap-v2Tests/`
- Do **not** run `xcodebuild test` or unit test targets
- Verification is via build + simulator launch only

## References

- [AGENTS.md](../AGENTS.md)
- [HANDOFF.md](HANDOFF.md)