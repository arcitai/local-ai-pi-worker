#!/usr/bin/env bash
set -euo pipefail

restore_opencodex=1
while (($#)); do
  case "$1" in
    --keep-opencodex) restore_opencodex=0 ;;
    -h|--help)
      printf '%s\n' 'Usage: ./uninstall.sh [--keep-opencodex]'
      exit 0
      ;;
    *) printf 'uninstall.sh: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
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
opencodex_config="${OPENCODEX_CONFIG_PATH:-$HOME/.opencodex/config.json}"
web_config="$HOME/.config/pi-web-search/config.json"
pi_auth="${PI_GLOBAL_AUTH_FILE:-$HOME/.pi/agent/auth.json}"

skill_root="$HOME/.agents/skills"
if [[ -r "$config_dir/config.env" ]]; then
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
# Also finish cleanup for installations upgraded from v0.1.
if [[ ! -e "$state_dir/legacy-skill-migrated" ]]; then
  restore_path "$codex_home/skills/orchestrate-pi-worker" codex-skill
fi
restore_path "$web_config" pi-web-search.json
restore_path "$pi_auth" pi-auth.json

if ((restore_opencodex)); then
  restore_path "$opencodex_config" opencodex-config.json
  if command -v ocx >/dev/null && [[ -f "$opencodex_config" ]]; then
    ocx config validate >/dev/null
    ocx service repair >/dev/null
  fi
fi

case "$config_dir" in
  */local-ai-pi-worker) rm -rf -- "$config_dir" ;;
  *) printf 'uninstall.sh: refusing unsafe config path: %s\n' "$config_dir" >&2; exit 1 ;;
esac
case "$state_dir" in
  */local-ai-pi-worker) rm -rf -- "$state_dir" ;;
  *) printf 'uninstall.sh: refusing unsafe state path: %s\n' "$state_dir" >&2; exit 1 ;;
esac

printf '%s\n' 'Removed local-ai-pi-worker and restored its first-install backups.'
