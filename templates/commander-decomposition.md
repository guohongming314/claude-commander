# Commander decomposition

The user provided this high-level goal:

```text
{{GOAL}}
```

Explore the repository, learn from relevant high-quality public examples when the work is non-trivial, and decompose the goal into independent, worktree-safe tasks.

Reference-first learning:

- If the goal is product, architecture, gameplay, UI, tooling, testing, or systems work, first identify 2-5 strong open-source repositories, examples, docs, or writeups worth studying.
- Use WebSearch/WebFetch first; use at most one researcher agent by default.
- Distill what matters: patterns to reuse, trade-offs, anti-patterns to avoid, and licensing/source notes.
- Use the distilled brief to improve the task graph and acceptance criteria.
- Skip only for trivial mechanical edits, offline/no-network situations, or when the user explicitly says not to research; say why if skipped.

Agent budget rules:

- Default max concurrently running budgeted AI units: 3 total, 2 implementers, 1 researcher, 1 spec/planning agent, 1 reviewer.
- Default max launched per phase: 5; default max launched per full run before asking again: 8.
- Default max first-DAG leaf implementation tasks: 6; extra work goes into later phases/backlog.
- Do not spawn another same-role/same-topic agent while an existing one still has useful context; batch or continue via SendMessage.
- Ask the user before exceeding these caps.

Return:

1. Goal contract: goal, non-goals, constraints, forbidden actions, definition of done, verification evidence, autonomy level, stop conditions
2. Reference brief summary with source links or an explicit skip reason
3. Proposed spec/approach before implementation
4. Agent budget plan: phase count, per-role counts, concurrency, reuse/batching decisions, and whether user approval is needed
5. Task DAG with dependencies and lifecycle states
6. File/path claims per task (`owned`, `shared`, `read_only`, `forbidden`)
7. Acceptance criteria per task
8. Suggested verification command and expected evidence per task
9. Files/areas likely affected
10. Risk level, retry limit, and whether the task may run in parallel
11. Suggested worker role/runtime

Constraints:

- Workers will run through `codex-unsafe`, so every task must be isolated to a git worktree.
- No task may push, deploy, publish, or modify external production systems.
- Prefer small, reviewable diffs.
- Do not copy substantial external code/assets/text unless license compatibility is clear and source attribution is recorded.
- Ask the user only for decisions that are genuinely theirs.
