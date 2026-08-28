#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
skip_packages=0
skip_opencodex=0

usage() {
  printf '%s\n' \
    'Usage: ./install.sh [--skip-packages] [--skip-opencodex]' \
    '' \
    '  --skip-packages   Do not install/update the pinned ocx and pi CLIs' \
    '  --skip-opencodex  Do not change OpenCodex config or its user service'
}

while (($#)); do
  case "$1" in
    --skip-packages) skip_packages=1 ;;
    --skip-opencodex) skip_opencodex=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'install.sh: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

for command_name in bash jq curl install mktemp; do
  command -v "$command_name" >/dev/null || {
    printf 'install.sh: missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
bin_dir="${PI_WORKER_BIN_DIR:-$HOME/.local/bin}"
data_dir="$data_home/local-ai-pi-worker"
config_dir="$config_home/local-ai-pi-worker"
state_dir="$state_home/local-ai-pi-worker"
backup_dir="$state_dir/original"
pi_dir="$data_dir/pi-agent"
config_file="$config_dir/config.env"
opencodex_config="${OPENCODEX_CONFIG_PATH:-$HOME/.opencodex/config.json}"
# pi-web-search 0.4.0 intentionally uses this fixed upstream path rather than
# XDG_CONFIG_HOME. Keep the installer aligned with the extension it pins.
web_config="$HOME/.config/pi-web-search/config.json"
pi_auth="${PI_GLOBAL_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

mkdir -p "$config_dir" "$backup_dir" "$data_dir" "$bin_dir" "$codex_home/skills"
if [[ ! -e "$config_file" ]]; then
  install -m 600 "$repo_dir/config/defaults.env" "$config_file"
fi

# shellcheck disable=SC1090
source "$repo_dir/config/defaults.env"
# shellcheck disable=SC1090
source "$config_file"

for integer_name in OPENCODEX_PORT LOCAL_AI_CONTEXT_WINDOW LOCAL_AI_MAX_OUTPUT_TOKENS; do
  value="${!integer_name}"
  [[ "$value" =~ ^[0-9]+$ ]] || {
    printf 'install.sh: %s must be a positive integer\n' "$integer_name" >&2
    exit 1
  }
done

if ((LOCAL_AI_MAX_OUTPUT_TOKENS >= LOCAL_AI_CONTEXT_WINDOW)); then
  printf 'install.sh: output token cap must be smaller than the context window\n' >&2
  exit 1
fi

backup_once() {
  local source_path="$1"
  local name="$2"
  if [[ -e "$backup_dir/$name" || -e "$backup_dir/$name.absent" ]]; then
    return
  fi
  if [[ -e "$source_path" ]]; then
    cp -a -- "$source_path" "$backup_dir/$name"
  else
    : > "$backup_dir/$name.absent"
  fi
}

install_cli() {
  local command_name="$1"
  local mise_spec="$2"
  local npm_spec="$3"
  if command -v mise >/dev/null; then
    mise use -g "$mise_spec"
  elif command -v npm >/dev/null; then
    npm install --global "$npm_spec"
  elif ! command -v "$command_name" >/dev/null; then
    printf 'install.sh: install mise or npm before installing %s\n' "$command_name" >&2
    exit 1
  fi
}

if ((skip_packages == 0)); then
  install_cli ocx "npm:@bitkyc08/opencodex@$OPENCODEX_VERSION" "@bitkyc08/opencodex@$OPENCODEX_VERSION"
  install_cli pi "pi@$PI_VERSION" "@earendil-works/pi-coding-agent@$PI_VERSION"
fi

command -v pi >/dev/null || { printf 'install.sh: pi is not installed\n' >&2; exit 1; }
if ((skip_opencodex == 0)); then
  command -v ocx >/dev/null || { printf 'install.sh: ocx is not installed\n' >&2; exit 1; }
fi

backup_once "$bin_dir/pi-worker" pi-worker
backup_once "$codex_home/skills/orchestrate-pi-worker" codex-skill
backup_once "$web_config" pi-web-search.json

install -m 755 "$repo_dir/bin/pi-worker" "$bin_dir/pi-worker"
rm -rf -- "$codex_home/skills/orchestrate-pi-worker"
cp -a "$repo_dir/skills/orchestrate-pi-worker" "$codex_home/skills/orchestrate-pi-worker"

mkdir -p "$(dirname -- "$web_config")"
jq \
  --arg base_url "http://127.0.0.1:$OPENCODEX_PORT/v1/responses" \
  --arg model "$PI_WEB_SEARCH_MODEL" \
  '.openai.baseUrl = $base_url | .openai.model = $model | .firecrawl.keyless = false' \
  "$repo_dir/config/pi-web-search.json" > "$web_config.tmp"
install -m 600 "$web_config.tmp" "$web_config"
rm -f -- "$web_config.tmp"

if [[ -f "$pi_auth" ]] && jq -e 'has("websearch-firecrawl")' "$pi_auth" >/dev/null 2>&1; then
  backup_once "$pi_auth" pi-auth.json
  jq 'del(."websearch-firecrawl")' "$pi_auth" > "$pi_auth.tmp"
  install -m 600 "$pi_auth.tmp" "$pi_auth"
  rm -f -- "$pi_auth.tmp"
fi

if ((skip_opencodex == 0)); then
  backup_once "$opencodex_config" opencodex-config.json
  mkdir -p "$(dirname -- "$opencodex_config")"
  base_config="$opencodex_config"
  if [[ ! -f "$opencodex_config" ]]; then
    base_config="$(mktemp)"
    printf '{}\n' > "$base_config"
  fi

  max_input=$((LOCAL_AI_CONTEXT_WINDOW - LOCAL_AI_MAX_OUTPUT_TOKENS))
  compact_limit=$((LOCAL_AI_CONTEXT_WINDOW * 3 / 4))
  existing_api_key="$(jq -r --arg provider_id "$LOCAL_AI_PROVIDER_ID" '.providers[$provider_id].apiKey // empty' "$base_config")"
  runtime_api_key=""
  if [[ -z "${LOCAL_AI_API_KEY:-}" && -z "$existing_api_key" ]] && command -v ps >/dev/null; then
    runtime_api_key="$(ps -ww -eo args= | awk -v wanted_alias="$LOCAL_AI_MODEL_ID" -v wanted_port="${LOCAL_AI_BASE_URL##*:}" '
      /llama-server/ {
        alias_ok = 0; port_ok = 0; key = ""
        sub(/\/.*/, "", wanted_port)
        for (i = 1; i <= NF; i++) {
          if ($i == "--alias" && $(i + 1) == wanted_alias) alias_ok = 1
          if ($i == "--port" && $(i + 1) == wanted_port) port_ok = 1
          if ($i == "--api-key") key = $(i + 1)
        }
        if (alias_ok && port_ok && key != "") { print key; exit }
      }
    ')"
  fi
  local_api_key="${LOCAL_AI_API_KEY:-${existing_api_key:-$runtime_api_key}}"
  cloud_models_json="$(printf '%s' "$PI_WORKER_CLOUD_MODELS" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))')"
  local_provider_json="$(jq -n \
    --arg base_url "$LOCAL_AI_BASE_URL" \
    --arg model "$LOCAL_AI_MODEL_ID" \
    --arg api_key "$local_api_key" \
    --argjson context "$LOCAL_AI_CONTEXT_WINDOW" \
    --argjson input "$max_input" \
    --argjson compact "$compact_limit" \
    --argjson output "$LOCAL_AI_MAX_OUTPUT_TOKENS" \
    '{
      adapter:"openai-chat", baseUrl:$base_url, allowPrivateNetwork:true,
      codexToolMode:"shell", apiKey:$api_key, defaultModel:$model,
      liveModels:true, models:[$model], selectedModels:[$model],
      contextWindow:$context, modelContextWindows:{($model):$context},
      modelMaxInputTokens:{($model):$input},
      modelAutoCompactTokenLimits:{($model):$compact},
      modelInputModalities:{($model):["text"]}, noVisionModels:[$model],
      modelReasoningEfforts:{($model):["low","medium","xhigh"]},
      modelDefaultReasoningEfforts:{($model):"xhigh"},
      modelSupportsReasoningSummaries:{($model):true},
      modelSupportsVerbosity:{($model):false},
      modelMaxOutputTokens:{($model):$output},
      preserveReasoningContentModels:[$model], parallelToolCalls:true
    } | if $api_key == "" then del(.apiKey) else . end')"

  rendered_config="$(mktemp)"
  jq \
    --arg provider_id "$LOCAL_AI_PROVIDER_ID" \
    --arg local_model "$LOCAL_AI_PROVIDER_ID/$LOCAL_AI_MODEL_ID" \
    --arg web_sidecar_model "$CODEX_WEB_SEARCH_MODEL" \
    --arg vision_sidecar_model "$CODEX_VISION_MODEL" \
    --argjson port "$OPENCODEX_PORT" \
    --argjson local_provider "$local_provider_json" \
    --argjson cloud_models "$cloud_models_json" \
    '.port = $port
     | .providers = (.providers // {})
     | .providers.openai = (.providers.openai // {
         adapter:"openai-responses",
         baseUrl:"https://chatgpt.com/backend-api/codex",
         codexAccountMode:"pool",
         authMode:"forward"
       })
     | .providers[$provider_id] = $local_provider
     | .defaultProvider = (.defaultProvider // "openai")
     | .multiAgentGuidanceEnabled = true
     | .subagentModels = ([$local_model] + $cloud_models
         | reduce .[] as $model ([]; if index($model) then . else . + [$model] end))
     | .subagentEffortCap = "xhigh"
     | .codexShimAutoRestore = true
     | .codexAutoStart = true
     | .webSearchSidecar = {
         enabled:true, backend:"openai", model:$web_sidecar_model,
         reasoning:"low", maxSearchesPerTurn:4
       }
     | .visionSidecar = {
         enabled:true, backend:"openai", model:$vision_sidecar_model,
         maxDescriptionsPerTurn:8
       }
     | .websockets = false' \
    "$base_config" > "$rendered_config"

  ocx config validate "$rendered_config" >/dev/null
  install -m 600 "$rendered_config" "$opencodex_config"
  rm -f -- "$rendered_config"
  if [[ "$base_config" != "$opencodex_config" ]]; then
    rm -f -- "$base_config"
  fi

  ocx service
  if command -v loginctl >/dev/null && [[ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null || true)" != yes ]]; then
    loginctl enable-linger "$USER" 2>/dev/null || printf 'Warning: enable login linger manually for boot-time startup.\n' >&2
  fi
  ocx ready --wait --timeout 60 >/dev/null
fi

mkdir -p "$pi_dir"
package="npm:@tian.zuo/pi-web-search@$PI_WEB_SEARCH_VERSION"
PI_CODING_AGENT_DIR="$pi_dir" PI_TELEMETRY=0 pi install "$package" >/dev/null

cloud_models_json="$(printf '%s' "$PI_WORKER_CLOUD_MODELS" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))')"
jq -n \
  --arg model "local-ai/$LOCAL_AI_MODEL_ID" \
  --arg reasoning "$LOCAL_AI_DEFAULT_REASONING" \
  --arg package "$package" \
  --argjson cloud "$cloud_models_json" \
  '{
    defaultProvider:"opencodex",
    defaultModel:$model,
    defaultThinkingLevel:$reasoning,
    enabledModels:(["opencodex/" + $model] + ($cloud | map("opencodex/" + .))),
    packages:[$package]
  }' > "$pi_dir/settings.json.tmp"
install -m 600 "$pi_dir/settings.json.tmp" "$pi_dir/settings.json"
rm -f -- "$pi_dir/settings.json.tmp"

if ((skip_opencodex == 0)); then
  ocx export --client pi --json > "$pi_dir/models.json.tmp"
  jq \
    --arg id "$LOCAL_AI_PROVIDER_ID/$LOCAL_AI_MODEL_ID" \
    --argjson context "$LOCAL_AI_CONTEXT_WINDOW" \
    --argjson output "$LOCAL_AI_MAX_OUTPUT_TOKENS" \
    '(.providers.opencodex.models[] | select(.id == $id)) |=
      (.input = ["text"] | .contextWindow = $context | .maxTokens = $output)' \
    "$pi_dir/models.json.tmp" > "$pi_dir/models.json.rendered"
  install -m 600 "$pi_dir/models.json.rendered" "$pi_dir/models.json"
  rm -f -- "$pi_dir/models.json.tmp" "$pi_dir/models.json.rendered"
fi

install -m 600 "$repo_dir/VERSION" "$state_dir/version"
printf 'Installed local-ai-pi-worker. Run: %s --health\n' "$bin_dir/pi-worker"
