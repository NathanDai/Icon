# `agy` (Antigravity CLI) reference

Verified against **agy 1.4.0** (2026-10-16): JSON denied/bad-model shapes, resume by id, the permission guard and `--mode plan`. Re-checked on **agy 1.4.12** (2026-11-02): `--help`, `/usage`, and the quota-exhaustion shape (`finished_reason`, added in 1.4.11; quota shape not re-tested on 1.5.3). Re-verified on **agy 1.5.3** (2026-11-08): `--print-timeout` expiry (exit 3 + `ERROR` since 1.5.0) and `--effort` rejection. Re-verified on **agy 1.5.9** (2026-11-16): version, `agy models`, Hydrogen (High) smoke, `/usage` pool rows, Auto-mode shell with/without the permission flag, JSON success and normal omission of `finished_reason`. Unretested items (timeout/quota/bad-model shapes, effort rejection, resume, images, `--sandbox`) retain their earlier version stamps. Mode and stability updates below come from the 1.5.4–1.5.9 release notes. agy moves fast — help is the runtime reference; re-check with `agy --help` if behavior surprises you.

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
| `--effort <level>` | `--help` lists `low\|medium\|high\|xhigh\|max`, but with a tiered name it fails: `--model "Gemini 4 Argon (High)" --effort high` → `invalid model selection (--model "Gemini 4 Argon (High)" --effort "high"): --effort is not supported for model "Gemini 4 Argon (High)"`, `"finished_reason":"error"`, exit 1 (re-verified on 1.5.3 (2026-11-08)). Since 1.3.4 a base model name without `--effort` picks the default tier. Keep using the tier in the model name. |
| `--mode <accept-edits\|auto\|plan>` | Since 1.5.7, headless `-p` defaults to Auto without a saved Agent Mode where available; see [Safety / permissions](#safety--permissions) for mode details. **`plan` is not read-only**: on 1.4.0 with `--dangerously-skip-permissions` it answered a write request by writing `implementation_plan.md` under `~/.gemini/antigravity-cli/brain/<conversation_id>/` (1.3.2 wrote the workspace file). |
| `--output-format <text\|json\|stream-json>` | Print-mode output format. Use **`json`** — see [JSON output](#json-output). |
| `--input-format`, `--json-schema` | stream-json input; JSON schema for structured final output. Not used by the skill. |
| `--project`, `--new-project`, `--agent`, `--disable-slash-commands`, `--remote-control` | Project / agent selection and other session options. Not used by the skill. |
| `--sandbox` | Run with terminal restrictions (network / out-of-workspace). **Not** a read-only mode — local writes still happen. |
| `--print-timeout <dur>` | Time limit for `-p`. Default **`0s` = no limit** (re-verified on 1.5.3 (2026-11-08); since 1.5.0 it waits indefinitely for background tasks to finish instead of hitting the earlier hidden 30m cap; was 5m in older builds) — always pass it (`20m` normal, `60m` broad exploration, reviews, writing). Since 1.5.0, on expiry the run exits 3 with `"status":"ERROR"`, `"error":"print timeout after 5s with the turn still in progress; the response is partial"`, `"finished_reason":"print_timeout"`, empty `response`, and `AGY_ERROR` (`"status":"DEADLINE_EXCEEDED"`, `"reason":"print_timeout"`, `"retryable":false`) on stderr (re-verified on 1.5.3 (2026-11-08)). |
| `--log-file <path>` | Override the CLI log path (logs default to `~/.gemini/antigravity-cli/log/`). |
| `--settings <json\|path>` | Settings for this session only, never saved: a JSON object of `settings.json` keys, inline or as a file path (seen in 1.4.12 `--help`). Not used by the skill; must not be used in place of `--dangerously-skip-permissions` (user decision, 2026-11-16). |

## JSON output

`--output-format json` prints **one JSON object on stdout**; diagnostics go to stderr. Verified shapes (1.4.0 unless marked):

```text
success:  {"conversation_id":"<uuid>","status":"SUCCESS","response":"正常\n","duration_seconds":6.6,"num_turns":1,"usage":{...}}           exit 0  (re-verified on 1.5.9 (2026-11-16))
timeout:  {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"print timeout after 5s with the turn still in progress; the response is partial","duration_seconds":0,"num_turns":1,"usage":{...},"finished_reason":"print_timeout"}   exit 3  (since 1.5.0; re-verified on 1.5.3 (2026-11-08))
          stderr: [agy] print timeout after 5s with turn in progress; returning partial output
                  error: print timeout after 5s with the turn still in progress; the response is partial
                  AGY_ERROR: {"short_error":"print timeout after 5s with the turn still in progress; the response is partial","status":"DEADLINE_EXCEEDED","retryable":false,"reason":"print_timeout"}
denied:   {"conversation_id":"<uuid>","status":"SUCCESS","response":"","denied_actions":[{"action":"write_file",...}],...}               exit 0
          stderr: jetski: no output produced — a tool required the "write_file" permission ...
quota:    {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"Your AI credits balance is too low to continue.","finished_reason":"error",...}   exit 3  (1.4.12; not re-tested on 1.5.3)
          stderr: error: Your AI credits balance is too low to continue.
                  AGY_ERROR: {"short_error":"RESOURCE_EXHAUSTED (code 429) ...","status":"RESOURCE_EXHAUSTED","error_code":429,"retryable":true,...}
bad model/effort: {"conversation_id":"","status":"ERROR","response":"","error":"invalid model selection (--model \"Gemini 4 Argon (High)\" --effort \"high\"): --effort is not supported for model \"Gemini 4 Argon (High)\"","duration_seconds":0,"num_turns":0,"usage":{...},"finished_reason":"error"}   exit 1  (--effort re-verified on 1.5.3 (2026-11-08); bad model on 1.4.0)
          stderr: error: invalid model selection ... (+ available list for a bad model)
```

- The `denied` example is historical (older versions / non-Auto mode); 1.5.9 Auto shell no longer triggered it without the flag. Every call in this configuration must include `--dangerously-skip-permissions` (user decision, 2026-11-16).
- `conversation_id` is the id to store for resume (replaces reading the cache file).
- A resumed call (`--conversation <uuid>`) returns the same id with `num_turns` incremented.
- `finished_reason` (since 1.4.11) appears only when a turn ended early: `print_timeout`, `interrupted` or `error`. It is omitted on a normal finish (re-verified on 1.5.9 (2026-11-16)).
- Success = exit 0 **and** `status == "SUCCESS"` **and** non-empty `response` **and** no `denied_actions` **and** no `finished_reason`. Since both `--print-timeout` expiry and quota exhaustion return exit 3 with `status == "ERROR"`, distinguish them by `finished_reason` (`print_timeout` vs `error`), `error` text, and `AGY_ERROR.status` (`DEADLINE_EXCEEDED` vs `RESOURCE_EXHAUSTED` / 429).

## Subcommands

- `agy models` — list available models, one `model id<TAB>display name` per row (re-verified on 1.5.9 (2026-11-16)).
- `agy -p "/usage"` — print remaining quota per pool (`Gemini Models` and `Claude and GPT models` with weekly and five-hour limits; `Gemini 4 Argon` with a weekly limit only; five rows re-verified on 1.5.9 (2026-11-16); no separate Hydrogen pool; Hydrogen shares Flash’s `Gemini Models` pool, confirmed by before/after usage checks on 1.5.9 (2026-11-16)) with reset times (UTC when piped). Takes a few seconds.
- `agy mcp` — manage MCP servers (add, remove, list, enable, disable).
- `agy agents` (alias `agent`) — list available agents.
- `agy mic-serve` — serve this machine's microphone to a CLI on another host (1.4.0; not used).
- `agy remote-control` — manage the remote-control daemon.
- `agy plugin <cmd>` (alias `plugins`): `list`, `import [gemini|claude]`, `install <target>` (e.g. `name@marketplace`), `uninstall <name>`, `enable <name>`, `disable <name>`, `validate [path]`, `link <mp> <target>`, `help`. (Importing the `nanobanana` extension is optional — agy generates images natively; see Images below.)
- `agy install` — configure PATH / shell aliases (`--dir`, `--skip-aliases`, `--skip-path`).
- `agy changelog` — release notes.
- `agy update` — update the CLI.
- `agy help [subcommand]` — help (subcommands also take `-h`/`--help`).

## Models

`agy models` (Google-account login; re-verified on 1.5.9 (2026-11-16)). Each row is `model id<TAB>display name`; summarized display names below:

```
Gemini 4 Argon (High) | (Medium) | (Low)     ← own weekly-only quota pool
Gemini 4 Hydrogen (Low) | (Medium) | (High) | (XHigh)
Orchestrator (Argon)                      ← id gemini-pro-orchestrator-g1-pro
Gemini 3.8 Flash (High) | (Medium) | (Low)   ← writing and images
Claude Opus 5.5 (High) | (Medium) | (Low)
Claude Sonnet 5.5 (High) | (Medium) | (Low)
GPT-OSS 120B (Medium)
```

- **Hydrogen:** visible on this Google-account login as of 1.5.9; `Gemini 4 Hydrogen (High)` passed a smoke test (exit 0, `SUCCESS`, response `正常`, ~3.7 s). In a small blind review of four real pre-fix Python files with one known defect each (agy 1.5.9, 2026-11-16), Hydrogen (High) found one defect and partially identified one in ~182 s versus Argon (High)’s three in ~454 s; both missed a TLS certificate-validation defect and used similar tokens (~78k total). Hydrogen shares Flash’s `Gemini Models` pool and remains **excluded from routing**, defaults and fallbacks because it found fewer defects than Argon in this sample and would consume writing quota; further evaluation is the user’s decision. The 1.5.8 release notes name API-key/ADC access; this Google-login observation takes precedence here.
- **Default choice:** always pass `--model` explicitly — `"Gemini 4 Argon (High)"` for read-only work, `"Gemini 3.8 Flash (High)"` for writing and images; on quota errors follow the role-based fallback in global CLAUDE.md (the only authority for fallbacks). Only these two Gemini models are used; `Claude Opus 5.5 (High)`, `Claude Sonnet 5.5 (High)` and GPT-OSS are listed but not used (the Claude/GPT pool's quota is too small), and agy is not used for code changes. `Claude Opus/Sonnet 4.6 (Thinking)` no longer exist (2026-10-03). The built-in default (no `--model`) is not pinned and has drifted across releases. Older Gemini Flash versions from earlier docs no longer exist.
- `--model` takes the **verbatim display string**, e.g. `--model "Gemini 4 Argon (High)"`. The `(Low/Medium/High)` suffix is a **reasoning-effort tier**, not a separate model.
- **An unknown `--model` fails hard** — `error: invalid model selection (--model "…"): model … is not recognized as a known model or custom model in settings`, exit 1, followed by the available list. Only pass strings that appear in `agy models`.
- Selecting a **Claude** or **GPT-OSS** model routes to that provider **through Google's Antigravity backend** (Google-brokered, billed against Google's quota/credits — not your own Anthropic/OpenAI key).

## Conversations & resume (the id mechanism)

- You can't set an id (no `--session-id` like gemini). With `--output-format json` the id is returned as `conversation_id`; in text mode it isn't printed.
- State lives under **`~/.gemini/antigravity-cli/`**:
  - `conversations/<UUID>.db` — one SQLite DB per conversation. Ids are standard UUIDs.
  - **`cache/last_conversations.json`** — maps each **workspace dir → its latest conversation UUID**. Rewritten after every `-p` run for that cwd. Keys are real paths (e.g. `/private/tmp/…`). Not a source of identity for a specific call: any `-p` run from that cwd (in any session) overwrites it. Take the id from the call's JSON `conversation_id`; if it is missing, record UNKNOWN.
  - `history.jsonl` — prompt log (no ids).
- **Resume by id:** `agy --conversation <uuid> -p "<prompt>"` — cwd-independent, the reliable path.
- **`-c` / `--continue`** resumes the latest conversation. From the matching workspace it's instant; from a different/empty dir it resorts to agentically grepping transcripts to find one — slow and side-effecty. Prefer `--conversation <uuid>` for topic routing.

## Safety / permissions

- **No usable read-only mode.** Historical 1.4.0 checks: allowlisted reads ran without the permission flag, but `write_file` was auto-denied (exit 0, no answer). This is not a universal current rule. Since 1.5.7, sessions without a saved Agent Mode, including headless `-p`, default to Auto where available (Default elsewhere). `"agentMode": ""` in `settings.json` restores Default; Tool Permission `strict` takes precedence over Auto and still requires approval for edits. On this machine (no saved `agentMode`, terminal sandbox disabled), Argon (High) ran `date +%Y` and `cat probe.txt` without `--dangerously-skip-permissions`: exit 0, `SUCCESS`, non-empty `response`, no `denied_actions` (re-verified on 1.5.9 (2026-11-16)); the same call with the flag also succeeded. The older auto-denial symptom (exit 0, empty response, `denied_actions`) no longer reproduced for shell in Auto. **Every Claude/Commander-initiated agy call must include `--dangerously-skip-permissions`**, including smoke tests, `/usage`, resumed conversations and image generation (user decision, 2026-11-16); this also applies when executing abbreviated command references in this document. Do not investigate or test behavior without the flag or seek alternatives via restricted allow-lists, `--settings` or deny rules. It is a headless compatibility method, **not isolation**; since 1.5.2 system-blocklisted commands and explicit deny rules still apply, while headless out-of-workspace reads/writes no longer hang on approval. Do not rely on deny rules to protect secret files such as `.env`. The user's own independent AGY sessions are unaffected.
- `--mode plan` is not read-only either: on 1.4.0 with `--dangerously-skip-permissions` it wrote a plan artifact under `~/.gemini/antigravity-cli/brain/<conversation_id>/` instead of the requested workspace file (1.3.2 wrote the workspace file).
- `--sandbox` (verified on an older build) gates network / full-disk / out-of-workspace operations behind confirmation, but **did not block a local `/tmp` write** — treat it as "restrict escape", not "read-only".
- For read-only intent, constrain via the **prompt** ("analyze and answer only; don't modify files or run shell; do not use run_workflow, swarm or any parallel subagents") and/or scope the workspace (`--add-dir` / cwd). `/swarm` is a quota-heavy preview since 1.5.5; `run_workflow` is available to everyone since 1.5.9 and can fan out to parallel subagents that consume quota.

## Gotchas

- **First call may be slower** (historical 1.5.3 cold call ~12 s, warm calls 5–20 s). Release notes: 1.5.5 fixed headless `-p` sometimes not exiting after printing a result; shutdown completes within 30 s for that case. Since 1.5.8, stale network connections retry on a fresh connection, and slow responses no longer time out at 60 s when admin settings configure a proxy or custom CA. `--print-timeout` defaults to no limit (since 1.5.0 it waits indefinitely for background tasks; last re-verified on 1.5.3 (2026-11-08)) — always set it.
- **Non-TTY stdout drop** (old builds) ([antigravity-cli#76](https://github.com/google-antigravity/antigravity-cli/issues/76)): on some builds (v1.0.0 / Windows), `agy -p` can exit 0 with **empty** piped stdout. Not reproduced on macOS 1.0.10, but guard for it: empty output + exit 0 → retry once.
- **Shared `~/.gemini/` lineage** — agy reuses gemini-cli's config/auth dir (`oauth_creds.json`, `settings.json`, plugins). Per-model settings live in `~/.gemini/antigravity-cli/settings.json` and interactive use can mutate them under a script.
- **Images**: agy generates images on the Google subscription — no API key or extension. Since 1.2.16 requests go to a built-in `image-generator` subagent (Nano Banana Pro). An explicit absolute output path in the `-p` prompt is honored (verified 1.3.2); very simple shapes may be drawn with code instead of the image model. (The `nanobanana` gemini-cli extension on disk is unregistered and unnecessary — an API-key path you don't need.)
- **Auth** = free Google account OAuth ("oauth-personal"); the sanctioned successor to gemini-cli's deprecated individual tier. No API key. `/logout` (interactive) signs out.
- **Quotas** are per pool — `Gemini Models` (Flash) and `Claude and GPT models` with weekly and five-hour limits, `Gemini 4 Argon` with a weekly limit only; check with `agy -p "/usage"`. On exhaustion follow the global Router — don't step down to other agy models.

## Docs

- Antigravity — https://antigravity.google
- CLI repo (issues / README; proprietary) — https://github.com/google-antigravity/antigravity-cli
- Gemini-CLI → Antigravity migration — https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
