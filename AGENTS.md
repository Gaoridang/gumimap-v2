# AGENTS.md — gumimap-v2

This is the single source of truth for all AI coding agents (Grok, Claude, Cursor, etc.) working on this project.

**Always read this file first** at the start of every session.

## Index

- [Agent Workflow Rules](docs/agent-workflow.md)
- [Session Handoff](docs/HANDOFF.md)
- [Cursor Rules](.cursor/rules/) — auto-applied per session

## Hard Rules (Non-Negotiable)

1. **Scope boundary** — Work only inside `gumimap-v2/`. Do not read, reference, or modify files in parent directories or sibling projects.
2. **Branch per task** — Create a feature branch before the first code change on each new task.
3. **Commit on completion** — Commit when a task is done and verified.
4. **Handoff document** — Update `docs/HANDOFF.md` after each completed task.
5. **Latest SwiftUI** — Use modern SwiftUI patterns (iOS 18+, Swift 6 idioms, `@Observable`, structured concurrency).
6. **Complex tasks** — Research best practices via sub-agents, build a demo first, and get user review before full implementation.
7. **Simulator verification** — Run the app in the iOS Simulator after completing work that touches app code, UI, assets, or build settings.
8. **No unit tests** — Do not write, run, or maintain unit tests in `gumimap-v2Tests/`.

## Session Start Checklist

1. Read this file and `docs/HANDOFF.md`
2. `git status` and check out the active branch listed in HANDOFF
3. Confirm you are working only within `gumimap-v2/`

## Session End Checklist (After a Completed Task)

1. Verify build and simulator launch (`scripts/run-simulator.sh`)
2. Update `docs/HANDOFF.md`
3. Commit on the task branch
4. Leave the branch as-is unless the user asks to merge

---

**End of core index. Add more sections below as the project grows.**