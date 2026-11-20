# AGY 1.5.13 本机实测

核验日期为 2026-11-20。`agy --version` 返回 `1.5.13`，内置 `agy changelog` 只到 1.5.9，缺 1.5.10–1.5.13 条目。以下 headless 实测均带 `--dangerously-skip-permissions`。

## 模型可用性

`agy models` 较 1.5.9 新增 `Gemini 4 Neon` 的 High、XHigh、Medium、Low 档及 `Orchestrator (Neon)`（`gemini-pro-orchestrator-neon`）。列表中的 16 个非 Claude／GPT 模型／档位均通过最小调用。Neon (High) 与 Argon (High) 均拒绝 `--effort high`，继续通过完整模型名称指定档位。Neon 额度池未确认。最小调用只验证当次基本可用性。

## 功能结果

| 功能 | 方法与结果 | 验收限制 |
| --- | --- | --- |
| 跨进程精确 ID 续聊 | Flash (High) 和 Argon (High) 各在目录 A 首轮记住随机校验码，次轮用 `--conversation <首轮 UUID>` 在 A 或空目录 B 查询。四例均准确返回校验码，`conversation_id` 不变，`num_turns` 从 1 到 2，退出 0、`SUCCESS`，无 `finished_reason` 或 `denied_actions`。另有 Neon (High) 同目录续聊成功。 | 同主题可用精确 UUID 加增量 bridge。写明关键事实，并核对本轮业务结果。此处验证的是文本记忆，结构化续聊未重测。 |
| 图片生成 | 在空目录要求 Flash (High) 用图片模型生成插画，按绝对路径保存后只回复路径。退出 0、`SUCCESS`，无 `finished_reason`。生成的 PNG 为 1376×768，查看确认符合要求且无文字。JSON `response` 只返回中间进度（“I have requested the image generator subagent ... Waiting”）。 | 验收以目标文件存在、格式正确及实际查看内容为准。`response` 可能只有进度文本。 |
| `/usage` | `agy --dangerously-skip-permissions --output-format json -p "/usage"` 返回 `SUCCESS`、空 `conversation_id`、`num_turns: 0`、各项 token 为 0，`command.name` 为 `"usage"`，与 1.5.9 的 `/quota` 一致。 | 内建查询不触发模型推理，不计入模型调用预算。 |

## 未重测项目

`--json-schema`（含结构化续聊）、同进程 stream-json、`run_workflow`、ACP、`--settings` 和额度耗尽形状均未在 1.5.13 重测。继续参考[沿用的 1.5.9 结论](#agy-159-carried-forward)及既有额度耗尽记录（1.4.12 实测）。

<a name="agy-159-carried-forward"></a>

## 沿用的 1.5.9 结论（2026-11-15，未在 1.5.13 重测）

- `--json-schema` 要求根为 `"type":"object"`。`string` 和 `{"type":"string"}` 均在模型调用前退出 1，与当时官方 headless 文档列出的 primitive 支持有差异。对象 schema 首轮通过。结构化续聊返回对象但业务值错误，1.5.13 未重测结构化续聊。
- 同进程 stream-json 多轮用 `--input-format stream-json --output-format stream-json`，不传 `-p`。stdin 每行一个 `{"event":"user","message":{"content":"..."}}`，收到本轮 `result` 再发下一轮，结束时关闭 stdin 并等待退出。两轮记忆测试通过，同一会话的 `num_turns`、`usage` 和 `duration_seconds` 均累计。
- `run_workflow` 的两个 `model="inherit"`、`workspace="inherit"` 子代理分别返回 7 和 11，父级汇总 18。验收核对实际 workflow 脚本、工具终态、日志、子会话 ID 及汇总值。
- `agy acp` 的 JSON-RPC `initialize` 握手通过，返回协议 1、服务版本 1.5.9，随后退出 0。未创建会话或调用模型。
- 会话级 `--settings` 用 `permissions.allow` 限定 `write_file` 路径及 `command(printf)`，文件读写和命令执行通过。当前调用仍须带 `--dangerously-skip-permissions`，不得用 `--settings` 替代。自动批准下的文件 deny 用例只证明该次模型遵守限制，未观察到工具拒绝，底层隔离未获验证。
- 网页读取仅经 shell `curl` 跑通，原生浏览器未跑通。
- 1.5.9 所测完整模型名加 `--effort` 均在推理前退出 1，Sonnet 组合未单独测。Claude Opus／Sonnet 5.5、GPT-OSS 经 AGY 最小调用成功，仅验证当次基本可用性，沿用现行不使用规则。
- `/help`、`/quota`、`/credits`、`/model`、`/effort` 正常结构化返回，`num_turns: 0`。`--print-timeout 1ms` 退出 3，返回 `status: ERROR`、`finished_reason: print_timeout`，无有效回答。
- 未测试付费远程资源、Remote Control 对外连接、账户／插件安装变更、生产 MCP、swarm／teamwork、多媒体输入和交互界面。
- 1.5.9 证据入口为本机目录 `/Users/nathan/.codex/tmp/agy-check-2026-11-15-h889fyfc/`，其中 `HANDOVER.md` 记录阶段状态。

1.5.9 时跨进程文本续聊与图片生成曾失败，1.5.13 已通过。

## 证据入口

Claude 会话临时目录（已不保留）。
