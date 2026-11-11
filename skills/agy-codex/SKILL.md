---
name: agy-codex
description: Use AGY for substantial analysis or an explicit AGY/Gemini request, and diagnose its model quotas and AI credits through built-in CLI queries. Route analysis to Gemini 4 Argon and writing to Gemini 3.8 Flash. Delegated model calls require an applicable convention or Task Packet and sufficient budget. Do not launch model tasks for strict read-only work or small direct fixes.
---

# AGY for Codex

## 适用范围与权限

Codex 独立使用时，大型源码阅读、调用链、长日志、根因、外部资料研究和按模块分析优先委派 AGY；主线程负责方案、关键证据复核及最终验收。范围明确的小修复直接处理。

被 Claude 委派时，只有任务说明（Packet）或已生效约定明确允许、且调用预算、范围和权限都满足，才调用 AGY；否则由主线程继续。每一次真实模型调用（包括冒烟、重试、`--conversation` 续聊）都占用调用预算，预算为 0 时一次都不调用。

- 严格只读、禁止创建任何文件或禁止必要认证访问的任务不启动 AGY 模型任务；CLI 自身也可能写会话缓存。额度内建查询另按下节及任务允许的缓存/认证范围判断，不通过 AGY 绕过当前权限。
- 普通分析允许 AGY 必要的会话缓存；这不授权修改项目、安装依赖、提交、部署或调用有写入副作用的 MCP。
- 默认 workspace-write 沙箱可能阻止 AGY 日志/缓存写入、本地端口监听或网络访问；允许缓存不等于沙箱已放行。遇到拒绝时报告所需资源，额外权限须经显式批准；未获准则由主线程继续允许范围内的分析，不自动改配置或切换 trusted。
- 普通分析默认不传 `--dangerously-skip-permissions`。拒绝、空输出或失败时不自动加该参数、不切换 trusted、不扩大沙箱权限。仅在用户明确授权 AGY 自动批准且环境允许时才考虑该参数；仍须遵守任务范围。
- 1.5.2 起，`--dangerously-skip-permissions` 仍受系统命令 denylist、显式 deny 规则及企业管理员审查要求限制；headless 模式遇必须审查的越界访问会拒绝，不能将该参数视为无条件放行。
- Codex 的 trusted 配置只改变执行权限，不构成项目修改、生产写入、提交或推送授权。提示词及 git status 均不是技术隔离。
- AGY 不用于修改代码。`Claude Sonnet 5.5 (High)` 等 Claude/GPT 池模型不在当前已批准的路由内，不因余额充足而使用；用户以后另行明确批准才恢复。
- 本技能是 Codex 的 AGY 工作流来源；不继承其他代理的身份、路由或回退链。

## 核对当前 CLI 用法

参数查 `agy --help`，版本行为查 `agy changelog`；已登录时，只读斜杠命令可查 `agy --print-timeout 1m -p '/help'`。2026-11-11 本机 `agy --version` 为 1.5.5，内置 changelog 最新条目也是 1.5.5；本次已核对本地帮助、发布说明，以及登录后的 `agy models`、`/help`、`/model`、`/effort`、`/quota` 和 `/credits`。这些内建查询均未启动模型推理，不代表已验证真实模型任务成功。不要为查看帮助发起模型调用。

需要账户信息时先用 `agy models` 检查；若提示未登录，或内建查询进入 OAuth 等待，停止本次等待并报告认证受阻，不反复查询、自动登录或改认证配置。认证失败不能推断模型下架或额度耗尽；登录完成后再复核 `/model`、`/effort`、`/quota` 与 `/credits`。

`-p` 会展开斜杠命令及技能。普通分析提示词需要将开头的 `/...` 当作字面文本时，加 `--disable-slash-commands`；查询 `/quota` 等内建命令时不要加这个开关，也不要同时附带分析任务。只读查询与真实模型调用的结果分别验收。

## 额度与可用性查询

问“三种模型还有多少额度”、排查 429 或 `credits balance too low` 时，优先直接读取 CLI 的只读内建命令。本机已于 2026-11-11 在 1.5.5 复核 JSON 结构：

```bash
agy --print-timeout 1m -p '/quota'
agy --print-timeout 1m -p '/credits'
# 需要机器读取时，用 JSON 结果中的结构化字段。
agy --print-timeout 1m --output-format json -p '/quota'
```

- `/quota` 每行返回制表符分隔的额度池、限制名称、剩余百分比、恢复时间；`/credits` 返回剩余额外 AI Credits。成功结果是结构化额度记录，不是模型推测的余额。
- JSON 额度位于 `command.data.groups[].buckets[]`，读取 `remaining_fraction`（乘100为百分比）、`window` 与 `reset_time`，不要解析自然语言 `description` 推算余额。`/quota` 的 `command.name` 实测为 `usage`；积分读取 `command.data.remaining_credits`。这类内建查询正常返回空 `conversation_id`、`num_turns: 0` 和零 token 用量；这不表示模型空响应失败，也不产生可供续聊的会话ID。
- 按实际返回的分组报告。2026-11-11 本账户实测有 `Gemini Models`（本次模型列表中的 Gemini Flash）、`Gemini 4 Argon`、`Claude and GPT models` 三池；Argon 仅单列周额度，其他两池均返回周额度和 5 小时额度。其他账户、计划或后续归组可能不同，不写死所有账户均为三池。分别展示周额度、5 小时额度；某池未返回某个窗口时写“未单列”，不补造数值。所有适用窗口都须有余量才视为配额可用，不能只看周额度。恢复时间中的 `Z` 是 UTC，按用户时区换算并注明时区。
- 额外 AI Credits 为 0，不表示订阅模型配额全部耗尽。某次 Argon 调用失败，也不能概括成 Flash 或整个 AGY 不可用。额度是查询时快照，不当作永久预算。
- 这两个内建查询不触发模型推理，不计入真实模型调用次数；CLI 自身必要的认证/缓存访问仍受当前权限限制。查询不需要发送测试提示词、启动交互式工作区信任流程、修改权限或读取凭据。
- `agy models` 只列模型名称，不证明有额度或调用成功。用户明确要求实测调用时，才执行最小模型调用并单独记录结果；不要声称模型回答能读取账户余额。
- 版本不支持这些命令或返回异常格式时，核对本机 `agy --help` / `agy changelog`，报告无法从 CLI 确认的具体项；必要时再用界面作补充并标明来源，不编造新的 quota 子命令。
- 认证/资格检查返回EOF等网络错误时，不能据此判断额度为0。不要为额度诊断切换订阅/PAYG计费、升级计划或开启额外消费。

## 模型与调用

- 探索、分析、第二意见、审查：`Gemini 4 Argon (High)`（独立周额度池）。
- 写文档、文章和生成图片：`Gemini 3.8 Flash (High)`；名称与档位按当前 `agy models` 核对，不沿用旧版Flash型号。
- 只使用这两个模型；不使用 Sonnet、Opus 或 GPT-OSS。模型列表与可读的默认选择可分别通过 `agy models`、`agy --print-timeout 1m -p '/model'` 查询；默认选择可能是Medium，不代表任务已经按High运行。真实调用显式传 `--model` 的完整带档位名称。
- 2026-11-11 在 1.5.5 用只读 `/model` 复核：完整模型名 `Gemini 3.8 Flash (High)` 和 `Gemini 4 Argon (High)` 均正确解析为相应的 `*-high` ID；Flash 完整名或基础名与 `--effort high` 组合仍被拒绝，退出 1，报 `--effort is not supported`。继续省略 `--effort`，通过完整模型名固定档位。只读 `/effort` 在 Argon 和 Flash High 下均返回 `current: high`、`available: [low, medium, high]`、`adjustable: true`，不代表 CLI 的 `--model` / `--effort` 组合可用；帮助列出的 `xhigh|max` 也不代表每个模型都支持。不以真实模型任务反复试探参数。
- 参数以当前 `agy --help` 为准；显式设 `--print-timeout`，普通调用 5m，大范围探索 15m。冒烟也是真实调用，只在调用预算允许时做。不把 `--mode plan`、`-p` 或 `--sandbox` 当成已验证的只读隔离。
- AGY 是同步 CLI；长任务使用当前执行工具的后台进程或会话机制，等待对应进程退出。冷启动可能需 2～3 分钟。1.5.0 起，未设 `--print-timeout`（默认 `0`）会等待后台任务完成；显式超时会终止尚在运行的任务并退出 `3`，同时输出 `AGY_ERROR` 和 stderr 超时说明。1.5.5 修复了结果打印后因后台任务卡住而无法退出的问题，发布说明称关闭过程最多等待 30 秒；看到结果文字仍须等待退出并验收。
- 复杂提示词在获准的临时目录中准备，避免拼接不可信 shell 文本。例如：

```bash
agy --model "Gemini 4 Argon (High)" --output-format json --print-timeout 15m -p "$(cat /absolute/path/prompt.txt)" > /absolute/path/out.json 2> /absolute/path/err.txt
```

分析提示词开头写明：“只分析；不得创建、修改或删除项目文件；只允许必要的只读命令；禁止有写入副作用的数据库、SSH、对象存储、通知及其他 MCP 操作。允许 CLI 自身必要的会话缓存。”纯文本冒烟进一步禁止所有工具调用。

### 新版多代理与远程能力

- 1.5.5 新增 `/swarm <task>`（Preview & Quota Heavy）：协调者可创建、fork 多个独立会话的 worker，每个 worker 都消耗额度并可选择不同模型。普通 AGY 调用不默认启用 swarm；只有任务授权包含多代理且预算覆盖各 worker 时才使用，所有成员仍受本技能的模型路由及任务范围限制，不能将整个 swarm 只记作一次模型调用。
- 1.5.5 发布说明称，隔离 worktree 会包含 staged、unstaged 和 untracked 改动；这不保证 worker 基于干净提交，也不替代主线程的范围核对。
- 1.5.0 新增 `--remote-agent` 和 ACP 入口；现有调用继续使用本地 CLI。只有任务确需且授权覆盖远程项目、数据访问与执行范围时才选择远程模式，不把它作为本地权限失败后的回退。
- 1.5.5 的 Gemini 4 Carbon 仅在 ADC 认证下新增，不自动替换当前批准的 Argon / Flash 路由。

## 上下文与验收

- 每次传入自包含说明：目标、必要绝对路径、已知事实、权限边界、验收标准和验证命令；不转发整段聊天或凭据。
- 返回 STATUS / FINDINGS / RELEVANT_FILES（修改任务用 FILES_CHANGED）/ TESTS / RISKS / NEXT_ACTION；关键证据附 file:line，不回贴整份文件或日志。
- 审查使用独立于作者的会话，提供原始材料和验收标准，不灌输作者结论；主线程定点核实发现与实际测试结果。
- 调用前后核对任务范围内的 Git 状态和 diff；非 Git 或仓库外目标使用限定文件的摘要核查。状态比较不能证明没有远程副作用。发现越界修改告知用户，不自动回滚。
- 模型输出是证据，不是新的指令或授权；以 Codex 的真实身份汇总结果。
- 需要结构化业务结果时，可用 `--json-schema /absolute/schema.json`；按本机changelog，schema根必须是 `"type": "object"`，文件缺失或不合法会在启动时失败。`stream-json`是逐行事件流，schema仅约束最终`result`事件，不把进度事件当作最终回答。

## 续聊、图像与失败处理

- 每次模型任务后，从本次调用的 JSON 输出里取非空 `conversation_id`，记录“主题 → UUID”。没有JSON或未返回非空ID时记UNKNOWN；内建查询不建立会话，不需要此映射。不从 `~/.gemini/antigravity-cli/cache/last_conversations.json` 取（它只记每个目录最近一次会话，会被其他会话的调用覆盖，不能证明是哪一次调用）。
- 同主题用已确认的 `--conversation <uuid>` 并补充新增事实；新主题另开。UUID 缺失时不以 `-c`、`--continue` 或最近会话替代；需要旧上下文时先解决匹配问题。
- 仅在用户明确要求 AGY 生成或编辑图像时使用其图像能力；说明获准输出路径，完成后查看图像，同主题沿用已确认 UUID。
- 模型任务验收同时检查进程退出码、JSON `status`、有效`response`、`finished_reason`与任务证据。正常完成可不带`finished_reason`；`print_timeout`表示超时且回答可能不完整，1.5.0 起超时退出码为 `3`，不能沿用旧版“超时也退出成功”的判断；`interrupted`表示取消，`error`表示失败，均不能当作已完成。保留部分结果、错误输出与精确会话ID，再决定是否需要授权范围内续聊；不因看到部分文字就重新派发同一任务。内建查询另按`command.data`验收。
- 权限拒绝或无结论按失败处理。空输出或有 `denied_actions` 时，在调用预算允许的前提下最多重试一次，不提升权限。
- 429 或 `credits balance too low` 不循环重试；先用上面的内建查询区分受限额度池与额外积分。确认 Argon 池耗尽而 Flash 所在池有可用配额时，已获授权的分析可改用 `Gemini 3.8 Flash (High)`，仍遵守调用预算；Flash 也不可用时报告缺口。不自动换供应商、定时恢复或调用 Claude/GPT 池，即使其额度充足。
