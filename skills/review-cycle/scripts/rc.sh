#!/usr/bin/env bash
# review-cycle 白名单入口：只开放只读审查与状态/结果查询，不开放 cancel/stop/task/run/--write。
# 插件路径每次从 ~/.claude/plugins/installed_plugins.json 解析，插件升级后无需改本文件。
set -euo pipefail

# 默认审查模型与全局 CLAUDE.md 路由表一致；改路由表时同步这两行。
CODEX_REVIEW_MODEL="${RC_CODEX_MODEL:-gpt-6.1-sol}"
GROK_REVIEW_MODEL="${RC_GROK_MODEL:-grok-4.6}"
GROK_REVIEW_EFFORT="${RC_GROK_EFFORT:-high}"

die() { echo "rc: $*" >&2; exit 2; }

plugin_root() {
  # $1 = installed_plugins.json 里的 key，如 codex@openai-codex
  node -e '
    const fs = require("fs"), path = require("path"), os = require("os");
    const key = process.argv[1];
    let root = "";
    try {
      const d = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude/plugins/installed_plugins.json"), "utf8"));
      const e = (d.plugins || d)[key];
      const entry = Array.isArray(e) ? e[0] : e;
      if (entry && entry.installPath && fs.existsSync(entry.installPath)) root = entry.installPath;
    } catch (_) {}
    process.stdout.write(root);
  ' "$1"
}

CODEX_ROOT="$(plugin_root codex@openai-codex)"
GROK_ROOT="$(plugin_root grok-build@xai-grok-build)"
CC="${CODEX_ROOT:+$CODEX_ROOT/scripts/codex-companion.mjs}"
GB="${GROK_ROOT:+$GROK_ROOT/scripts/grok-bridge.mjs}"

need_cc() { [ -n "$CC" ] && [ -f "$CC" ] || die "找不到 codex 插件（installed_plugins.json 无 codex@openai-codex）"; }
need_gb() { [ -n "$GB" ] && [ -f "$GB" ] || die "找不到 grok-build 插件（installed_plugins.json 无 grok-build@xai-grok-build）"; }

has_flag() { local f="$1"; shift; for a in "$@"; do [ "$a" = "$f" ] && return 0; done; return 1; }

# 审查只读：拒绝任何写权限或续线程参数。
for a in "$@"; do
  case "$a" in
    --write|--resume|--resume-last|--always-approve) die "参数 $a 不在 review-cycle 白名单内（审查必须只读）";;
  esac
done

# --wait-min N → 状态查询的有界等待（默认 25 分钟）
wait_args() {
  local mins="$1"
  echo "--wait --timeout-ms $(( mins * 60 * 1000 ))"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  paths)
    echo "codex: ${CC:-<missing>}"
    echo "grok:  ${GB:-<missing>}"
    echo "defaults: codex --model $CODEX_REVIEW_MODEL | grok --model $GROK_REVIEW_MODEL --effort $GROK_REVIEW_EFFORT"
    ;;
  codex-review|codex-adv)
    need_cc
    sub=review; [ "$cmd" = codex-adv ] && sub=adversarial-review
    has_flag --effort "$@" && die "codex review 不接受 --effort（effort 来自 ~/.codex/config.toml）"
    extra=(); has_flag --model "$@" || has_flag -m "$@" || extra=(--model "$CODEX_REVIEW_MODEL")
    # companion 的 review 永远前台执行；调用方用 Bash run_in_background 获得后台效果。
    exec node "$CC" "$sub" ${extra[@]+"${extra[@]}"} "$@"
    ;;
  codex-status)
    need_cc
    id="${1:-}"; if [ -z "$id" ] || [ "$id" = --all ]; then exec node "$CC" status --all --json; fi; shift
    w=""; if [ "${1:-}" = "--wait-min" ]; then w="$(wait_args "${2:-25}")"; fi
    # shellcheck disable=SC2086
    exec node "$CC" status "$id" --json $w
    ;;
  codex-result)
    need_cc
    [ -n "${1:-}" ] || die "codex-result 需要 job id"
    exec node "$CC" result "$1"
    ;;
  grok-review|grok-critique)
    need_gb
    sub=review; [ "$cmd" = grok-critique ] && sub=critique
    extra=(--background)
    has_flag --model "$@" || has_flag -m "$@" || extra+=(--model "$GROK_REVIEW_MODEL")
    has_flag --effort "$@" || extra+=(--effort "$GROK_REVIEW_EFFORT")
    exec node "$GB" "$sub" ${extra[@]+"${extra[@]}"} "$@"
    ;;
  grok-runs)
    need_gb
    id="${1:-}"; if [ -z "$id" ] || [ "$id" = --all ]; then exec node "$GB" runs --all --json; fi; shift
    w=""; if [ "${1:-}" = "--wait-min" ]; then w="$(wait_args "${2:-25}")"; fi
    # shellcheck disable=SC2086
    exec node "$GB" runs "$id" --json $w
    ;;
  grok-show)
    need_gb
    [ -n "${1:-}" ] || die "grok-show 需要 run id"
    exec node "$GB" show "$1"
    ;;
  cancel|stop|codex-cancel|grok-stop|task|run)
    die "'$cmd' 不开放给自动编排：终止任务、写入型任务需用户明确要求后用插件命令或 runbook 手动执行"
    ;;
  *)
    die "用法: rc.sh paths | codex-review|codex-adv [--base <ref>] [--scope ...] [focus] | codex-status [<id> [--wait-min N]] | codex-result <id> | grok-review|grok-critique [--base <ref>] [--scope ...] [focus] | grok-runs [<id> [--wait-min N]] | grok-show <id>"
    ;;
esac
