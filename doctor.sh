#!/usr/bin/env bash
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
bin_dir="${PI_WORKER_BIN_DIR:-$HOME/.local/bin}"
data_dir="$data_home/local-ai-pi-worker"
config_file="$config_home/local-ai-pi-worker/config.env"
runtime_file="$state_home/local-ai-pi-worker/runtime.env"
pi_dir="$data_dir/pi-agent"
skill_root="$HOME/.agents/skills"
if [[ -r "$config_file" ]]; then
  # shellcheck disable=SC1090
  source "$config_file"
  skill_root="${PI_WORKER_SKILL_ROOT:-$skill_root}"
fi
skill_dir="$skill_root/orchestrate-pi-worker"
failures=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; failures=$((failures + 1)); }
check_file() {
  if [[ -e "$1" ]]; then
    pass "$2"
  else
    fail "$2 ($1 missing)"
  fi
}

check_file "$config_file" 'machine config'
check_file "$runtime_file" 'resolved runtime metadata'
check_file "$bin_dir/pi-worker" 'worker CLI'
check_file "$bin_dir/pi-worker-sync" 'runtime catalog synchronizer'
check_file "$pi_dir/settings.json" 'dedicated Pi settings'
check_file "$pi_dir/models.json" 'dedicated Pi model catalog'
check_file "$skill_dir/SKILL.md" 'portable orchestration skill'

if [[ -x "$bin_dir/pi-worker-sync" ]] && "$bin_dir/pi-worker-sync" --ensure --quiet; then
  pass 'runtime and worker catalog synchronized'
else
  fail 'runtime and worker catalog synchronization'
fi

if [[ -r "$config_file" && -r "$runtime_file" ]]; then
  # shellcheck disable=SC1090
  source "$config_file"
  # shellcheck disable=SC1090
  source "$runtime_file"
  if jq -e \
      --arg provider "$LOCAL_AI_PROVIDER_ID" \
      --arg id "$LOCAL_AI_MODEL_ID" \
      --arg base_url "$LOCAL_AI_BASE_URL" \
      --argjson context "${LOCAL_AI_RESOLVED_CONTEXT_WINDOW:-0}" \
      --argjson output "$LOCAL_AI_MAX_OUTPUT_TOKENS" '
      .providers[$provider].baseUrl == $base_url
      and any(.providers[$provider].models[]?;
        .id == $id
        and .contextWindow == $context
        and .maxTokens == $output
        and .input == ["text"])
    ' "$pi_dir/models.json" >/dev/null 2>&1; then
    pass "direct local Pi model (${LOCAL_AI_RESOLVED_CONTEXT_WINDOW} tokens, text-only)"
  else
    fail 'direct local Pi model metadata'
  fi

  if jq -e \
      --arg provider "$LOCAL_AI_PROVIDER_ID" \
      --arg model "$LOCAL_AI_MODEL_ID" '
      .defaultProvider == $provider
      and .defaultModel == $model
      and (.enabledModels | index($provider + "/" + $model)) != null
    ' "$pi_dir/settings.json" >/dev/null 2>&1; then
    pass 'local model is the dedicated worker default'
  else
    fail 'dedicated worker defaults'
  fi
fi

web_config="$HOME/.config/pi-web-search/config.json"
if jq -e '
    .firecrawl.keyless == false
    and .searchOrder[0] == "monid"
    and .fetchOrder[0] == "monid"
    and (.fetchOrder | index("direct")) != null
  ' "$web_config" >/dev/null 2>&1; then
  pass 'web policy (Monid first, direct fetch fallback, Firecrawl off)'
else
  fail 'web policy (Monid first, direct fetch fallback, Firecrawl off)'
fi

pi_auth="${PI_GLOBAL_AUTH_FILE:-$HOME/.pi/agent/auth.json}"
if [[ ! -f "$pi_auth" ]] || ! jq -e 'has("websearch-firecrawl")' "$pi_auth" >/dev/null 2>&1; then
  pass 'no stored Firecrawl credential'
else
  fail 'stored Firecrawl credential is still active'
fi

if command -v pi >/dev/null \
  && PI_CODING_AGENT_DIR="$pi_dir" PI_TELEMETRY=0 \
    pi --offline --list-models "${LOCAL_AI_PROVIDER_ID:-local-ai}" >/dev/null 2>&1; then
  pass 'Pi can load the dedicated local provider'
else
  fail 'Pi dedicated provider catalog'
fi

if [[ "$failures" -gt 0 ]]; then
  printf '%s check(s) failed.\n' "$failures" >&2
  exit 1
fi
printf '%s\n' 'All checks passed.'
