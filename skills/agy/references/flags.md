# `agy` (Antigravity CLI) reference

Verified against **agy 1.0.10** (`agy --version`). agy is brand-new and moving fast — the help is the source of truth at runtime; re-check with `agy --help` if behavior surprises you.

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
| `--dangerously-skip-permissions` | Auto-approve all tool-permission requests. **Required for headless `-p`** on agy 1.2.13: without it, any non-allowlisted tool (e.g. `write_file`) is auto-denied and the whole call gives up with exit 0 and no answer. |
| `--effort <level>` | Not supported on Flash or Claude Opus/Sonnet 5.5 (`--effort is not supported for model`); the tier is part of the model name. |
| `--sandbox` | Run with terminal restrictions (network / out-of-workspace). **Not** a read-only mode — local writes still happen. |
| `--print-timeout <dur>` | Timeout for `-p` wait. Default **5m0s**. |
| `--log-file <path>` | Override the CLI log path (logs default to `~/.gemini/antigravity-cli/log/`). |

There is **no** `--json` / `-o` / `--output` / `--format` flag — output is plain stdout only.

## Subcommands

- `agy models` — list available models (no flags).
- `agy plugin <cmd>` (alias `plugins`): `list`, `import [gemini|claude]`, `install <target>` (e.g. `name@marketplace`), `uninstall <name>`, `enable <name>`, `disable <name>`, `validate [path]`, `link <mp> <target>`, `help`. (Importing the `nanobanana` extension is optional — agy generates images natively; see Images below.)
- `agy install` — configure PATH / shell aliases (`--dir`, `--skip-aliases`, `--skip-path`).
- `agy changelog` — release notes.
- `agy update` — update the CLI.
- `agy help [subcommand]` — help (subcommands also take `-h`/`--help`).

## Models

`agy models` (this account, 2026-10-03):

```
Gemini 3.8 Flash (High) | (Medium) | (Low)
Gemini 3.7 Flash (High) | (Medium) | (Low)
Gemini 3.6 Flash (High) | (Medium) | (Low)
Gemini 3.1 Pro (High) | (Low)
Claude Opus 5.5 (High) | (Medium) | (Low)
Claude Sonnet 5.5 (High) | (Medium) | (Low)
GPT-OSS 120B (Medium)
```

- **Default choice:** always pass `--model "Gemini 3.8 Flash (High)"` explicitly; on quota errors follow the role-based fallback in global CLAUDE.md. For code changes via agy use `Claude Sonnet 5.5 (High)`. `Claude Opus 5.5 (High)` is listed but not used (quota too small). `Claude Opus/Sonnet 4.6 (Thinking)` no longer exist (2026-10-03). The built-in default (no `--model`) is not pinned and has drifted across releases. `Gemini 3.5 Flash (…)` from older docs no longer exists.
- `--model` takes the **verbatim display string**, e.g. `--model "Gemini 3.1 Pro (High)"`. The `(Low/Medium/High)` suffix is a **reasoning-effort tier**, not a separate model.
- **An unknown `--model` fails hard** — `error: invalid model selection (--model "…"): model … is not recognized as a known model or custom model in settings`, exit 1, followed by the available list. Only pass strings that appear in `agy models`.
- Selecting a **Claude** or **GPT-OSS** model routes to that provider **through Google's Antigravity backend** (Google-brokered, billed against Google's quota/credits — not your own Anthropic/OpenAI key).

## Conversations & resume (the id mechanism)

- No id is printed to stdout/stderr and you can't set one (no `--session-id` like gemini).
- State lives under **`~/.gemini/antigravity-cli/`**:
  - `conversations/<UUID>.db` — one SQLite DB per conversation. Ids are standard UUIDs.
  - **`cache/last_conversations.json`** — maps each **workspace dir → its latest conversation UUID**. Rewritten after every `-p` run for that cwd. **This is the capture point**: read the value for the current dir right after a call.
  - `history.jsonl` — prompt log (no ids).
- **Resume by id:** `agy --conversation <uuid> -p "<prompt>"` — cwd-independent, the reliable path.
- **`-c` / `--continue`** resumes the latest conversation. From the matching workspace it's instant; from a different/empty dir it resorts to agentically grepping transcripts to find one — slow and side-effecty. Prefer `--conversation <uuid>` for topic routing.

## Safety / permissions

- **No usable read-only mode.** Verified on agy 1.2.13 (2026-09-29): without `--dangerously-skip-permissions`, allowlisted read tools (e.g. `git diff`) still run, but a `write_file` request is auto-denied and the call ends with exit 0 and only `no output produced — a tool required the "write_file" permission…` (no file written, no answer). With the flag, `-p` auto-approves and executes everything — it will create/modify files and run shell if the task leads there. (Older builds, e.g. 1.0.10, wrote files even without the flag.)
- `--sandbox` gates network / full-disk / out-of-workspace operations behind confirmation, but **did not block a local `/tmp` write** — treat it as "restrict escape", not "read-only".
- For read-only intent, constrain via the **prompt** ("analyze and answer only; don't modify files or run shell") and/or scope the workspace (`--add-dir` / cwd).

## Gotchas

- **Cold start ~2–3 min** on the first call (language-server spin-up + auth). Use a generous timeout; `--print-timeout` defaults to 5m.
- **Non-TTY stdout drop** ([antigravity-cli#76](https://github.com/google-antigravity/antigravity-cli/issues/76)): on some builds (v1.0.0 / Windows), `agy -p` can exit 0 with **empty** piped stdout. Not reproduced on macOS 1.0.10, but guard for it: empty output + exit 0 → retry once.
- **Shared `~/.gemini/` lineage** — agy reuses gemini-cli's config/auth dir (`oauth_creds.json`, `settings.json`, plugins). Per-model settings live in `~/.gemini/antigravity-cli/settings.json` and interactive use can mutate them under a script.
- **Images**: agy generates images **natively** via a built-in `generate_image` tool (Antigravity's Nano Banana Pro model), on the Google subscription — no API key or extension. Just ask in a `-p` call ("generate … and save to `<path>`"); it honors the path. (The `nanobanana` gemini-cli extension on disk is unregistered and unnecessary — an API-key path you don't need.)
- **Auth** = free Google account OAuth ("oauth-personal"); the sanctioned successor to gemini-cli's deprecated individual tier. No API key. `/logout` (interactive) signs out.
- **Per-model quotas** exist (premium Gemini-Pro / Claude buckets) and aren't publicly numbered — they can exhaust; fall back to a lighter model.

## Docs

- Antigravity — https://antigravity.google
- CLI repo (issues / README; proprietary) — https://github.com/google-antigravity/antigravity-cli
- Gemini-CLI → Antigravity migration — https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
