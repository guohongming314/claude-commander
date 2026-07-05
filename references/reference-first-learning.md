# Reference-first learning protocol

Commander should learn from excellent public examples before producing substantial work. The goal is not to copy code; it is to raise the quality of decomposition, prompts, review gates, and verification.

## Why this exists

Good implementation usually starts from seeing good precedent. For non-trivial product, architecture, gameplay, UI, tooling, testing, or systems work, Commander must study comparable public examples before launching implementers.

## When to run

Run this before task decomposition unless the work is a trivial mechanical edit, the user explicitly says not to research, or network access is unavailable.

Typical triggers:

- new feature or architecture work;
- gameplay/system design;
- multiplayer/networking design;
- UI/UX and tooling design;
- test/CI/release automation;
- refactors with multiple valid approaches;
- any task where prior art could change the plan.

## Source selection rubric

Prefer 2-5 sources with these qualities:

1. Public and accessible without private credentials.
2. Reputable, maintained, or widely referenced.
3. Similar constraints to the current task.
4. Concrete implementation/docs rather than pure marketing.
5. License is visible or source is used only as conceptual reference.

For this project, prefer Godot 4, cooperative/multiplayer, small vertical-slice games, data-driven validation, and local-first dev tooling examples.

## What to extract

For every source, capture:

- source name and URL;
- why it is relevant;
- patterns to reuse;
- trade-offs or limitations;
- anti-patterns to avoid;
- licensing/source hygiene notes.

## Applying the research

Commander must synthesize decisions, not dump links at workers.

Use the brief to improve:

- task boundaries and sequencing;
- acceptance criteria;
- worker prompts;
- verification commands;
- reviewer rubric;
- merge gate requirements;
- final risk report.

Workers should adapt ideas to this repo. Do not copy substantial external code/assets/text unless license compatibility and attribution are explicit.

## Proven patterns from similar AI coding tools

These are reference-derived patterns that fit Claude Commander itself:

- **Git/worktree isolation:** Similar multi-agent coding orchestrators isolate each task in its own git worktree and branch so parallel agents do not collide.
- **Local-first/human-controlled merge:** Keep work local by default; humans or the Commander control final merge/push. Do not auto-publish.
- **Spec before execution:** Convert the goal into an explicit spec/brief before implementation. If research changes the approach, update the plan before workers launch.
- **Git-first reversibility:** Keep diffs reviewable, commit or snapshot changes at clear gates, and rely on normal git tools for rollback.
- **Evidence trail:** Preserve prompts, logs, diffs, test output, review decisions, and hashes so each result is auditable.
- **Reproducible verification:** Prefer deterministic commands with pass/fail evidence. If possible, mimic benchmark-style runs: fixed base ref, task id, run id, logs, and final verdict.
- **Line-level actionable review:** Reviews should separate blocking issues from suggestions and include file/line evidence where possible.
- **Repo-specific review rules:** Reviewers should apply project-specific constraints, style, product direction, and safety boundaries.
- **Auto-fix only behind gates:** Retrying failures is useful, but every revision must preserve scope and rerun review if the diff changes.

## Reference examples behind these patterns

- Aider: terminal AI pair programming with repo map, automatic commits, git diff/undo, and lint/test loops. Apache-2.0.
- OpenHands: autonomous software development platform with sandbox warnings, PR/code-review workflows, inline review comments, configurable review skills, and human-in-the-loop triggers.
- SWE-agent / SWE-bench: coding-agent task loops and benchmark-style evaluation using real issues, reproducible environments, run ids, logs, and pass/fail evidence. MIT.
- Shep / dmux-style orchestrators: parallel AI coding agents using git worktrees, terminal sessions, local-first execution, review/CI/merge gates, and human oversight. Check exact license/source before copying any implementation.

## Required reference brief format

Save per-run research under the Commander run directory, for example:

```text
references/reference-brief.md
```

Use this structure:

```markdown
# Reference brief: <goal>

## Sources studied

- <Name> — <URL> — why relevant — license/source note

## Patterns to adopt

- ...

## Patterns to avoid

- ...

## Decisions for this repo

- ...

## Impact on worker tasks

- Task <id>: ...

## Skipped or uncertain areas

- ...
```
