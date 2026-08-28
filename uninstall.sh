#!/usr/bin/env bash
set -euo pipefail

if (($#)); then
  case "$1" in
    -h|--help)
      printf '%s\n' 'Usage: ./uninstall.sh'
      exit 0
      ;;
    *) printf 'uninstall.sh: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
fi

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
bin_dir="${PI_WORKER_BIN_DIR:-$HOME/.local/bin}"
data_dir="$data_home/local-ai-pi-worker"
config_dir="$config_home/local-ai-pi-worker"
state_dir="$state_home/local-ai-pi-worker"
backup_dir="$state_dir/original"
web_config="$HOME/.config/pi-web-search/config.json"
pi_auth="${PI_GLOBAL_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

skill_root="$HOME/.agents/skills"
if [[ -r "$config_dir/config.env" ]]; then
  # shellcheck disable=SC1091
  # shellcheck disable=SC1090
  source "$config_dir/config.env"
  skill_root="${PI_WORKER_SKILL_ROOT:-$skill_root}"
fi
skill_dir="$skill_root/orchestrate-pi-worker"

restore_path() {
  local target="$1"
  local name="$2"
  if [[ -e "$backup_dir/$name" ]]; then
    rm -rf -- "$target"
    mkdir -p "$(dirname -- "$target")"
    cp -a -- "$backup_dir/$name" "$target"
  elif [[ -e "$backup_dir/$name.absent" ]]; then
    rm -rf -- "$target"
  fi
}

case "$data_dir" in
  */local-ai-pi-worker) rm -rf -- "$data_dir" ;;
  *) printf 'uninstall.sh: refusing unsafe data path: %s\n' "$data_dir" >&2; exit 1 ;;
esac

restore_path "$bin_dir/pi-worker" pi-worker
restore_path "$bin_dir/pi-worker-sync" pi-worker-sync
restore_path "$skill_dir" orchestration-skill
# Finish cleanup for installations upgraded from the original private skill
# location. This is migration compatibility, not a Codex dependency.
if [[ ! -e "$state_dir/legacy-skill-migrated" ]]; then
  restore_path "$codex_home/skills/orchestrate-pi-worker" codex-skill
fi
restore_path "$web_config" pi-web-search.json
restore_path "$pi_auth" pi-auth.json

case "$config_dir" in
  */local-ai-pi-worker) rm -rf -- "$config_dir" ;;
  *) printf 'uninstall.sh: refusing unsafe config path: %s\n' "$config_dir" >&2; exit 1 ;;
esac
case "$state_dir" in
  */local-ai-pi-worker) rm -rf -- "$state_dir" ;;
  *) printf 'uninstall.sh: refusing unsafe state path: %s\n' "$state_dir" >&2; exit 1 ;;
esac

printf '%s\n' 'Removed local-ai-pi-worker and restored its first-install backups.'
