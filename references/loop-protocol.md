# Loop protocol

This skill supports bounded loop-style progression. It does not create unbounded hooks in v1.

## When to schedule wakeups

External Codex processes launched with `codex-unsafe` are not harness-tracked. After launching them, use `ScheduleWakeup` when the user asked for loop/autonomous operation.

Recommended delays:

- ~270 seconds while actively polling short Codex work.
- 1200+ seconds as a fallback heartbeat if work may take longer or the state is mostly idle.

Avoid 300 seconds exactly.

## Each loop iteration

1. Load run state.
2. Check worker process status and exit artifact status (`running`, `succeeded`, `failed`, `unknown_dead`).
3. Read recent logs or last-message files.
4. Check git status in worktrees.
5. Decide one next action:
   - keep waiting;
   - review completed worker;
   - revise failed worker;
   - integrate passed worker;
   - ask user for a true decision;
   - abort on safety violation.
6. Update run state/report.
7. Schedule the next wakeup only if there is useful autonomous work remaining.

## Stop conditions

- all tasks integrated or intentionally skipped;
- reviewer/gate failure exceeds attempt cap;
- worker violates safety boundary;
- user decision required;
- max runtime reached.
