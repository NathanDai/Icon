---
name: review-cycle
description: 由 Claude 主动编排的独立代码审查流程：派 Codex / Grok 只读审查（review、adversarial-review、critique），按 id 追到终态取结果，Claude 逐条核实后分级输出；在已授权的开发/修复任务里继续完成"核实 → 范围内修复 → 测试 → 验收"。用于按全局 CLAUDE.md Writer/Reviewer 规则需要独立审查一个 diff 时，或用户要求 Codex/Grok 审查、挑战方案时。AGY 的第二意见走 agy skill；用户手动输入的 /codex:review、/grok-build:review 等原生命令按插件自身规则执行，不走本流程。
---

# review-cycle

原生 `/codex:*`、`/grok-build:*` 命令设了 `disable-model-invocation`，Claude 调不起；本 skill 通过白名单入口 `~/.claude/skills/review-cycle/scripts/rc.sh` 直调插件脚本。入口只开放审查与查询，`cancel`/`stop`/`task`/`run`/`--write`/`--resume` 都会被拒绝——终止任务和写入型委派不属于自动编排。插件路径每次从 `installed_plugins.json` 解析，插件升级不影响本 skill。

## 先定模式

从原始任务的授权判断，不从审查结果推断：

- **纯审查**（用户只要审查意见）：Reviewer 只读，Claude 核实后输出分级结果，不改任何文件。
- **已授权开发/修复**（用户已让 Claude 实现或修复）：审查是交付前的一步，确认的问题在原授权范围内修，测试通过后由 Claude 验收。

插件里 `codex-result-handling`、`grok-run-output` 的"列完审查结果必须 STOP 问用户"约束的是原生命令的结果呈现，本流程不加载它们。纯审查模式下行为本来就一致（不改文件）；开发模式下是否修由原任务授权决定，下面的边界仍然适用。

## 选 Reviewer

按全局 CLAUDE.md「Writer / Reviewer」选第一个可用的异构 Reviewer，并记下实际用了谁（含模型）。默认模型已写在 `rc.sh` 顶部（Codex `gpt-6.1-sol`，effort 来自 `~/.codex/config.toml`；Grok `grok-4.6`+`high`），一般不必再传。

- 设计取舍、并发、安全、数据正确性等复杂问题，在常规 review 之外加一次挑战审查：Reviewer 是 Codex 时用 `codex-adv`，是 Grok 时用 `grok-critique`。二者通常只选一个。
- Fast Path 小改动（几行、能一句话说清 diff）可以不派外部审查，或只派一个 review，不加挑战审查。

## 派发与追踪

在**目标仓库的 git 根目录**执行（两家的任务状态都按工作区隔离，换目录查不到）。派发前记下 `git status --porcelain` 的输出。

```bash
RC=~/.claude/skills/review-cycle/scripts/rc.sh
"$RC" codex-review --base main            # 或 --scope working-tree；codex-adv 可在参数后附 focus 文本
"$RC" grok-review --base main             # grok-critique 同理
"$RC" codex-status [<job-id> [--wait-min 25]] ; "$RC" codex-result <job-id>    # 不带 id 时列出最近任务
"$RC" grok-runs [<review-id> [--wait-min 25]] ; "$RC" grok-show <review-id>
```

- **Codex**：companion 的 review 总在前台跑完才退出，所以用 Bash `run_in_background: true` 启动；进程退出、输出里有审查结论才算完成。输出不含 job id；需要复查时用不带 id 的 `codex-status` 列出任务，按 `title: "Codex Review"` 和时间找到 `review-…` id（列表会混入 Grok 的 review，`latestFinished` 不一定是本任务），再用 `codex-status <id>` / `codex-result <id>`。
- **Grok**：`grok-review`/`grok-critique` 只负责入队，几秒内返回 `review-…` id；再用 `run_in_background: true` 跑 `grok-runs <id> --wait-min 25`，退出后看 `job.status`。`completed` 后用 `grok-show` 取结果；`failed`/`cancelled` 时按失败处理。
- "已启动"不是完成。等待是有界的：`waitTimedOut: true` 时最多再等一轮，仍未结束就报告用户（附 id 和最后状态），不自行 cancel/stop，也不对同一 diff 重复派同一 Reviewer。
- 结束后再比对一次 `git status --porcelain`。审查期间工作区有变化即视为违规：告诉用户，不自动回滚。

额度或可用性错误（429/402/usage limit）按 CLAUDE.md「额度回落与暂停」换到下一个 Reviewer，并在结果里写明换了谁、为什么。

## 核实与分级

Reviewer 的结论只是候选。每条都要对照实际代码、调用链和测试核实：能复现或有确凿代码证据才算确认，否则驳回并写一句理由。输出时每条带 `file:line`、证据和核实结论：

- **P0**：会导致错误结果、数据损坏、安全问题或不可用，必须修。
- **P1**：真实缺陷或需求偏差，影响有限，应修。
- **P2**：可读性、风格、可选改进，默认不修。

结果开头写明实际 Reviewer（工具 + 模型）、审查范围（base 或 working tree）和终态。

## 已授权任务的修复闭环

- 确认的 P0/P1 在原任务范围内修：小修 Claude 直接改；较大的按 Router 交给 writer（Codex `task --fresh`，Task Packet 自包含），Reviewer 本身不动手。P2 不顺手做。
- 修完跑原任务的测试/构建/静态检查，自己看结果。修复改动不小或涉及 P0 时，再派**一次** fresh review 只审修复 diff。整个任务最多两轮审查（生产写入类脚本可到三轮），之后仍有分歧就把剩余问题和证据交给用户裁决，不进入无限修复循环。
- 修复要越出原任务范围、改动接口或数据格式、或涉及高业务风险时，先征求授权。

## 始终需要用户单独授权

git commit / push / merge；生产部署与发布；数据库数据或结构变更；删除用户数据或其他破坏性文件操作；修改凭据或生产配置；终止已有的 Codex/Grok 任务。
