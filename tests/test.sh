#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"
trap 'rm -rf -- "$tmp_root"' EXIT

for script in "$repo_dir/install.sh" "$repo_dir/uninstall.sh" "$repo_dir/doctor.sh" "$repo_dir/bin/pi-worker" "$repo_dir/bin/pi-worker-sync"; do
  bash -n "$script"
done

jq -e '.firecrawl.keyless == false and .searchOrder == ["monid", "openai"]' "$repo_dir/config/pi-web-search.json" >/dev/null

HOME="$tmp_root/home"
XDG_DATA_HOME="$tmp_root/data"
XDG_CONFIG_HOME="$tmp_root/config"
XDG_STATE_HOME="$tmp_root/state"
CODEX_HOME="$tmp_root/codex"
PI_WORKER_BIN_DIR="$tmp_root/bin"
export HOME XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME CODEX_HOME PI_WORKER_BIN_DIR
mkdir -p "$HOME"

mock_log="$tmp_root/mock.log"
export MOCK_LOG="$mock_log"
PATH="$repo_dir/tests/fixtures/bin:$PATH"
export PATH

"$repo_dir/install.sh" --skip-packages --skip-opencodex >/dev/null
test -x "$PI_WORKER_BIN_DIR/pi-worker"
test -x "$PI_WORKER_BIN_DIR/pi-worker-sync"
test -f "$HOME/.agents/skills/orchestrate-pi-worker/SKILL.md"
test -f "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/settings.json"
jq -e '.defaultModel == "local-ai/qwen3.8-27b-local"' "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/settings.json" >/dev/null
jq -e '.firecrawl.keyless == false' "$HOME/.config/pi-web-search/config.json" >/dev/null

"$repo_dir/install.sh" --skip-packages >/dev/null
jq -e '.providers["local-ai"] | has("contextWindow") | not' "$HOME/.opencodex/config.json" >/dev/null
jq -e '.providers["local-ai"] | has("modelContextWindows") | not' "$HOME/.opencodex/config.json" >/dev/null
jq -e 'any(.providers.opencodex.models[]?; .id == "local-ai/qwen3.8-27b-local" and .contextWindow == 131072 and .maxTokens == 8192 and .input == ["text"])' \
  "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/models.json" >/dev/null
grep -q 'LOCAL_AI_RESOLVED_CONTEXT_WINDOW=131072' "$XDG_STATE_HOME/local-ai-pi-worker/runtime.env"

FIRECRAWL_API_KEY=must-not-leak "$PI_WORKER_BIN_DIR/pi-worker" --no-web -- 'bounded test' >/dev/null
grep -q 'FIRECRAWL_API_KEY=unset FIRECRAWL_KEYLESS=0' "$mock_log"
grep -q -- '--tools read,grep,find,ls' "$mock_log"
if grep -q 'web_search\|web_fetch' "$mock_log"; then
  printf '%s\n' 'web tools leaked into --no-web invocation' >&2
  exit 1
fi

"$repo_dir/uninstall.sh" --keep-opencodex >/dev/null
test ! -e "$PI_WORKER_BIN_DIR/pi-worker"
test ! -e "$PI_WORKER_BIN_DIR/pi-worker-sync"
test ! -e "$HOME/.agents/skills/orchestrate-pi-worker"
test ! -e "$XDG_DATA_HOME/local-ai-pi-worker"

printf '%s\n' 'tests passed'
