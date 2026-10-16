# `agy` (Antigravity CLI) reference

Verified against **agy 1.4.0** (2026-10-16): `--help`, `agy models`, `/usage`, JSON success/denied/bad-model/bad-effort shapes, resume by id, the permission guard and `--mode plan`. Items not re-run on 1.4.0 (quota-exhaustion shape, images, `--sandbox`) keep the version they were last seen on. agy moves fast — the help is the source of truth at runtime; re-check with `agy --help` if behavior surprises you.

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
| `--dangerously-skip-permissions` | Auto-approve all tool-permission requests. **Required for headless `-p`** (re-verified 1.4.0): without it, any non-allowlisted tool (e.g. `write_file`) is auto-denied and the whole call gives up with exit 0, empty `response` and a `denied_actions` list. |
| `--effort <level>` | `--help` lists `low\|medium\|high\|xhigh\|max`, but with a tiered name it fails: `--model "Gemini 4 Argon (High)" --effort high` → `--effort is not supported for model`, exit 1 (1.4.0). Since 1.3.4 a base model name without `--effort` picks the default tier. Keep using the tier in the model name. |
| `--mode <accept-edits\|auto\|plan>` | Execution mode (`auto` added in 1.3.5, untested). **`plan` is not read-only**: on 1.4.0 with `--dangerously-skip-permissions` it answered a write request by writing `implementation_plan.md` under `~/.gemini/antigravity-cli/brain/<conversation_id>/` (1.3.2 wrote the workspace file). |
| `--output-format <text\|json\|stream-json>` | Print-mode output format. Use **`json`** — see [JSON output](#json-output). |
| `--input-format`, `--json-schema` | stream-json input; JSON schema for structured final output. Not used by the skill. |
| `--project`, `--new-project`, `--agent`, `--disable-slash-commands`, `--remote-control` | Project / agent selection and other session options. Not used by the skill. |
| `--sandbox` | Run with terminal restrictions (network / out-of-workspace). **Not** a read-only mode — local writes still happen. |
| `--print-timeout <dur>` | Time limit for `-p`. Default **`0s` = no limit** in 1.4.0 (was 5m in older builds) — always pass it (`5m` normal, `15m` broad exploration). |
| `--log-file <path>` | Override the CLI log path (logs default to `~/.gemini/antigravity-cli/log/`). |

## JSON output

`--output-format json` prints **one JSON object on stdout**; diagnostics go to stderr. Verified shapes (1.4.0 unless marked):

```text
success:  {"conversation_id":"<uuid>","status":"SUCCESS","response":"正常\n","duration_seconds":3.1,"num_turns":1,"usage":{...}}           exit 0
denied:   {"conversation_id":"<uuid>","status":"SUCCESS","response":"","denied_actions":[{"action":"write_file",...}],...}               exit 0
          stderr: jetski: no output produced — a tool required the "write_file" permission ...
quota:    {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"Your AI credits balance is too low to continue.",...}   exit 3  (1.3.2)
          stderr: AGY_ERROR: {"short_error":"RESOURCE_EXHAUSTED (code 429) ...","error_code":429,"retryable":true,...}
bad model/effort: {"conversation_id":"","status":"ERROR","response":"","error":"invalid model selection ...","num_turns":0,...}   exit 1
          stderr: error: invalid model selection ... (+ available list for a bad model)
```

- `conversation_id` is the id to store for resume (replaces reading the cache file).
- A resumed call (`--conversation <uuid>`) returns the same id with `num_turns` incremented.
- Success = exit 0 **and** `status == "SUCCESS"` **and** non-empty `response` **and** no `denied_actions`.

## Subcommands

- `agy models` — list available models (no flags).
- `agy -p "/usage"` — print remaining quota per pool (`Gemini Models` and `Claude and GPT models` with weekly and five-hour limits; `Gemini 4 Argon` with a weekly limit only, 1.4.0) with reset times (UTC when piped). Takes a few seconds.
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

`agy models` (this account, agy 1.4.0, 2026-10-16):

```
Gemini 4 Argon (High) | (Medium) | (Low)     ← own weekly-only quota pool
Gemini 3.8 Flash (High) | (Medium) | (Low)   ← the only Flash left
Claude Opus 5.5 (High) | (Medium) | (Low)
Claude Sonnet 5.5 (High) | (Medium) | (Low)
GPT-OSS 120B (Medium)
```

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

- **No usable read-only mode.** Re-verified on agy 1.4.0 (2026-10-16): without `--dangerously-skip-permissions`, allowlisted read tools (e.g. `git diff`) still run, but a `write_file` request is auto-denied and the call ends with exit 0 and only `no output produced — a tool required the "write_file" permission…` (no file written, no answer). With the flag, `-p` auto-approves and executes everything — it will create/modify files and run shell if the task leads there. (Older builds, e.g. 1.0.10, wrote files even without the flag.)
- `--mode plan` is not read-only either: on 1.4.0 with `--dangerously-skip-permissions` it wrote a plan artifact under `~/.gemini/antigravity-cli/brain/<conversation_id>/` instead of the requested workspace file (1.3.2 wrote the workspace file).
- `--sandbox` (verified on an older build) gates network / full-disk / out-of-workspace operations behind confirmation, but **did not block a local `/tmp` write** — treat it as "restrict escape", not "read-only".
- For read-only intent, constrain via the **prompt** ("analyze and answer only; don't modify files or run shell") and/or scope the workspace (`--add-dir` / cwd).

## Gotchas

- **Cold start ~2–3 min** on the first call (language-server spin-up + auth); warm calls took 5–20 s in 1.4.0 testing. `--print-timeout` defaults to no limit — always set it.
- **Non-TTY stdout drop** (old builds) ([antigravity-cli#76](https://github.com/google-antigravity/antigravity-cli/issues/76)): on some builds (v1.0.0 / Windows), `agy -p` can exit 0 with **empty** piped stdout. Not reproduced on macOS 1.0.10, but guard for it: empty output + exit 0 → retry once.
- **Shared `~/.gemini/` lineage** — agy reuses gemini-cli's config/auth dir (`oauth_creds.json`, `settings.json`, plugins). Per-model settings live in `~/.gemini/antigravity-cli/settings.json` and interactive use can mutate them under a script.
- **Images**: agy generates images on the Google subscription — no API key or extension. Since 1.2.16 requests go to a built-in `image-generator` subagent (Nano Banana Pro). An explicit absolute output path in the `-p` prompt is honored (verified 1.3.2); very simple shapes may be drawn with code instead of the image model. (The `nanobanana` gemini-cli extension on disk is unregistered and unnecessary — an API-key path you don't need.)
- **Auth** = free Google account OAuth ("oauth-personal"); the sanctioned successor to gemini-cli's deprecated individual tier. No API key. `/logout` (interactive) signs out.
- **Quotas** are per pool — `Gemini Models` (Flash) and `Claude and GPT models` with weekly and five-hour limits, `Gemini 4 Argon` with a weekly limit only; check with `agy -p "/usage"`. On exhaustion follow the global Router — don't step down to other agy models.

## Docs

- Antigravity — https://antigravity.google
- CLI repo (issues / README; proprietary) — https://github.com/google-antigravity/antigravity-cli
- Gemini-CLI → Antigravity migration — https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
