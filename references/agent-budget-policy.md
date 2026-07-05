# Agent budget and fan-out policy

Claude Commander must balance quality, speed, and quota. A goal-only workflow is not permission to spawn unlimited agents. Uncontrolled fan-out is a failure mode.

## Definitions

Count all of these as budgeted AI units:

- Claude Code `Agent` subagents.
- Codex workers launched by `launch-worker.sh`.
- Optional Codex review runs.
- Any future runtime adapter workers.

Do not count local shell helper commands, `WebSearch`, `WebFetch`, `Read`, `Edit`, or deterministic scripts as agents.

## Default caps

Unless the user explicitly authorizes more for the current run:

- Max concurrently running implementation workers: **2**.
- Max concurrently running reviewers: **1**.
- Max concurrently running researchers: **1**.
- Max concurrently running spec/planning agents: **1**.
- Max concurrently running budgeted AI units across all roles: **3**.
- Max total budgeted AI units launched in one run phase: **5**.
- Max total budgeted AI units launched in a full run before asking again: **8**.
- Max leaf implementation tasks in the first DAG: **6**. If more are found, batch them into later phases.
- Max ready tasks launched at once: **2**.

If the user asks for higher scale, record that authorization in `goal-contract.md` and `run.json` with the new numbers.

## Same-role reuse rule

Do not open a new agent for the same role and topic while an existing one still has usable context.

Reuse the existing agent via `SendMessage`, continue in the main conversation, or batch the work into the same prompt unless one of these is true:

1. The existing agent reached a terminal decision/result.
2. The existing agent is blocked or failed.
3. The new work is materially independent and caps allow it.
4. The existing agent context is clearly too full to continue efficiently.

## Context threshold heuristic

There is no exact token meter in this skill, so use these practical thresholds:

- If an agent has not produced a consolidated brief/result yet, do **not** spawn another same-role agent.
- If a researcher/spec/reviewer can cover more items in the same prompt without losing clarity, batch them.
- Spawn a replacement same-role agent only after saving a compact handoff summary under the run directory when the current conversation/transcript is long enough that continuing would be worse than summarizing.
- For reviewers, one reviewer may review up to 3 small related diffs in one pass. Use separate reviewers only for unrelated high-risk areas or after the cap is explicitly raised.

## Research policy

Reference-first does not mean agent-first.

Default order:

1. Use WebSearch/WebFetch or direct docs/pages in the main conversation.
2. Summarize into `references/reference-brief.md`.
3. Use at most one researcher agent only if the research surface is broad enough to justify it.
4. Never spawn one researcher per source by default.

## Decomposition policy

Avoid tiny-task explosion.

- Prefer 2-4 meaningful tasks for a normal feature.
- Use 5-6 tasks only when file ownership is clearly separate.
- Put extra work into backlog phases instead of launching everything.
- Collapse tiny edits into a single worker when they share files or verification.
- Do not create more worker tasks than can be reviewed and integrated in the same run budget.

## Review policy

Review is mandatory, but review fan-out is capped.

- Default: one reviewer pass per worker batch or per high-risk worker.
- Batch related small diffs into one review prompt when possible.
- Do not launch a separate reviewer agent for every tiny task if a single reviewer can assess them reliably.
- Any diff change after review still invalidates that review.

## When to ask the user

Ask before exceeding any default cap. The question must include:

- why the extra agent(s) are needed;
- expected additional count;
- cost/latency trade-off;
- recommended lower-cost alternative.

If the user does not answer, stay within default caps.

## Run artifact requirements

Every run should record:

- `budgets` in `run.json`;
- budget assumptions in `goal-contract.md`;
- current phase and launched counts in status/final report;
- explicit user authorization if caps were raised.
