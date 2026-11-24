# `agy` (Antigravity CLI) reference

Re-verified on **agy 1.5.13** (2026-11-20): `agy models`, all 16 non-Claude/GPT smoke calls, JSON success with no `finished_reason`, resume by id, image generation, Auto-mode shell with the required permission flag, `--effort high` rejection, the bad-model error, `--print-timeout 5s` expiry and the five `/usage` rows with zero model usage. All three documented commands passed `evals/lint_agy_commands.py` on that version. Historical checks retain their dates: denied actions and `--mode plan` (1.4.0), quota exhaustion (1.4.12), and Auto shell without the flag (1.5.9). `--sandbox` retains its original verification note below. On 1.5.13, `agy changelog` ended at 1.5.9 (no changelog entries for 1.5.10–1.5.13). Mode and stability notes below come from the 1.5.4–1.5.9 release notes.

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
| `--effort <level>` | `--help` lists `low\|medium\|high\|xhigh\|max`, but Neon (High) and Argon (High) both reject `--effort high`: `--model "Gemini 4 Argon (High)" --effort high` → `invalid model selection (--model "Gemini 4 Argon (High)" --effort "high"): --effort is not supported for model "Gemini 4 Argon (High)"`, `"finished_reason":"error"`, exit 1 (re-verified on 1.5.13 (2026-11-20)). Since 1.3.4 a base model name without `--effort` picks the default tier. Keep using the tier in the model name. |
| `--mode <accept-edits\|auto\|plan>` | Since 1.5.7, headless `-p` defaults to Auto without a saved Agent Mode where available; see [Safety / permissions](#safety--permissions) for mode details. **`plan` is not read-only**: on 1.4.0 with `--dangerously-skip-permissions` it answered a write request by writing `implementation_plan.md` under `~/.gemini/antigravity-cli/brain/<conversation_id>/` (1.3.2 wrote the workspace file). |
| `--output-format <text\|json\|stream-json>` | Print-mode output format. Use **`json`** — see [JSON output](#json-output). |
| `--input-format`, `--json-schema` | stream-json input; JSON schema for structured final output. Not used by the skill. |
| `--project`, `--new-project`, `--agent`, `--disable-slash-commands`, `--remote-control` | Project / agent selection and other session options. Not used by the skill. |
| `--sandbox` | Run with terminal restrictions (network / out-of-workspace). **Not** a read-only mode — local writes still happen. |
| `--print-timeout <dur>` | Time limit for `-p`. Default **`0s` = no limit** (re-verified on 1.5.3 (2026-11-08); since 1.5.0 it waits indefinitely for background tasks to finish instead of hitting the earlier hidden 30m cap; was 5m in older builds) — always pass it (`20m` normal, `60m` broad exploration, reviews, writing). Since 1.5.0, on expiry the run exits 3 with `"status":"ERROR"`, `"error":"print timeout after 5s with the turn still in progress; the response is partial"`, `"finished_reason":"print_timeout"`, empty `response`, and `AGY_ERROR` (`"status":"DEADLINE_EXCEEDED"`, `"reason":"print_timeout"`, `"retryable":false`) on stderr (re-verified on 1.5.13 (2026-11-20)). |
| `--log-file <path>` | Override the CLI log path (logs default to `~/.gemini/antigravity-cli/log/`). |
| `--settings <json\|path>` | Settings for this session only, never saved: a JSON object of `settings.json` keys, inline or as a file path (seen in 1.4.12 `--help`). Not used by the skill; must not be used in place of `--dangerously-skip-permissions` (user decision, 2026-11-16). |

## JSON output

`--output-format json` prints **one JSON object on stdout**; diagnostics go to stderr. Verified shapes (1.4.0 unless marked):

```text
success:  {"conversation_id":"<uuid>","status":"SUCCESS","response":"正常\n","duration_seconds":6.6,"num_turns":1,"usage":{...}}           exit 0  (re-verified on 1.5.13 (2026-11-20))
timeout:  {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"print timeout after 5s with the turn still in progress; the response is partial","duration_seconds":0,"num_turns":1,"usage":{...},"finished_reason":"print_timeout"}   exit 3  (since 1.5.0; re-verified on 1.5.13 (2026-11-20))
          stderr: [agy] print timeout after 5s with turn in progress; returning partial output
                  error: print timeout after 5s with the turn still in progress; the response is partial
                  AGY_ERROR: {"short_error":"print timeout after 5s with the turn still in progress; the response is partial","status":"DEADLINE_EXCEEDED","retryable":false,"reason":"print_timeout"}
denied:   {"conversation_id":"<uuid>","status":"SUCCESS","response":"","denied_actions":[{"action":"write_file",...}],...}               exit 0
          stderr: jetski: no output produced — a tool required the "write_file" permission ...
quota:    {"conversation_id":"<uuid>","status":"ERROR","response":"","error":"Your AI credits balance is too low to continue.","finished_reason":"error",...}   exit 3  (1.4.12; not re-tested on 1.5.3)
          stderr: error: Your AI credits balance is too low to continue.
                  AGY_ERROR: {"short_error":"RESOURCE_EXHAUSTED (code 429) ...","status":"RESOURCE_EXHAUSTED","error_code":429,"retryable":true,...}
bad model/effort: {"conversation_id":"","status":"ERROR","response":"","error":"invalid model selection (--model \"Gemini 4 Argon (High)\" --effort \"high\"): --effort is not supported for model \"Gemini 4 Argon (High)\"","duration_seconds":0,"num_turns":0,"usage":{...},"finished_reason":"error"}   exit 1  (bad model and --effort re-verified on 1.5.13 (2026-11-20))
          stderr: error: invalid model selection ... (+ available list for a bad model)
```

- The `denied` example is historical (older versions / non-Auto mode); 1.5.9 Auto shell no longer triggered it without the flag. Every call in this configuration must include `--dangerously-skip-permissions` (user decision, 2026-11-16).
- `conversation_id` is the id to store for resume (replaces reading the cache file).
- A resumed call (`--conversation <uuid>`) returned the same `conversation_id`, advanced `num_turns` from 1 to 2 and recalled the previous turn on 1.5.13 (2026-11-20).
- `finished_reason` (since 1.4.11) appears only when a turn ended early: `print_timeout`, `interrupted` or `error`. It is omitted on a normal finish (re-verified on 1.5.13 (2026-11-20)).
- Success requires exit 0, `status == "SUCCESS"`, and no `denied_actions` or `finished_reason`. For text, also require a non-empty `response`. For images, verify the saved file as described under Gotchas. Since both `--print-timeout` expiry and quota exhaustion return exit 3 with `status == "ERROR"`, distinguish them by `finished_reason` (`print_timeout` vs `error`), `error` text, and `AGY_ERROR.status` (`DEADLINE_EXCEEDED` vs `RESOURCE_EXHAUSTED` / 429).

## Subcommands

- `agy models` — list available models, one `model id<TAB>display name` per row (re-verified on 1.5.16 (2026-11-24)).
- `agy --dangerously-skip-permissions -p "/usage"` — print remaining quota per pool with reset times (UTC when piped). On 1.5.16 (2026-11-24), it returned four rows, with weekly and five-hour limits for `Gemini Models` and `Claude and GPT models`. The weekly-only `Gemini 4 Argon` row observed on 1.5.13 (2026-11-20) is no longer listed. On 1.5.16, Gemini 4 Argon shares the `Gemini Models` pool with Flash, Hydrogen and Carbon (user confirmation, 2026-11-24). Hydrogen shares Flash’s `Gemini Models` pool, confirmed by before/after usage checks on 1.5.9 (2026-11-16). Takes a few seconds. `/usage` is a built-in query with no model inference (1.5.13 JSON showed `num_turns: 0` and zero tokens in every usage field). It does not count against the model-call budget. The permission flag is still required.
- `mcp` — manage MCP servers (add, remove, list, enable, disable).
- `agents` (alias `agent`) — list available agents.
- `mic-serve` — serve this machine's microphone to a CLI on another host (1.4.0; not used).
- `remote-control` — manage the remote-control daemon.
- `plugin <cmd>` (alias `plugins`): `list`, `import [gemini|claude]`, `install <target>` (e.g. `name@marketplace`), `uninstall <name>`, `enable <name>`, `disable <name>`, `validate [path]`, `link <mp> <target>`, `help`. (Importing the `nanobanana` extension is optional — agy generates images natively; see Images below.)
- `install` — configure PATH / shell aliases (`--dir`, `--skip-aliases`, `--skip-path`).
- `agy changelog` — release notes.
- `update` — update the CLI.
- `help [subcommand]` — help (subcommands also take `-h`/`--help`).

## Models

`agy models` (Google-account login; re-verified on 1.5.16 (2026-11-24)). Each row is `model id<TAB>display name`; summarized display names below:

```
Gemini 4 Neon (High) | (XHigh) | (Medium) | (Low)
Gemini 4 Carbon (Medium) | (High) | (Low)
Gemini 4 Argon (High) | (Medium) | (Low)     ← shares the Gemini Models pool on 1.5.16 (user confirmation, 2026-11-24)
Gemini 4 Hydrogen (Low) | (Medium) | (High) | (XHigh)
Orchestrator (Neon)                       ← id gemini-pro-orchestrator-neon
Orchestrator (Carbon)                     ← id gemini-pro-orchestrator
Orchestrator (Argon)                      ← id gemini-pro-orchestrator-argon
Gemini 3.8 Flash (High) | (Medium) | (Low)   ← writing and images
Claude Opus 5.5 (High) | (Medium) | (Low)
Claude Sonnet 5.5 (High) | (Medium) | (Low)
GPT-OSS 120B (Medium)
```

- **Hydrogen:** visible on this Google-account login as of 1.5.9; `Gemini 4 Hydrogen (High)` passed a smoke test (exit 0, `SUCCESS`, response `正常`, ~3.7 s). In a small blind review of four real pre-fix Python files with one known defect each (agy 1.5.9, 2026-11-16), Hydrogen (High) found one defect and partially identified one in ~182 s versus Argon (High)’s three in ~454 s; both missed a TLS certificate-validation defect and used similar tokens (~78k total). Hydrogen shares Flash’s `Gemini Models` pool and remains **excluded from routing**, defaults and fallbacks because it found fewer defects than Argon in this sample and would consume writing quota; further evaluation is the user’s decision. The 1.5.8 release notes name API-key/ADC access; this Google-login observation takes precedence here.
- **Neon:** 1.5.13 added four Neon tiers and Orchestrator (Neon) to the list. On 2026-11-20 all 16 non-Claude/GPT entries returned `正常` with exit 0, `SUCCESS`, no `denied_actions` and no `finished_reason`. Each smoke call took ~2–10 s by agy’s timer and used ~13k tokens, mostly agy’s system prompt.
  - **Quota:** On 1.5.13, `/usage` had no separate Neon row. All three pools showed the same percentages before and after one Neon (High) call. At 1% display precision, the pool is unconfirmed.
  - **Blind review:** five real pre-fix files from one repository (two Python, two JS, one Shell), each with one known defect. A hit earned 1 point and a partial hit 0.5. Hydrogen (XHigh) scored 3.5/5 (~295 s, ~86k tokens), Neon (High) 3/5 (~375 s, ~69k), Argon (High) 2.5/5 (~358 s, ~59k) and Neon (XHigh) 2.5/5 (~629 s, ~99k). All four found the same two defects and missed the same one. Treat gaps of 0.5–1 point as noise in this small, single-repository sample. Compared with Neon (High), Neon (XHigh) took ~1.7× as long and used ~1.4× as many tokens for a lower score.
  - **Writing:** on the same 400-character explanation, neither Neon (High) nor Flash (High) fabricated details. Neon’s paragraphs were slightly better structured, but the tight prompt left too little room to distinguish the models or justify changing the writing model. Like Hydrogen, Neon remains **excluded from routing**, defaults and fallbacks. Further evaluation is the user’s decision.
- **Carbon:** On 1.5.16 (2026-11-24), `Gemini 4 Carbon (High)` passed a smoke test (exit 0, `SUCCESS`, response `正常`, no `denied_actions` or `finished_reason`, ~5.2 s). At 1% display precision, Flash’s `Gemini Models` pool dropped from 83% to 82% weekly and 30% to 29% over five hours, while the Claude/GPT pool was unchanged. Carbon draws from Flash’s writing quota. Carbon and Orchestrator (Carbon) are **excluded from routing**, defaults and fallbacks. The evidence is limited to the Carbon (High) smoke test. Further evaluation is the user’s decision.
- **Default choice:** always pass `--model` explicitly — `"Gemini 4 Argon (High)"` for read-only work, `"Gemini 3.8 Flash (High)"` for writing and images; on quota errors follow the role-based fallback in global CLAUDE.md (the only authority for fallbacks). Only these two Gemini models are used; `Claude Opus 5.5 (High)`, `Claude Sonnet 5.5 (High)` and GPT-OSS are listed but not used (the Claude/GPT pool's quota is too small), and agy is not used for code changes. `Claude Opus/Sonnet 4.6 (Thinking)` no longer exist (2026-10-03). The built-in default (no `--model`) is not pinned and has drifted across releases. Older Gemini Flash versions from earlier docs no longer exist.
- `--model` takes the **verbatim display string**, e.g. `--model "Gemini 4 Argon (High)"`. The `(Low/Medium/High)` suffix is a **reasoning-effort tier**, not a separate model.
- **An unknown `--model` fails hard** — `error: invalid model selection (--model "Gemini 9 Fake (High)" --effort ""): model Gemini 9 Fake (High) is not recognized as a known model or custom model in settings`, exit 1, followed by the `Available models` list (re-verified on 1.5.13 (2026-11-20)). Only pass strings that appear in `agy models`.
- Selecting a **Claude** or **GPT-OSS** model routes to that provider **through Google's Antigravity backend** (Google-brokered, billed against Google's quota/credits — not your own Anthropic/OpenAI key).

## Conversations & resume (the id mechanism)

- You can't set an id (no `--session-id` like gemini). With `--output-format json` the id is returned as `conversation_id`; in text mode it isn't printed.
- State lives under **`~/.gemini/antigravity-cli/`**:
  - `conversations/<UUID>.db` — one SQLite DB per conversation. Ids are standard UUIDs.
  - **`cache/last_conversations.json`** — maps each **workspace dir → its latest conversation UUID**. Rewritten after every `-p` run for that cwd. Keys are real paths (e.g. `/private/tmp/…`). Not a source of identity for a specific call: any `-p` run from that cwd (in any session) overwrites it. Take the id from the call's JSON `conversation_id`; if it is missing, record UNKNOWN.
  - `history.jsonl` — prompt log (no ids).
- **Resume by id:** `agy --dangerously-skip-permissions --conversation <uuid> -p "<prompt>"`. On 1.5.13 (2026-11-20), Flash (High) and Argon (High) both recovered context in the original directory and in a different directory, re-verifying cwd independence. Codex recorded a cross-process context recovery failure on 1.5.9 that did not recur in these 1.5.13 tests. Verify the resumed result against the task.
- **`-c` / `--continue`** resumes the latest conversation. From the matching workspace it's instant; from a different/empty dir it resorts to agentically grepping transcripts to find one — slow and side-effecty. Prefer `--conversation <uuid>` for topic routing.

## Safety / permissions

- **No usable read-only mode.** Historical 1.4.0 checks: allowlisted reads ran without the permission flag, but `write_file` was auto-denied (exit 0, no answer). This is not a universal current rule. Since 1.5.7, sessions without a saved Agent Mode, including headless `-p`, default to Auto where available (Default elsewhere). `"agentMode": ""` in `settings.json` restores Default; Tool Permission `strict` takes precedence over Auto and still requires approval for edits. On this machine (no saved `agentMode`, terminal sandbox disabled), Argon (High) ran `date +%Y` and `cat probe.txt` without `--dangerously-skip-permissions`: exit 0, `SUCCESS`, non-empty `response`, no `denied_actions` (re-verified on 1.5.9 (2026-11-16)); the same call with the flag also succeeded. With the flag on 1.5.13 (2026-11-20), Auto shell ran `ls`, `wc -l` and file reads successfully and left the workspace unchanged. The older auto-denial symptom (exit 0, empty response, `denied_actions`) no longer reproduced for shell in Auto. **Every Claude/Commander-initiated agy call must include `--dangerously-skip-permissions`**, including smoke tests, `/usage`, resumed conversations and image generation (user decision, 2026-11-16); this also applies when executing abbreviated command references in this document. Do not investigate or test behavior without the flag or seek alternatives via restricted allow-lists, `--settings` or deny rules. It is a headless compatibility method, **not isolation**; since 1.5.2 system-blocklisted commands and explicit deny rules still apply, while headless out-of-workspace reads/writes no longer hang on approval. Do not rely on deny rules to protect secret files such as `.env`. The user's own independent AGY sessions are unaffected.
- `--mode plan` is not read-only either: on 1.4.0 with `--dangerously-skip-permissions` it wrote a plan artifact under `~/.gemini/antigravity-cli/brain/<conversation_id>/` instead of the requested workspace file (1.3.2 wrote the workspace file).
- `--sandbox` (verified on an older build) gates network / full-disk / out-of-workspace operations behind confirmation, but **did not block a local `/tmp` write** — treat it as "restrict escape", not "read-only".
- For read-only intent, constrain via the **prompt** ("analyze and answer only; don't modify files or run shell; do not use run_workflow, swarm or any parallel subagents") and/or scope the workspace (`--add-dir` / cwd). `/swarm` is a quota-heavy preview since 1.5.5; `run_workflow` is available to everyone since 1.5.9 and can fan out to parallel subagents that consume quota.

## Gotchas

- **First call may be slower** (historical 1.5.3 cold call ~12 s, warm calls 5–20 s). Release notes: 1.5.5 fixed headless `-p` sometimes not exiting after printing a result; shutdown completes within 30 s for that case. Since 1.5.8, stale network connections retry on a fresh connection, and slow responses no longer time out at 60 s when admin settings configure a proxy or custom CA. `--print-timeout` defaults to no limit (since 1.5.0 it waits indefinitely for background tasks; last re-verified on 1.5.3 (2026-11-08)) — always set it.
- **Non-TTY stdout drop** (old builds) ([antigravity-cli#76](https://github.com/google-antigravity/antigravity-cli/issues/76)): on some builds (v1.0.0 / Windows), print mode (`-p`) can exit 0 with **empty** piped stdout. Not reproduced on macOS 1.0.10, but guard for it: empty output + exit 0 → retry once.
- **Shared `~/.gemini/` lineage** — agy reuses gemini-cli's config/auth dir (`oauth_creds.json`, `settings.json`, plugins). Per-model settings live in `~/.gemini/antigravity-cli/settings.json` and interactive use can mutate them under a script.
- **Images**: agy generates images on the Google subscription — no API key or extension. Since 1.2.16 requests go to a built-in `image-generator` subagent (Nano Banana Pro). On 1.5.13 (2026-11-20), Flash (High) generated a PNG illustration at the absolute path requested in the `-p` prompt using the image model. Very simple shapes may be drawn with code instead of the image model. Verify that the target file exists, check its format, and open it to inspect the content. JSON `response` may contain only progress text, so verify the file even when the response omits its path. (The `nanobanana` gemini-cli extension on disk is unregistered and unnecessary — an API-key path you don't need.)
- **Auth** = free Google account OAuth ("oauth-personal"); the sanctioned successor to gemini-cli's deprecated individual tier. No API key. `/logout` (interactive) signs out.
- **Quotas** — on 1.5.16, `agy --dangerously-skip-permissions -p "/usage"` shows weekly and five-hour limits for `Gemini Models` (Argon, Flash, Hydrogen and Carbon, user confirmation on 2026-11-24) and `Claude and GPT models`. If `Gemini Models` is exhausted, both Argon and Flash are unavailable. Under the routing table in global CLAUDE.md, read-only work and technical docs return to Codex, and prose writing waits for quota to reset. Don't step down to other agy models.

## Docs

- Antigravity — https://antigravity.google
- CLI repo (issues / README; proprietary) — https://github.com/google-antigravity/antigravity-cli
- Gemini-CLI → Antigravity migration — https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
