# Evals for the `agy` skill

Developer tooling — not loaded into Claude's context at runtime. Run it after
editing `SKILL.md` / `references/flags.md` or upgrading agy.

## Command-parse lint

`lint_agy_commands.py` extracts every `agy …` command from the fenced code
blocks in `SKILL.md` and `references/flags.md` and checks its subcommands and
flags against the installed CLI's `--help`. Offline, ~1 s.

```bash
conda run -n py312 python evals/lint_agy_commands.py --skill .            # from the skill dir
conda run -n py312 python evals/lint_agy_commands.py --skill . --verbose  # list every command
```

Exit codes: `0` clean · `1` drift · `2` `agy` not on PATH.

It checks flag/subcommand **names** only. It can't see model strings, JSON
output shape, permission behavior, quota errors or resume — those are the smoke
tests below. If agy adds a value-taking flag or subcommand, add it to
`VALUE_FLAGS` / `SUBCOMMANDS` in the script.

## After an agy upgrade — checklist

1. `agy --version`, `agy --help`, `agy models`, `agy changelog | head -60`; update
   the version stamp, flags, models and verified notes in `references/flags.md`.
2. Run the lint.
3. Run the smoke tests (online, use Gemini quota; run from an empty scratch dir).

## Smoke tests (manual)

Use Gemini 4 Argon (High); repeat test 1 with Gemini 3.8 Flash (High), the writing/image model. Each warm call takes seconds; cold start 2–3 min.

```bash
M="Gemini 4 Argon (High)"
# 1. JSON shape + success
agy --dangerously-skip-permissions --model "$M" --output-format json --print-timeout 5m -p "只回复两个字：正常" > out.json 2> err.txt; echo "exit=$?"; cat out.json
# 2. resume by id: same conversation_id back, num_turns incremented, recalls "正常"
agy --dangerously-skip-permissions --conversation "$(jq -r .conversation_id out.json)" --model "$M" --output-format json --print-timeout 5m -p "我上一条让你回复什么？" | jq '{conversation_id,num_turns,response}'
# 3. permission guard: without the flag a write is denied -> empty response + denied_actions (exit 0)
agy --model "$M" --output-format json --print-timeout 5m -p "用 write_file 创建 out.txt 内容 abc" 2>/dev/null | jq '{status,response,denied_actions}'
# 4. quota
agy -p "/usage"
```

Expected results and the error shapes (quota exit 3, bad model exit 1) are in
`references/flags.md` → "JSON output". If any changes, update `SKILL.md`
("Reading the result", "Error handling") to match.
