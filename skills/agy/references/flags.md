# `agy` (Antigravity CLI) reference

Verified against agy 1.5.16 (2026-11-24).

Checks covered `agy models`, all 16 non-Claude/GPT smoke calls, JSON success with no `finished_reason`, resume by id, image generation, Auto-mode shell with the required permission flag, `--effort high` rejection, the bad-model error, `--print-timeout 5s` expiry and `/usage` with zero model usage. All three documented commands passed `evals/lint_agy_commands.py`. The mode and stability details below draw on release notes.

## Top-level flags

`agy --help` (Go-flag format — note the single-dash long flags work too):

| Flag | Meaning |
|------|---------|
| `-p`, `--print`, `--prompt` | Run a single prompt **non-interactively** and print the response. The delegation entry point. |
| `-i`, `--prompt-interactive` | Run an initial prompt, then continue interactively (not for delegation). |
| `--model <display string>` | Model for this session. Verbatim string from `agy models` (see below). |
| `-c`, `--continue` | Continue the **most recent** conversation. |
| `--conversation <id>` | Resume a **specific** conversation by its UUID. Cwd-independent — the reliable resume. |
| `--add-dir <dir>` | Add a directory to the workspace (repeatable). |
| `--dangerously-skip-permissions` | Auto-approve tool-permission requests; required on every call in this configuration by user decision (2026-11-16). It is **not isolation**; see [Safety / permissions](#safety--permissions). |
| `--effort <level>` | `--help` lists `low\|medium\|high\|xhigh\|max`, but Neon (High) rejects `--effort high`. Historical Argon (High) result: `--model "Gemini 4 Argon (High)" --effort high` → `invalid model selection (--model "Gemini 4 Argon (High)" --effort "high"): --effort is not supported for model "Gemini 4 Argon (High)"`, `"finished_reason":"error"`, exit 1. A base model name without `--effort` picks the default tier. Keep using the tier in the model name. |
| `--mode <accept-edits\|auto\|plan>` | Without a saved Agent Mode, headless `-p` defaults to Auto where available. See [Safety / permissions](#safety--permissions) for mode details. **`plan` is not read-only.** With `--dangerously-skip-permissions`, it can answer a write request by writing `implementation_plan.md` under `~/.gemini/antigravity-cli/brain/<conversation_id>/` or by writing the requested workspace file itself. |
| `--output-format <text\|json\|stream-json>` | Print-mode output format. Use **`json`** — see [JSON output](#json-output). |
| `--input-format`, `--json-schema` | stream-json input; JSON schema for structured final output. Not used by the skill. |
| `--project`, `--new-project`, `--agent`, `--disable-slash-commands`, `--remote-control` | Project / agent selection and other session options. Not used by the skill. |
| `--sandbox` | Run with terminal restrictions (network / out-of-workspace). **Not** a read-only mode — local writes still happen. |
| `--print-timeout <dur>` | Time limit for `-p`. Default **`0s` = no limit**, so it waits indefinitely for background tasks to finish. Always pass it (`20m` normal, `60m` broad exploration, reviews, writing). On expiry the run exits 3 with `"status":"ERROR"`, `"error":"print timeout after 5s with the turn still in progress; the response is partial"`, `"finished_reason":"print_timeout"`, empty `response`, and `AGY_ERROR` (`"status":"DEADLINE_EXCEEDED"`, `"reason":"print_timeout"`, `"retryable":false`) on stderr. |
| `--log-file <path>` | Override the CLI log path (logs default to `~/.gemini/antigravity-cli/log/`). |
| `--settings <json\|path>` | Settings for this session only, never saved: a JSON object of `settings.json` keys, inline or as a file path. Not used by the skill; must not be used in place of `--dangerously-skip-permissions` (user decision, 2026-11-16). |

## JSON output

`--output-format json` prints **one JSON object on stdout**; diagnostics go to stderr. Examples:

```text
success:  {"conversation_id":"<uuid>","status":"SUCCESS","response":"正常\n","duration_seconds":6.6,"num_turns":1,"usage":{...}}           exit 0
timeout:  {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"print timeout after 5s with the turn still in progress; the response is partial","duration_seconds":0,"num_turns":1,"usage":{...},"finished_reason":"print_timeout"}   exit 3
          stderr: [agy] print timeout after 5s with turn in progress; returning partial output
                  error: print timeout after 5s with the turn still in progress; the response is partial
                  AGY_ERROR: {"short_error":"print timeout after 5s with the turn still in progress; the response is partial","status":"DEADLINE_EXCEEDED","retryable":false,"reason":"print_timeout"}
denied:   {"conversation_id":"<uuid>","status":"SUCCESS","response":"","denied_actions":[{"action":"write_file",...}],...}               exit 0
          stderr: jetski: no output produced — a tool required the "write_file" permission ...
quota:    {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"Your AI credits balance is too low to continue.","finished_reason":"error",...}   exit 3
          stderr: error: Your AI credits balance is too low to continue.
                  AGY_ERROR: {"short_error":"RESOURCE_EXHAUSTED (code 429) ...","status":"RESOURCE_EXHAUSTED","error_code":429,"retryable":true,...}
bad model/effort (historical Argon test): {"conversation_id":"","status":"ERROR","response":"","error":"invalid model selection (--model \"Gemini 4 Argon (High)\" --effort \"high\"): --effort is not supported for model \"Gemini 4 Argon (High)\"","duration_seconds":0,"num_turns":0,"usage":{...},"finished_reason":"error"}   exit 1
          stderr: error: invalid model selection ... (+ available list for a bad model)
```

- The `denied` example illustrates a tool permission denial, which can occur outside Auto mode. Every call in this configuration must include `--dangerously-skip-permissions` (user decision, 2026-11-16).
- `conversation_id` is the id to store for resume (replaces reading the cache file).
- A resumed call (`--conversation <uuid>`) returned the same `conversation_id`, advanced `num_turns` from 1 to 2 and recalled the previous turn.
- `finished_reason` appears only when a turn ended early: `print_timeout`, `interrupted` or `error`. It is omitted on a normal finish.
- Success requires exit 0, `status == "SUCCESS"`, and no `denied_actions` or `finished_reason`. For text, also require a non-empty `response`. For images, verify the saved file as described under Gotchas. Since both `--print-timeout` expiry and quota exhaustion return exit 3 with `status == "ERROR"`, distinguish them by `finished_reason` (`print_timeout` vs `error`), `error` text, and `AGY_ERROR.status` (`DEADLINE_EXCEEDED` vs `RESOURCE_EXHAUSTED` / 429).

## Subcommands

- `agy models` — list available models, one `model id<TAB>display name` per row.
- `agy --dangerously-skip-permissions -p "/usage"` — print remaining quota per pool with reset times (UTC when piped). It shows four rows with weekly and five-hour limits for `Gemini Models` and `Claude and GPT models`. The user confirmed on 2026-11-24 that Argon, Flash, Hydrogen and Carbon shared the `Gemini Models` pool. Takes a few seconds. `/usage` is a built-in query with no model inference (JSON output showed `num_turns: 0` and zero tokens in every usage field). It does not count against the model-call budget. The permission flag is still required.
- `mcp` — manage MCP servers (add, remove, list, enable, disable).
- `agents` (alias `agent`) — list available agents.
- `mic-serve` — serve this machine's microphone to a CLI on another host (not used).
- `remote-control` — manage the remote-control daemon.
- `plugin <cmd>` (alias `plugins`): `list`, `import [gemini|claude]`, `install <target>` (e.g. `name@marketplace`), `uninstall <name>`, `enable <name>`, `disable <name>`, `validate [path]`, `link <mp> <target>`, `help`. (Importing the `nanobanana` extension is optional — agy generates images natively; see Images below.)
- `install` — configure PATH / shell aliases (`--dir`, `--skip-aliases`, `--skip-path`).
- `agy changelog` — release notes.
- `update` — update the CLI.
- `help [subcommand]` — help (subcommands also take `-h`/`--help`).

## Models

`agy models` (Google-account login). Each row is `model id<TAB>display name`; summarized display names below:

```
Gemini 4 Neon (High) | (XHigh) | (Medium) | (Low)  ← High id gemini-4-neon-high, the only tier in use
Gemini 4 Carbon (Medium) | (High) | (Low)
Gemini 4 Argon (High) | (Medium) | (Low)     ← High retired
Gemini 4 Hydrogen (Low) | (Medium) | (High) | (XHigh)
Orchestrator (Neon)                       ← id gemini-pro-orchestrator-neon
Orchestrator (Carbon)                     ← id gemini-pro-orchestrator
Orchestrator (Argon)                      ← id gemini-pro-orchestrator-argon
Gemini 3.8 Flash (High) | (Medium) | (Low)   ← High retired
Claude Opus 5.5 (High) | (Medium) | (Low)
Claude Sonnet 5.5 (High) | (Medium) | (Low)
GPT-OSS 120B (Medium)
```

- **Hydrogen:** visible on this Google-account login. `Gemini 4 Hydrogen (High)` passed a smoke test (exit 0, `SUCCESS`, response `正常`, ~3.7 s). In a small blind review of four real pre-fix Python files with one known defect each, Hydrogen (High) found one defect and partially identified one in ~182 s versus Argon (High)’s three in ~454 s. Both missed a TLS certificate-validation defect and used similar tokens (~78k total). Hydrogen shared the `Gemini Models` pool with the then-current writing model Flash and remains **excluded from routing**, defaults and fallbacks because it found fewer defects than Argon in this sample and would consume that writing quota; further evaluation is the user’s decision. The release notes describe API-key/ADC access. The list above reflects this Google-account login.
- **Neon:** the user described Neon as “between Carbon and Hydrogen” (2026-11-25). `agy models` lists four Neon tiers and Orchestrator (Neon). In the earlier smoke tests, all 16 non-Claude/GPT entries returned `正常` with exit 0, `SUCCESS`, no `denied_actions` and no `finished_reason`. Each smoke call took ~2–10 s by agy’s timer and used ~13k tokens, mostly agy’s system prompt.
  - **Quota:** `/usage` has no separate Neon row. At 1% display precision, the reported quota percentages were unchanged before and after one Neon (High) call. On 2026-11-25, another Neon (High) smoke test passed (exit 0, `SUCCESS`, response `正常`, ~7.2 s by agy’s timer). Before and after, `Gemini Models` was 77% weekly and 100% over five hours, and both Claude/GPT windows were 100%. The Gemini five-hour reset time shifted by 15 s. Neon’s pool remains unconfirmed.
  - **Blind review:** five real pre-fix files from one repository (two Python, two JS, one Shell), each with one known defect. A hit earned 1 point and a partial hit 0.5. Hydrogen (XHigh) scored 3.5/5 (~295 s, ~86k tokens), Neon (High) 3/5 (~375 s, ~69k), Argon (High) 2.5/5 (~358 s, ~59k) and Neon (XHigh) 2.5/5 (~629 s, ~99k). All four found the same two defects and missed the same one. Treat gaps of 0.5–1 point as noise in this small, single-repository sample. Compared with Neon (High), Neon (XHigh) took ~1.7× as long and used ~1.4× as many tokens for a lower score.
  - **Writing:** Neon’s prose quality is unevaluated. In a historical 400-character explanation check, neither Neon (High) nor Flash (High) fabricated details. Neon’s paragraphs were slightly better structured, but the tight prompt left too little room to distinguish the models.
  - **Images:** Neon’s image-generation capability is unevaluated. See the historical Flash test under Images below.
- **Carbon:** `Gemini 4 Carbon (High)` passed a smoke test (exit 0, `SUCCESS`, response `正常`, no `denied_actions` or `finished_reason`, ~5.2 s). At 1% display precision, the `Gemini Models` pool shared with the then-current writing model Flash dropped from 83% to 82% weekly and 30% to 29% over five hours, while the Claude/GPT pool was unchanged. Carbon drew from that writing quota. Carbon and Orchestrator (Carbon) are **excluded from routing**, defaults and fallbacks. The evidence is limited to the Carbon (High) smoke test. Further evaluation is the user’s decision.
- **Default choice:** explicitly pass `--model "Gemini 4 Neon (High)"` for every AGY role and omit `--effort`. For quota errors follow the role-based fallback in global CLAUDE.md. AGY is not used for code changes.
- **Excluded models:** the user retired Argon (High) and Flash (High) in favor of Neon on 2026-11-25. Hydrogen, Carbon and all three Orchestrators stay outside routing, defaults and fallbacks. `Claude Opus 5.5 (High)`, `Claude Sonnet 5.5 (High)` and GPT-OSS remain unused because the Claude/GPT pool’s quota is too small. The model list excludes `Claude Opus/Sonnet 4.6 (Thinking)` (2026-10-03).
- **Historical Argon (High) checks:** a read-only inventory task matched Codex. Auto shell with the required flag and resume by ID passed verification.
- `--model` takes the **verbatim display string**, e.g. `--model "Gemini 4 Neon (High)"`. The `(Low/Medium/High)` suffix is a **reasoning-effort tier**, not a separate model.
- **An unknown `--model` fails hard** — `error: invalid model selection (--model "Gemini 9 Fake (High)" --effort ""): model Gemini 9 Fake (High) is not recognized as a known model or custom model in settings`, exit 1, followed by the `Available models` list. Only pass strings that appear in `agy models`.
- Selecting a **Claude** or **GPT-OSS** model routes to that provider **through Google's Antigravity backend** (Google-brokered, billed against Google's quota/credits — not your own Anthropic/OpenAI key).

## Conversations & resume (the id mechanism)

- You can't set an id (no `--session-id` like gemini). With `--output-format json` the id is returned as `conversation_id`; in text mode it isn't printed.
- State lives under **`~/.gemini/antigravity-cli/`**:
  - `conversations/<UUID>.db` — one SQLite DB per conversation. Ids are standard UUIDs.
  - **`cache/last_conversations.json`** — maps each **workspace dir → its latest conversation UUID**. Rewritten after every `-p` run for that cwd. Keys are real paths (e.g. `/private/tmp/…`). Not a source of identity for a specific call: any `-p` run from that cwd (in any session) overwrites it. Take the id from the call's JSON `conversation_id`; if it is missing, record UNKNOWN.
  - `history.jsonl` — prompt log (no ids).
- **Resume by id:** `agy --dangerously-skip-permissions --conversation <uuid> --model "Gemini 4 Neon (High)" -p "<prompt>"`. Use it for Neon conversations. Neon (High) recovered context in the original directory. In historical tests, Flash (High) and Argon (High) both recovered context in the original directory and in a different directory. Verify the resumed result against the task.
- **`-c` / `--continue`** resumes the latest conversation. From the matching workspace it's instant; from a different/empty dir it resorts to agentically grepping transcripts to find one — slow and side-effecty. Prefer `--conversation <uuid>` for topic routing.

## Safety / permissions

- **No usable read-only mode.** Sessions without a saved Agent Mode, including headless `-p`, default to Auto where available (Default elsewhere). `"agentMode": ""` in `settings.json` restores Default; Tool Permission `strict` takes precedence over Auto and still requires approval for edits. On this machine (no saved `agentMode`, terminal sandbox disabled), Argon (High) ran `date +%Y` and `cat probe.txt` without `--dangerously-skip-permissions`: exit 0, `SUCCESS`, non-empty `response`, no `denied_actions`, showing that this flag is not an isolation boundary and must still be passed on every Claude/Commander-initiated agy call as required by the user. With the flag, Auto shell ran `ls`, `wc -l` and file reads successfully and left the workspace unchanged. **Every Claude/Commander-initiated agy call must include `--dangerously-skip-permissions`**, including smoke tests, `/usage`, resumed conversations and image generation (user decision, 2026-11-16); this also applies when executing abbreviated command references in this document. Do not investigate or test behavior without the flag or seek alternatives via restricted allow-lists, `--settings` or deny rules. It is a headless compatibility method, **not isolation**. System-blocklisted commands and explicit deny rules still apply, and headless out-of-workspace reads and writes can proceed without waiting for approval. Do not rely on deny rules to protect secret files such as `.env`. The user's own independent AGY sessions are unaffected.
- **`--mode plan` is not read-only.** With `--dangerously-skip-permissions`, a workspace write request may produce a plan artifact under `~/.gemini/antigravity-cli/brain/<conversation_id>/` or write the requested workspace file itself. Behavior has varied between builds, so never use it as isolation.
- `--sandbox` gates network / full-disk / out-of-workspace operations behind confirmation, but **did not block a local `/tmp` write** — treat it as "restrict escape", not "read-only".
- For read-only intent, constrain via the **prompt** ("analyze and answer only; don't modify files or run shell; do not use run_workflow, swarm or any parallel subagents") and/or scope the workspace (`--add-dir` / cwd). `/swarm` is a quota-heavy preview. `run_workflow` is available to everyone and can fan out to parallel subagents that consume quota.

## Gotchas

- **First call may be slower** (observed cold call ~12 s, warm calls 5–20 s). Headless `-p` shutdown after printing a result completes within 30 s. Stale network connections retry on a fresh connection. When admin settings configure a proxy or custom CA, slow responses no longer time out at 60 s. `--print-timeout` defaults to no limit and waits indefinitely for background tasks. Always set it.
- **Empty piped stdout.** If print mode (`-p`) exits 0 with **empty** piped stdout, retry once. [antigravity-cli#76](https://github.com/google-antigravity/antigravity-cli/issues/76)
- **Shared `~/.gemini/` lineage** — agy reuses gemini-cli's config/auth dir (`oauth_creds.json`, `settings.json`, plugins). Per-model settings live in `~/.gemini/antigravity-cli/settings.json` and interactive use can mutate them under a script.
- **Images**: agy generates images on the Google subscription — no API key or extension. Requests go to a built-in `image-generator` subagent (Nano Banana Pro). In a historical test, Flash (High) generated a PNG illustration at the absolute path requested in the `-p` prompt using the image model. Very simple shapes may be drawn with code instead of the image model. Verify that the target file exists, check its format, and open it to inspect the content. JSON `response` may contain only progress text, so verify the file even when the response omits its path. (The `nanobanana` gemini-cli extension on disk is unregistered and unnecessary — an API-key path you don't need.)
- **Auth** = free Google account OAuth ("oauth-personal"); the sanctioned successor to gemini-cli's deprecated individual tier. No API key. `/logout` (interactive) signs out.
- **Quotas** — `agy --dangerously-skip-permissions -p "/usage"` shows weekly and five-hour limits for `Gemini Models` and `Claude and GPT models`. When Neon is unavailable, read-only work and technical docs return to Codex under global CLAUDE.md; prose writing waits for quota to reset without switching to Codex or Grok.

## Docs

- Antigravity — https://antigravity.google
- CLI repo (issues / README; proprietary) — https://github.com/google-antigravity/antigravity-cli
- Gemini-CLI → Antigravity migration — https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
