#!/usr/bin/env bash
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
bin_dir="${PI_WORKER_BIN_DIR:-$HOME/.local/bin}"
data_dir="$data_home/local-ai-pi-worker"
config_file="$config_home/local-ai-pi-worker/config.env"
pi_dir="$data_dir/pi-agent"
failures=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; failures=$((failures + 1)); }
check_file() { [[ -e "$1" ]] && pass "$2" || fail "$2 ($1 missing)"; }

check_file "$config_file" 'machine config'
check_file "$bin_dir/pi-worker" 'worker CLI'
check_file "$pi_dir/settings.json" 'dedicated Pi settings'
check_file "$pi_dir/models.json" 'OpenCodex Pi model catalog'
check_file "$codex_home/skills/orchestrate-pi-worker/SKILL.md" 'Codex orchestration skill'

if [[ -r "$config_file" ]]; then
  # shellcheck disable=SC1090
  source "$config_file"
  if jq -e --arg id "local-ai/$LOCAL_AI_MODEL_ID" --argjson context "$LOCAL_AI_CONTEXT_WINDOW" --argjson output "$LOCAL_AI_MAX_OUTPUT_TOKENS" '
      any(.providers.opencodex.models[]?; .id == $id and .contextWindow == $context and .maxTokens == $output and .input == ["text"])
    ' "$pi_dir/models.json" >/dev/null 2>&1; then
    pass 'local model caps and modality'
  else
    fail 'local model caps and modality'
  fi
fi

web_config="$HOME/.config/pi-web-search/config.json"
if jq -e '.firecrawl.keyless == false and .searchOrder[0] == "monid" and .searchOrder[1] == "openai"' "$web_config" >/dev/null 2>&1; then
  pass 'web policy (Monid → OpenCodex, Firecrawl off)'
else
  fail 'web policy (Monid → OpenCodex, Firecrawl off)'
fi

if [[ ! -f "$HOME/.pi/agent/auth.json" ]] || ! jq -e 'has("websearch-firecrawl")' "$HOME/.pi/agent/auth.json" >/dev/null 2>&1; then
  pass 'no stored Firecrawl credential'
else
  fail 'stored Firecrawl credential is still active'
fi

if command -v ocx >/dev/null && ocx health --json | jq -e '.ok == true or .healthy == true' >/dev/null 2>&1; then
  pass 'OpenCodex proxy health'
else
  fail 'OpenCodex proxy health'
fi

if jq -e '.webSearchSidecar.enabled == true and .webSearchSidecar.backend == "openai" and .webSearchSidecar.reasoning == "low" and .visionSidecar.enabled == true and .visionSidecar.backend == "openai"' "$HOME/.opencodex/config.json" >/dev/null 2>&1; then
  pass 'Codex web-search and vision sidecars'
else
  fail 'Codex web-search and vision sidecars'
fi

if jq -e --arg id "local-ai/${LOCAL_AI_MODEL_ID:-qwen3.8-27b-local}" '
    any(.models[]?; .slug == $id and (.input_modalities | index("image")) != null)
  ' "$codex_home/opencodex-catalog.json" >/dev/null 2>&1; then
  pass 'Codex image UI via vision sidecar'
else
  fail 'Codex image UI via vision sidecar'
fi

if systemctl --user is-enabled opencodex-proxy.service >/dev/null 2>&1 && systemctl --user is-active opencodex-proxy.service >/dev/null 2>&1; then
  pass 'OpenCodex boot service'
else
  fail 'OpenCodex boot service'
fi

if [[ "$failures" -gt 0 ]]; then
  printf '%s check(s) failed.\n' "$failures" >&2
  exit 1
fi
printf '%s\n' 'All checks passed.'
