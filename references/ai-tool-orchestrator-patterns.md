# AI tool orchestrator patterns

This note captures design patterns from open-source/local-first tools that coordinate other AI coding tools. Use it to improve Claude Commander when the user wants to provide only a high-level goal and have the system drive the rest.

## Reference set

- Shep — local-first prompt-to-PR orchestrator for terminal coding agents; uses specs, worktrees, PR/CI loops, dashboard, and human merge control.
- Crewly — orchestrator with role-based agent profiles, shared memory/knowledge base, live terminal dashboard, and mixed Claude Code/Gemini/Codex teams.
- ORCH — lead-agent decomposition, task routing, separate worktrees, monitoring, retries/backoff, stall/zombie cleanup, adapters, and approval gates.
- Agent Orchestrator — browser control plane with Kanban, live terminal access, worktree isolation, issue tracker integration, PR/CI/review loop.
- Ruah — worktree isolation plus file-level claims, workflow DAGs, governance gates, and dependency-ordered merges.
- Agetor — local kanban/control hub with per-task branches/checkouts, isolated runtime environments, transcripts, permission prompts, rerun/cancel/delete controls.
- Phasr — multi-agent workspace with review-first flow, real-time diffs, explicit approve/reject/request-changes merge controls.
- strIDEterm — terminal workspace with supervised Worker + Judge loops, deterministic checks, worktree branches, Git/Docker/review support.

## Patterns Commander should adopt

### 1. Goal-only intake contract

When the user gives only a goal, Commander should infer everything it can and ask only user-owned decisions. Convert the goal into a run contract:

- goal statement;
- non-goals and forbidden actions;
- success criteria / definition of done;
- constraints from repo/memory;
- destructive-operation policy;
- push/PR/deploy policy;
- expected verification evidence;
- autonomy level and stop conditions.

If a decision is not user-owned, do not ask. Research, inspect, and choose a sensible default.

### 2. Spec before workers

For non-trivial tasks, generate a short spec before launching implementers:

- reference brief;
- proposed architecture/approach;
- task DAG;
- file/path claims;
- acceptance criteria;
- verification plan;
- review rubric;
- rollback/integration plan.

The spec is the handoff from Commander reasoning to worker execution.

### 3. File-level claims

Before parallel work, assign claimed paths/areas:

- `owned`: worker may edit;
- `shared`: worker may edit only with explicit coordination/review;
- `read_only`: worker may inspect but not modify;
- `forbidden`: worker must not touch.

Use claims to avoid parallel agents editing the same files unless intentionally staged.

### 4. Workflow DAG, not just a list

Represent tasks as a dependency graph:

- researcher/spec tasks first;
- independent implementers in parallel;
- test/verification tasks after relevant implementation;
- review tasks after stable diff hashes;
- integration tasks in dependency order.

Merge only tasks whose dependencies and review gates passed.

### 5. Adapter profile per tool

Different AI tools behave differently. Store a runtime profile per worker/tool:

- command template;
- working directory behavior;
- prompt input method;
- permission/sandbox expectations;
- output/log format;
- completion marker;
- interrupt/stop method;
- known failure modes;
- whether it can review, implement, test, or only research.

Do not assume every CLI behaves like Codex.

### 6. Live state machine

Every task should have a lifecycle state:

- `planned`
- `ready`
- `running`
- `blocked_waiting_input`
- `blocked_failed_check`
- `succeeded_unreviewed`
- `review_failed_revise`
- `review_passed`
- `merged_local`
- `failed_abort`

Persist state under the run directory so Commander can resume goal-only work after wakeups or restarts.

### 7. Watch, retry, and stop conditions

Commander should actively detect:

- stalled processes;
- zombie/dead workers with no exit artifact;
- repeated tool failures;
- scope drift;
- safety-boundary violations;
- failing tests or missing verification;
- merge conflicts.

Retries must be capped and include concrete findings. If autonomy cannot safely continue, stop and ask the user.

### 8. Review-first merge control

Borrow review-first patterns:

- line/file-specific findings;
- severity levels: `blocking`, `important`, `suggestion`, `nit`;
- diff hash reviewed;
- verification evidence echoed;
- explicit merge recommendation;
- stale review invalidated by any diff change.

Merge remains local unless separately authorized.

### 9. Evidence trail and observability

For each run, preserve:

- goal contract;
- reference brief;
- task DAG;
- prompts;
- logs/transcripts;
- worker state JSON;
- status snapshots;
- diffs/stats/hashes;
- verification outputs;
- review decisions;
- integration attempts;
- final report.

The user should be able to audit what happened without trusting summaries.

### 10. Goal-only finalization loop

When the user wants “只给目标就能完成”, Commander should keep progressing until one of these terminal conditions:

- all tasks reviewed and locally integrated;
- blocked on a genuinely user-owned decision;
- safety boundary hit;
- max attempts/review cycles exhausted;
- verification cannot be run and no safe substitute exists.

Do not stop merely because a worker says it is done.

## Patterns to avoid

- Launching workers before reference/spec/context is ready.
- Letting multiple workers edit the same high-risk file without dependency ordering.
- Treating logs as success evidence without running verification.
- Auto-merging or pushing because an agent says the task is done.
- Copying external code/assets without license handling.
- Asking the user implementation questions that tools/research can answer.
- Hidden autonomous execution with no persisted state or audit trail.
