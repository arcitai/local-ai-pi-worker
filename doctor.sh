#!/usr/bin/env bash
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
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
check_file() { [[ -e "$1" ]] && pass "$2" || fail "$2 ($1 missing)"; }

check_file "$config_file" 'machine config'
check_file "$runtime_file" 'resolved runtime metadata'
check_file "$bin_dir/pi-worker" 'worker CLI'
check_file "$pi_dir/settings.json" 'dedicated Pi settings'
check_file "$pi_dir/models.json" 'OpenCodex Pi model catalog'
check_file "$skill_dir/SKILL.md" 'portable orchestration skill'

if [[ -r "$config_file" ]]; then
  # shellcheck disable=SC1090
  source "$config_file"
  if [[ -r "$runtime_file" ]]; then
    # shellcheck disable=SC1090
    source "$runtime_file"
  fi
  if jq -e --arg id "$LOCAL_AI_PROVIDER_ID/$LOCAL_AI_MODEL_ID" --argjson context "${LOCAL_AI_RESOLVED_CONTEXT_WINDOW:-0}" --argjson output "$LOCAL_AI_MAX_OUTPUT_TOKENS" '
      any(.providers.opencodex.models[]?; .id == $id and .contextWindow == $context and .maxTokens == $output and .input == ["text"])
    ' "$pi_dir/models.json" >/dev/null 2>&1; then
    pass 'Pi context inherited from runtime and native modality preserved'
  else
    fail 'Pi context inheritance or native modality'
  fi

  runtime_key="${LOCAL_AI_API_KEY:-}"
  if [[ -z "$runtime_key" && -r "$HOME/.opencodex/config.json" ]]; then
    runtime_key="$(jq -r --arg id "$LOCAL_AI_PROVIDER_ID" '.providers[$id].apiKey // empty' "$HOME/.opencodex/config.json")"
  fi
  runtime_models="$(mktemp)"
  curl_args=(--fail --silent --show-error --connect-timeout 3 --max-time 10)
  if [[ -n "$runtime_key" ]]; then
    curl_args+=(-H "Authorization: Bearer $runtime_key")
  fi
  if curl "${curl_args[@]}" "${LOCAL_AI_BASE_URL%/}/models" > "$runtime_models" 2>/dev/null; then
    runtime_context="$(jq -r --arg id "$LOCAL_AI_MODEL_ID" '
      [(.data[]?, .models[]?)
       | select((.id // .model // .name) == $id)
       | (.context_window // .contextWindow // .context_length // .context_size
          // .max_model_len // .max_context_length
          // .metadata.limits.max_context_length // .metadata.context_length
          // .meta.n_ctx // .meta.n_ctx_train)]
      | map(select(. != null)) | first // empty
    ' "$runtime_models")"
  else
    runtime_context=""
  fi
  rm -f -- "$runtime_models"

  if [[ -n "${LOCAL_AI_CONTEXT_WINDOW_OVERRIDE:-}" ]]; then
    pass 'explicit context override configured'
  elif [[ "$runtime_context" =~ ^[0-9]+$ ]] && [[ "$runtime_context" == "${LOCAL_AI_RESOLVED_CONTEXT_WINDOW:-}" ]]; then
    pass "runtime is the context source (${runtime_context} tokens)"
  else
    fail 'runtime context differs from the last synced Pi catalog; run pi-worker --sync'
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
  pass 'Codex image UI via text-description vision sidecar'
else
  fail 'Codex image UI via text-description vision sidecar'
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
