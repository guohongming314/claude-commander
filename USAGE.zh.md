# claude-commander 使用指南

`claude-commander` 是一个让 Claude Code 作为“指挥官”来管理 Codex CLI workers 的开发 Skill。

你只需要给一个高层目标，Claude 会负责拆任务、派 Codex 执行、观察进度、安排审查、要求返工，并在通过后做本地集成。

## 一句话用法

```text
/claude-commander <你的开发目标>
```

例如：

```text
/claude-commander 把 Godot 第一关做成可试玩 demo。你自己拆任务，用 Codex workers 分工，每个 worker 独立 worktree，review 后本地合并。
```

如果你希望它持续推进，可以配合 `/loop`：

```text
/loop /claude-commander 修复浏览器灰盒原型的试玩阻塞问题。用 Codex workers 分工，失败就返工，直到验证通过或需要我决策。
```

## 这个 Skill 会做什么

工作流是：

```text
你给目标
↓
Claude Commander 理解项目和目标
↓
生成 goal contract（成功标准、边界、证据、停止条件）
↓
非平凡任务先学习优秀参考，写 reference brief
↓
生成 spec 和 task DAG
↓
给每个任务分配 file/path claims
↓
每个 Codex worker 分配一个独立 git worktree
↓
用 codex-unsafe exec 启动 worker
↓
Commander 观察日志、git status、diff、测试结果
↓
Reviewer 做只读代码审查
↓
不合格则生成返工任务，让 worker 修
↓
合格后只本地集成到 integration branch
↓
输出最终报告
```

## 适合什么任务

适合：

- 比较大的功能开发
- 多文件改动
- 需要多个方向并行推进
- 需要专门 reviewer 审查
- 希望 Codex 做具体执行，Claude 做调度管理
- 希望用 worktree 隔离风险
- 希望用 `/loop` 逐步推进直到完成

不适合：

- 单行小改动
- 简单文案修改
- 不需要 Codex 的普通问答
- 需要立即人工判断的设计取舍

## 推荐提需求方式

你可以直接说目标，不需要自己拆任务。

好例子：

```text
/claude-commander 把当前游戏 demo 做到可试玩。重点是第一关完整流程、HUD 提示、失败/成功反馈。你自己拆任务，用 Codex workers 实现，review 后本地合并。
```

```text
/claude-commander 清理项目结构，把素材包、Godot 原型、浏览器预览、文档整理成清楚的目录。注意不要删除有价值资产，先 review 再合并。
```

```text
/claude-commander 给 v0.6 原型补一轮验收测试和试玩报告。Codex 可以负责检查数据、运行项目、整理缺口，Reviewer 检查结论是否可信。
```

不推荐：

```text
/claude-commander 做好这个项目
```

这种太宽泛。可以说“大目标”，但最好给出成功标准，例如“可试玩”“能跑通第一关”“本地验证通过”。

## 默认分工

默认情况下：

- 最多 2 个 Codex implementer workers 并发
- 最多 1 个 Reviewer 并发
- 最多 1 个 researcher / spec agent 并发
- 默认总并发 AI 单元不超过 3
- 默认单次 run 启动的预算内 AI 单元超过 8 个之前必须再次问你
- 同角色、同主题的 Agent 在上下文还能用时必须复用/继续，不允许为一堆小任务反复新开 Agent
- 每个 worker 一个 git worktree
- 每个任务最多 2 次实现尝试
- 每个任务最多 2 次 review/revision 循环
- 默认不 push、不 deploy、不 publish
- 默认只做本地 integration branch
- 默认 worktree 放在 `~/.claude/commander/worktrees/`，不污染项目仓库
- 默认保留 worktree 和日志，方便审计
- 默认生成 goal contract、reference brief、spec、task DAG 和 final report scaffold
- 默认用 exit artifact 和 `status/<task>.json` 记录 worker/task 生命周期状态
- 默认在 worker prompt 和 merge gate 中使用 file/path claims，避免并行越界修改

## 角色说明

### Claude Commander

负责：

- 理解目标
- 探查代码
- 拆任务
- 写 worker prompt
- 启动 Codex workers
- 观察日志和 diff
- 安排 reviewer
- 决定返工/放弃/本地合并
- 输出最终报告

### Codex Worker

负责：

- 在自己的 worktree 里实现一个小任务
- 遵守限定范围
- 跑必要验证
- 输出完成说明

限制：

- 不能改父仓库
- 不能改 `~/.claude`
- 不能 push
- 不能 deploy
- 不能 publish
- 不能打印密钥
- 不能删除无关文件

### Reviewer

负责：

- 只读审查 worker 的 diff
- 检查正确性、范围、测试、安全边界、可维护性
- 给出结论：
  - `PASS`
  - `PASS_WITH_NOTES`
  - `FAIL_REVISE`
  - `FAIL_ABORT`

### Revision Worker

负责：

- 只修 reviewer 指出的 blocker
- 不扩大范围
- 重新跑验证

### Merge Gate

负责：

- 确认 review 通过
- 确认 review 记录的 diff hash 仍然等于当前 worker diff，防止 stale review
- 确认验证通过，或者有明确的 NOT_APPLICABLE 原因
- 确认 worktree 是 Commander 管理的安全路径
- 确认没有越界改动
- 只本地合并，不 push

## 安全边界

本机的 `codex-unsafe` 是高权限 wrapper：

```bash
exec codex "$@" --dangerously-bypass-approvals-and-sandbox
```

所以这个 Skill 强制采用这些边界：

1. `codex-unsafe` 只能在验证过的 git worktree 中运行。
2. 每个 worker 只能改自己的 worktree。
3. 不允许自动 push。
4. 不允许自动 deploy。
5. 不允许自动 publish。
6. 不允许修改 `~/.claude`、shell profile、global git config、凭据文件。
7. 不允许打印 token、secret、环境变量。
8. 不允许删除 Commander 管理范围外的文件。
9. review 之前不允许合并。
10. 默认只合并到本地 integration branch。

如果你确实要 push、开 PR、deploy，需要单独明确授权。

## loop 模式怎么用

如果你希望它持续推进，而不是只启动一轮，可以这样：

```text
/loop /claude-commander <目标>
```

例如：

```text
/loop /claude-commander 把第一关 demo 做到能本地试玩。Codex 分工实现，review 不过就返工，直到验证通过或需要我决策。
```

loop 模式下，Commander 会：

- 记录 run state
- 定期检查 Codex workers 状态
- 在 status/monitor 中显示每个 worker 的任务摘要、prompt 路径、分支、worktree 和最近日志，让你知道当前具体在做什么
- 完成后安排 review
- review 不过就返工
- 通过后本地集成
- 遇到安全边界或需要你决策时停止

它不会无限循环。默认有尝试次数和运行时间边界。

## 辅助命令

这些命令通常由 Claude 自动调用，但你也可以自己看。

预检环境：

```bash
~/.claude/skills/claude-commander/scripts/commander.sh preflight
```

只生成计划，不启动 worker：

```bash
~/.claude/skills/claude-commander/scripts/commander.sh plan --goal "你的目标" --dry-run
```

创建一次 run：

```bash
~/.claude/skills/claude-commander/scripts/commander.sh start --goal "你的目标" --workers 2
```

查看 run 状态：

```bash
~/.claude/skills/claude-commander/scripts/commander.sh status --run <run-id>
```

监控 run：

```bash
~/.claude/skills/claude-commander/scripts/commander.sh monitor --run <run-id>
```

更新任务生命周期状态：

```bash
~/.claude/skills/claude-commander/scripts/commander.sh state --run <run-id> --task <task-id> --status ready --note "ready after spec review"
```

验证 skill 自身文件完整性：

```bash
~/.claude/skills/claude-commander/scripts/validate-skill.sh
```

## 文件和日志在哪里

Skill 本体：

```text
~/.claude/skills/claude-commander/
```

运行状态：

```text
~/.claude/commander/runs/<run-id>/
```

每次 run 会保存：

```text
run.json
goal-contract.md
references/reference-brief.md
specs/spec.md
tasks/task-dag.json
status/
prompts/
logs/
workers/
reviews/
diffs/
reports/
```

默认 worktree 位置：

```text
~/.claude/commander/worktrees/<repo-slug>/<run-id>/<task-id>/
```

这样不会污染项目仓库的 git status。如果确实想把 worktree 放到项目内，可以显式给 `launch-worker.sh` 传：

```text
--worktree-root <repo>/.claude/commander/worktrees/<run-id>
```

## tmux 说明

当前机器没有安装 `tmux`，所以 v1 使用：

```text
后台进程 + 日志文件
```

如果你以后想实时看到多个 Codex 窗口，可以安装 `tmux`，然后让 Skill 使用 tmux session 管理 worker。

安装前需要你明确授权。这个 Skill 不会自动安装系统依赖。

## 最推荐的使用句式

```text
/claude-commander 目标：<你想完成什么>。
成功标准：<怎样算完成>。
限制：<哪些不能改/不能做>。
执行方式：Codex workers 分工，每个 worker 独立 worktree，Reviewer 审查，不通过就返工，通过后只本地合并。
```

例子：

```text
/claude-commander 目标：把《破车快递队》Godot 第一关做成可试玩 demo。
成功标准：本地能启动，玩家能完成取件、装车、运输、送达，HUD 有当前阶段和包裹状态，失败/成功反馈清楚。
限制：不要删除素材包，不要 push，不要 deploy。
执行方式：Codex workers 分工，每个 worker 独立 worktree，Reviewer 审查，不通过就返工，通过后只本地合并。
```

## 记住

这个 Skill 的核心不是“让 Codex 多开几个窗口”，而是：

```text
Claude 负责管理责任，Codex 负责具体执行。
```

如果 Codex 做得不行，Commander 要发现、指出、让它改；不能把失败结果直接交给你。
