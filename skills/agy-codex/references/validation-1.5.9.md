# AGY 1.5.9 本机实测

核验日期：2026-11-15。以下保留当时全模型／功能测试的事实，用于排查版本差异和调用验收，不作为永久可用性、质量排名或当前外派建议。用户随后明确将 AGY 的常规分工收窄为简单数据提取、按明确规则校验和写作，默认 Flash High；代码、复杂分析、研究和代码审查由 Codex 完成。当前分工以 `SKILL.md` 为准，受派任务仍遵守其 Packet。

本机 `agy --version`、内置 changelog 首条及官方 latest 均为 1.5.9，未执行升级。测试在临时工作目录使用合成文本、版本号和算术夹具；模型矩阵最多并发两个 CLI，无项目源码修改。

## 模型可用性

| 当前模型名称 | 实测档位 | 结果 |
| --- | --- | --- |
| Gemini 4 Argon | Low、Medium、High | 最小调用成功；High 对象 schema 首轮值正确 |
| Gemini 4 Hydrogen | Low、Medium、High、XHigh | 最小调用成功 |
| Orchestrator (Argon) | 列表中未另列档位 | 无工具最小回答成功，未评估规划／执行混合路由 |
| Gemini 3.8 Flash | Low、Medium、High | 最小调用成功；High 另验证工具及多轮 |
| Claude Opus 5.5 | Low、Medium、High | 经 AGY 最小调用成功 |
| Claude Sonnet 5.5 | Low、Medium、High | 经 AGY 最小调用成功 |
| GPT-OSS 120B | Medium | 经 AGY 最小调用成功 |

共 18 个可见模型／档位。这只证明当次请求、模型选择及基本输出可用，不证明推理、实现或审查质量。矩阵流中的 `init.model` 与请求匹配，最小回答测试未调用工具；High Argon／Flash 复用前序 schema／文件读取测试。

## 功能结果

| 功能 | 实际结果 | 验收限制 |
| --- | --- | --- |
| `/help`、`/quota`、`/credits`、`/model`、`/effort` | 正常结构化返回，`num_turns: 0` | 内建查询不是模型调用 |
| 完整模型名与 `--effort` 组合 | Argon、Flash、Hydrogen、Opus、GPT-OSS、Orchestrator 的所测组合均在推理前退出 1 | 使用完整带档位名称，省略该参数；Sonnet 组合未单独测 |
| 对象 `--json-schema` | 首轮返回 `{"major":2,"minor":14,"patch":3}`，包含 `structured_output` | schema 格式与业务值分别验收 |
| primitive schema | `string` 非合法 JSON；`{"type":"string"}` 被拒为非 object 根，均退出 1 | 与当时官方文档存在差异，本机仍使用 object 根 |
| 文件读取 | 真实 `read_file` 返回夹具内容 | 不能由 `init.tools` 列表推断每种工具均可调用 |
| 会话级 `--settings` | 限定 `write_file` 路径和 `command(printf)`，读写文件及命令执行均通过 | 未修改持久设置；不能视为完整隔离验证 |
| stream-json 输出 | 含 init、工具步骤及最终 result | 工具／子代理步骤与最终 response 均需检查 |
| stream-json 输入两轮 | 第二轮准确返回首轮随机校验码，ID 相同、轮数 1→2 | usage、耗时和轮数在同进程会话中累计 |
| 跨进程精确 ID 续聊 | Flash 在异目录和原目录均返回 `NO_CONTEXT`；Argon 对象 schema 值也未保留 | 外层 SUCCESS 和 ID 一致不能证明历史已恢复；原因未定位 |
| `run_workflow` | 两个 `model="inherit"`／`workspace="inherit"` 子代理返回 7、11，父级汇总 18 | 已核对实际 workflow 脚本、工具终态、日志和子会话 ID |
| 自动批准下的文件 deny | 模型返回 BLOCKED，未读出夹具值 | 本次没有真实工具拒绝步骤，仅能证明该用例下模型遵守限制，未证明底层强制隔离 |
| `--print-timeout 1ms` | 退出 3、`status: ERROR`、`finished_reason: print_timeout`，无有效回答 | stderr 有 DEADLINE_EXCEEDED，不作完成结果 |
| ACP 初始化握手 | `agy acp` 返回协议 1、服务版本 1.5.9，随后退出 0 | 未创建会话、登录或调用模型；不证明编辑器会话、MCP 注入或多媒体能力通过 |
| 网页／浏览器 | 直接网页限制用例未执行工具；放开合法回落后，经真实 `curl` 取得 example.com 页面 | 只验收 shell 网页读取，原生浏览器能力未跑通 |
| 图片生成 | 经一个真实 `image-generator` 子代理，三次 `generate_image` 均报 `no image generated in response`，无图片文件 | 子日志已核对；父级 SUCCESS 不等于图片产出，不继续重试 |

没有测试付费远程资源、Remote Control 对外连接、账户／插件安装变更、生产 MCP、swarm／teamwork、多媒体输入和交互界面。没有将这些项目算作通过；图像子代理内部的三次尝试单独记录，不隐瞒在父级一次调用中。

## 续聊用法调整

- 跨进程传精确 UUID 仍用于身份对账，但提示词必须补齐必要事实、原始材料和期望状态；未验证前不依赖“上次说过”。
- 需要真正连续上下文时，可用本次通过的同进程输入。每个提示单独计入预算，收到该轮 `result` 再发下一条，关 stdin 后等待退出。
- 当前证据不能区分 CLI 恢复、存储或后端上下文的问题；不据此修改认证、清理会话缓存或升级／降级。

最小输入格式：

```json
{"event":"user","message":{"content":"第一轮提示词"}}
{"event":"user","message":{"content":"第二轮提示词"}}
```

配合 `agy --model "Gemini 3.8 Flash (High)" --input-format stream-json --output-format stream-json --print-timeout 5m`；不再传 `-p`，不把 `/model` 等 CLI 内建命令混入 stdin。

## 证据入口

本机原始请求、输出、stderr 与摘要位于 `/Users/nathan/.codex/tmp/agy-check-2026-11-15-h889fyfc/`，不是跨机器固定位置；目录中的 `HANDOVER.md` 记录进程／会话和阶段状态。

- 模型：`model-matrix.json`、`matrix-summary.json`、`matrix/*/request.json` 与 `stdout.jsonl`；High 测试见 `argon-first.*`、`flash-read.*`。
- 内建查询与参数：`builtin-summary.json`、`effort-summary.json` 及对应 stdout／stderr。
- 多轮与续聊：`features/stream-memory/`、`features/exact-resume/`、`samecwd-resume.*`、`argon-resume.*`。Flash 记忆会话 `5496cdca-77d2-4023-b402-f86cb802eb98`；Argon schema 会话 `22129a11-7c42-4bd5-873b-31b237410070`。
- workflow：`advanced/workflow/`，父会话 `282ea535-1dec-4218-919b-b9919abecb04`；子会话 `c7668875-3e7c-469e-a289-e0815afa475c`、`d5abc67c-43c9-4858-99ab-0e629e551f9e`。
- 图片：`capabilities/image-agent/`、`image-child-evidence.json`；子会话 `f9c708ca-2b12-42de-9bb9-09094737a9bc`。摘要只保留模型、工具名和错误，不复制模型推理过程。
- ACP：`acp-summary.json`、`acp-initialize.request.json` 及 stdout／stderr。

## 官方对照

- [1.5.9 发布记录](https://github.com/google-antigravity/antigravity-cli/releases/tag/1.5.9)：workflow、恢复入口、MCP 安全及其他变化。
- [Headless 文档](https://antigravity.google/docs/cli/headless)：JSON／stream-json、输入格式、续聊与权限；primitive schema 支持须以上述本机结果为准。
- [Dynamic Workflows](https://antigravity.google/docs/dynamic-workflows/)：Python 工作流、独立子会话、模型选择和权限。
