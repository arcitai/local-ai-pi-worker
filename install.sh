#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
skip_packages=0

usage() {
  printf '%s\n' \
    'Usage: ./install.sh [--skip-packages]' \
    '' \
    '  --skip-packages   Do not install/update the pinned Pi CLI'
}

while (($#)); do
  case "$1" in
    --skip-packages) skip_packages=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'install.sh: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

for command_name in awk bash curl grep install jq mktemp sed; do
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
systemd_user_dir="$config_home/systemd/user"
update_service="$systemd_user_dir/local-ai-pi-worker-update.service"
update_timer="$systemd_user_dir/local-ai-pi-worker-update.timer"
config_file="$config_dir/config.env"
# pi-web-search 0.4.0 currently uses these fixed upstream paths. The installer
# backs them up before applying credential-aware Monid/provider routing and the
# Firecrawl-off policy.
web_config="$HOME/.config/pi-web-search/config.json"
pi_auth="${PI_GLOBAL_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

mkdir -p "$config_dir" "$backup_dir" "$data_dir" "$bin_dir"
if [[ ! -e "$config_file" ]]; then
  install -m 600 "$repo_dir/config/defaults.env" "$config_file"
fi

# New defaults fill fields added by upgrades; the machine file remains
# authoritative for values it already defines.
# shellcheck disable=SC1091
source "$repo_dir/config/defaults.env"
# shellcheck disable=SC1090
source "$config_file"

# Remove settings owned by the former gateway-focused release and add only the
# new direct-worker fields that an existing machine config does not yet have.
migrated_config="$(mktemp)"
awk '
  !/^(OPENCODEX_VERSION|OPENCODEX_PORT|PI_WEB_SEARCH_MODEL|CODEX_WEB_SEARCH_MODEL|CODEX_VISION_MODEL|PI_WORKER_CLOUD_MODELS)=/ &&
  $0 != "PI_WORKER_DEFAULT_TOOLS=read,grep,find,ls,web_search,web_fetch"
' "$config_file" > "$migrated_config"
append_config_default() {
  local name="$1"
  local value="$2"
  if ! grep -q "^${name}=" "$migrated_config"; then
    printf '%s=%q\n' "$name" "$value" >> "$migrated_config"
  fi
}
append_config_default LOCAL_AI_MODEL_NAME "$LOCAL_AI_MODEL_NAME"
append_config_default LOCAL_AI_API "$LOCAL_AI_API"
append_config_default LOCAL_AI_THINKING_LEVELS "$LOCAL_AI_THINKING_LEVELS"
append_config_default PI_WORKER_DEFAULT_PROFILE "$PI_WORKER_DEFAULT_PROFILE"
append_config_default PI_WORKER_UPDATE_REPO "$PI_WORKER_UPDATE_REPO"
append_config_default PI_WORKER_UPDATE_NOTIFY "$PI_WORKER_UPDATE_NOTIFY"
install -m 600 "$migrated_config" "$config_file"
rm -f -- "$migrated_config"
# shellcheck disable=SC1090
source "$config_file"

skill_root="${PI_WORKER_SKILL_ROOT:-$HOME/.agents/skills}"
skill_dir="$skill_root/orchestrate-pi-worker"
legacy_skill_dir="$codex_home/skills/orchestrate-pi-worker"
mkdir -p "$skill_root"

if ! [[ "$LOCAL_AI_MAX_OUTPUT_TOKENS" =~ ^[0-9]+$ ]] || ((LOCAL_AI_MAX_OUTPUT_TOKENS <= 0)); then
  printf 'install.sh: LOCAL_AI_MAX_OUTPUT_TOKENS must be a positive integer\n' >&2
  exit 1
fi
if [[ -n "${LOCAL_AI_CONTEXT_WINDOW_OVERRIDE:-}" ]]; then
  if ! [[ "$LOCAL_AI_CONTEXT_WINDOW_OVERRIDE" =~ ^[0-9]+$ ]] || ((LOCAL_AI_CONTEXT_WINDOW_OVERRIDE <= 0)); then
    printf 'install.sh: LOCAL_AI_CONTEXT_WINDOW_OVERRIDE must be blank or a positive integer\n' >&2
    exit 1
  fi
  if ((LOCAL_AI_MAX_OUTPUT_TOKENS >= LOCAL_AI_CONTEXT_WINDOW_OVERRIDE)); then
    printf 'install.sh: output token cap must be smaller than the context override\n' >&2
    exit 1
  fi
fi
if [[ "${PI_WORKER_UPDATE_NOTIFY:-1}" != 0 && "${PI_WORKER_UPDATE_NOTIFY:-1}" != 1 ]]; then
  printf 'install.sh: PI_WORKER_UPDATE_NOTIFY must be 0 or 1\n' >&2
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

install_pi() {
  if command -v mise >/dev/null; then
    mise use -g "pi@$PI_VERSION"
  elif command -v npm >/dev/null; then
    npm install --global "@earendil-works/pi-coding-agent@$PI_VERSION"
  elif ! command -v pi >/dev/null; then
    printf 'install.sh: install mise or npm before installing Pi\n' >&2
    exit 1
  fi
}

if ((skip_packages == 0)); then
  install_pi
fi
command -v pi >/dev/null || { printf 'install.sh: pi is not installed\n' >&2; exit 1; }

backup_once "$bin_dir/pi-worker" pi-worker
backup_once "$bin_dir/pi-worker-sync" pi-worker-sync
backup_once "$bin_dir/pi-worker-update" pi-worker-update
backup_once "$skill_dir" orchestration-skill
backup_once "$web_config" pi-web-search.json
backup_once "$update_service" update-service
backup_once "$update_timer" update-timer

install -m 755 "$repo_dir/bin/pi-worker" "$bin_dir/pi-worker"
install -m 755 "$repo_dir/bin/pi-worker-sync" "$bin_dir/pi-worker-sync"
install -m 755 "$repo_dir/bin/pi-worker-update" "$bin_dir/pi-worker-update"
rm -rf -- "$skill_dir"
cp -a "$repo_dir/skills/orchestrate-pi-worker" "$skill_dir"

# v0.1 installed this skill in a Codex-private directory. Migrate it once to
# the harness-neutral Agent Skills location without making Codex a dependency.
legacy_skill_migrated="$state_dir/legacy-skill-migrated"
if [[ "$skill_dir" != "$legacy_skill_dir" && ! -e "$legacy_skill_migrated" ]]; then
  if [[ -e "$backup_dir/codex-skill" ]]; then
    rm -rf -- "$legacy_skill_dir"
    mkdir -p "$(dirname -- "$legacy_skill_dir")"
    cp -a -- "$backup_dir/codex-skill" "$legacy_skill_dir"
  elif [[ -e "$backup_dir/codex-skill.absent" ]]; then
    rm -rf -- "$legacy_skill_dir"
  fi
  : > "$legacy_skill_migrated"
fi

mkdir -p "$(dirname -- "$web_config")"
base_web_config=/dev/null
if [[ -r "$web_config" ]]; then
  base_web_config="$web_config"
fi
if [[ "$base_web_config" == /dev/null ]]; then
  install -m 600 "$repo_dir/config/pi-web-search.json" "$web_config"
else
  jq -s '.[0] * .[1]' \
    "$base_web_config" "$repo_dir/config/pi-web-search.json" > "$web_config.tmp"
  install -m 600 "$web_config.tmp" "$web_config"
  rm -f -- "$web_config.tmp"
fi

if [[ -f "$pi_auth" ]] && jq -e 'has("websearch-firecrawl")' "$pi_auth" >/dev/null 2>&1; then
  backup_once "$pi_auth" pi-auth.json
  jq 'del(."websearch-firecrawl")' "$pi_auth" > "$pi_auth.tmp"
  install -m 600 "$pi_auth.tmp" "$pi_auth"
  rm -f -- "$pi_auth.tmp"
fi

mkdir -p "$pi_dir"
install -m 600 "$repo_dir/worker/worker-system-prompt.txt" "$data_dir/worker-system-prompt.txt"
rm -rf -- "$data_dir/skills/bounded-worker"
rmdir "$data_dir/skills" 2>/dev/null || true
package="npm:@tian.zuo/pi-web-search@$PI_WEB_SEARCH_VERSION"
PI_CODING_AGENT_DIR="$pi_dir" PI_TELEMETRY=0 pi install "$package" >/dev/null

jq -n \
  --arg provider "$LOCAL_AI_PROVIDER_ID" \
  --arg model "$LOCAL_AI_MODEL_ID" \
  --arg reasoning "$LOCAL_AI_DEFAULT_REASONING" \
  --arg package "$package" \
  '{
    defaultProvider:$provider,
    defaultModel:$model,
    defaultThinkingLevel:$reasoning,
    enabledModels:[$provider + "/" + $model],
    packages:[$package]
  }' > "$pi_dir/settings.json.tmp"
install -m 600 "$pi_dir/settings.json.tmp" "$pi_dir/settings.json"
rm -f -- "$pi_dir/settings.json.tmp"

PI_WORKER_CONFIG="$config_file" PI_WORKER_DATA_DIR="$data_dir" \
  "$bin_dir/pi-worker-sync"

mkdir -p "$systemd_user_dir"
escaped_update_bin="$bin_dir/pi-worker-update"
if [[ "$escaped_update_bin" == *$'\n'* ]]; then
  printf '%s\n' 'install.sh: updater path must not contain a newline' >&2
  exit 1
fi
escaped_update_bin="${escaped_update_bin//\\/\\\\}"
escaped_update_bin="${escaped_update_bin//&/\\&}"
escaped_update_bin="${escaped_update_bin//|/\\|}"
escaped_update_bin="${escaped_update_bin//%/%%}"
escaped_update_bin="${escaped_update_bin//\"/\\\"}"
rendered_service="$(mktemp)"
sed "s|@PI_WORKER_UPDATE_BIN@|$escaped_update_bin|g" \
  "$repo_dir/systemd/local-ai-pi-worker-update.service.in" > "$rendered_service"
install -m 644 "$rendered_service" "$update_service"
unlink "$rendered_service"
install -m 644 "$repo_dir/systemd/local-ai-pi-worker-update.timer" "$update_timer"
install -m 600 "$repo_dir/VERSION" "$state_dir/version"
rm -f -- "$state_dir/update.json"

if command -v systemctl >/dev/null \
  && systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  if [[ "$PI_WORKER_UPDATE_NOTIFY" == 1 ]]; then
    systemctl --user enable --now local-ai-pi-worker-update.timer >/dev/null
  else
    systemctl --user disable --now local-ai-pi-worker-update.timer >/dev/null 2>&1 || true
  fi
elif [[ "$PI_WORKER_UPDATE_NOTIFY" == 1 ]]; then
  printf '%s\n' 'install.sh: systemd user manager unavailable; use pi-worker --check-update manually' >&2
fi
printf 'Installed local-ai-pi-worker. Run: %s --health\n' "$bin_dir/pi-worker"
