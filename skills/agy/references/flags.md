# `agy` (Antigravity CLI) reference

Verified against **agy 1.3.2** (`agy --version`, 2026-10-10); older notes are marked with their version. agy moves fast — the help is the source of truth at runtime; re-check with `agy --help` if behavior surprises you.

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
| `--dangerously-skip-permissions` | Auto-approve all tool-permission requests. **Required for headless `-p`** (re-verified 1.3.2): without it, any non-allowlisted tool (e.g. `write_file`) is auto-denied and the whole call gives up with exit 0, empty `response` and a `denied_actions` list. |
| `--effort <level>` | Listed in `--help`, but not supported on Flash or Claude Opus/Sonnet 5.5 (`--effort is not supported for model`, exit 1, re-verified 1.3.2); the tier is part of the model name. |
| `--mode <accept-edits\|plan>` | Execution mode. **`plan` is not read-only** (1.3.2): with `--dangerously-skip-permissions` it still wrote a file; without it even `read_file` was denied. |
| `--output-format <text\|json\|stream-json>` | Print-mode output format. Use **`json`** — see [JSON output](#json-output). |
| `--input-format`, `--json-schema` | stream-json input; JSON schema for structured final output. Not used by the skill. |
| `--project`, `--new-project`, `--agent`, `--disable-slash-commands`, `--remote-control` | Project / agent selection and other session options. Not used by the skill. |
| `--sandbox` | Run with terminal restrictions (network / out-of-workspace). **Not** a read-only mode — local writes still happen. |
| `--print-timeout <dur>` | Time limit for `-p`. Default **`0s` = no limit** in 1.3.x (was 5m in older builds) — always pass it (`5m` normal, `15m` broad exploration). |
| `--log-file <path>` | Override the CLI log path (logs default to `~/.gemini/antigravity-cli/log/`). |

## JSON output

`--output-format json` prints **one JSON object on stdout**; diagnostics go to stderr. Verified shapes (1.3.2):

```text
success:  {"conversation_id":"<uuid>","status":"SUCCESS","response":"正常\n","duration_seconds":3.1,"num_turns":1,"usage":{...}}           exit 0
denied:   {"conversation_id":"<uuid>","status":"SUCCESS","response":"","denied_actions":[{"action":"write_file",...}],...}               exit 0
          stderr: jetski: no output produced — a tool required the "write_file" permission ...
quota:    {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"Your AI credits balance is too low to continue.",...}   exit 3
          stderr: AGY_ERROR: {"short_error":"RESOURCE_EXHAUSTED (code 429) ...","error_code":429,"retryable":true,...}
bad model: no JSON; stderr "error: invalid model selection ..." + available list                                                     exit 1
```

- `conversation_id` is the id to store for resume (replaces reading the cache file).
- A resumed call (`--conversation <uuid>`) returns the same id with `num_turns` incremented.
- Success = exit 0 **and** `status == "SUCCESS"` **and** non-empty `response` **and** no `denied_actions`.

## Subcommands

- `agy models` — list available models (no flags).
- `agy -p "/usage"` — print remaining quota per pool (`Gemini Models`, `Claude and GPT models`; weekly and five-hour limits) with reset times (UTC when piped). Takes a few seconds.
- `agy mcp` — manage MCP servers (add, remove, list, enable, disable).
- `agy agents` — list available agents.
- `agy remote-control` — manage the remote-control daemon.
- `agy plugin <cmd>` (alias `plugins`): `list`, `import [gemini|claude]`, `install <target>` (e.g. `name@marketplace`), `uninstall <name>`, `enable <name>`, `disable <name>`, `validate [path]`, `link <mp> <target>`, `help`. (Importing the `nanobanana` extension is optional — agy generates images natively; see Images below.)
- `agy install` — configure PATH / shell aliases (`--dir`, `--skip-aliases`, `--skip-path`).
- `agy changelog` — release notes.
- `agy update` — update the CLI.
- `agy help [subcommand]` — help (subcommands also take `-h`/`--help`).

## Models

`agy models` (this account, 2026-10-10, unchanged since 2026-10-03):

```
Gemini 3.8 Flash (High) | (Medium) | (Low)
Gemini 3.7 Flash (High) | (Medium) | (Low)
Gemini 3.6 Flash (High) | (Medium) | (Low)
Gemini 3.1 Pro (High) | (Low)
Claude Opus 5.5 (High) | (Medium) | (Low)
Claude Sonnet 5.5 (High) | (Medium) | (Low)
GPT-OSS 120B (Medium)
```

- **Default choice:** always pass `--model "Gemini 3.8 Flash (High)"` explicitly; on quota errors follow the role-based fallback in global CLAUDE.md (the only authority for fallbacks). Only the latest Gemini Flash is used; `Claude Opus 5.5 (High)`, `Claude Sonnet 5.5 (High)` and GPT-OSS are listed but not used (the Claude/GPT pool's quota is too small), and agy is not used for code changes. `Claude Opus/Sonnet 4.6 (Thinking)` no longer exist (2026-10-03). The built-in default (no `--model`) is not pinned and has drifted across releases. `Gemini 3.5 Flash (…)` from older docs no longer exists.
- `--model` takes the **verbatim display string**, e.g. `--model "Gemini 3.1 Pro (High)"`. The `(Low/Medium/High)` suffix is a **reasoning-effort tier**, not a separate model.
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

- **No usable read-only mode.** Verified on agy 1.2.13 (2026-09-29) and re-verified on 1.3.2 (2026-10-10): without `--dangerously-skip-permissions`, allowlisted read tools (e.g. `git diff`) still run, but a `write_file` request is auto-denied and the call ends with exit 0 and only `no output produced — a tool required the "write_file" permission…` (no file written, no answer). With the flag, `-p` auto-approves and executes everything — it will create/modify files and run shell if the task leads there. (Older builds, e.g. 1.0.10, wrote files even without the flag.)
- `--mode plan` is not read-only either (1.3.2): with `--dangerously-skip-permissions` it wrote a file on request; without it, even `read_file` was denied and the call gave up.
- `--sandbox` (verified on an older build) gates network / full-disk / out-of-workspace operations behind confirmation, but **did not block a local `/tmp` write** — treat it as "restrict escape", not "read-only".
- For read-only intent, constrain via the **prompt** ("analyze and answer only; don't modify files or run shell") and/or scope the workspace (`--add-dir` / cwd).

## Gotchas

- **Cold start ~2–3 min** on the first call (language-server spin-up + auth); warm calls took 3–50 s in 1.3.2 testing. `--print-timeout` defaults to no limit — always set it.
- **Non-TTY stdout drop** (old builds) ([antigravity-cli#76](https://github.com/google-antigravity/antigravity-cli/issues/76)): on some builds (v1.0.0 / Windows), `agy -p` can exit 0 with **empty** piped stdout. Not reproduced on macOS 1.0.10, but guard for it: empty output + exit 0 → retry once.
- **Shared `~/.gemini/` lineage** — agy reuses gemini-cli's config/auth dir (`oauth_creds.json`, `settings.json`, plugins). Per-model settings live in `~/.gemini/antigravity-cli/settings.json` and interactive use can mutate them under a script.
- **Images**: agy generates images on the Google subscription — no API key or extension. Since 1.2.16 requests go to a built-in `image-generator` subagent (Nano Banana Pro). An explicit absolute output path in the `-p` prompt is honored (verified 1.3.2); very simple shapes may be drawn with code instead of the image model. (The `nanobanana` gemini-cli extension on disk is unregistered and unnecessary — an API-key path you don't need.)
- **Auth** = free Google account OAuth ("oauth-personal"); the sanctioned successor to gemini-cli's deprecated individual tier. No API key. `/logout` (interactive) signs out.
- **Quotas** are per pool (Gemini vs Claude/GPT), each with weekly and five-hour limits; check with `agy -p "/usage"`. On exhaustion follow the global Router — don't step down to other agy models.

## Docs

- Antigravity — https://antigravity.google
- CLI repo (issues / README; proprietary) — https://github.com/google-antigravity/antigravity-cli
- Gemini-CLI → Antigravity migration — https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
