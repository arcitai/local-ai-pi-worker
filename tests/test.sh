#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"
trap 'rm -rf -- "$tmp_root"' EXIT

for script in \
  "$repo_dir/install.sh" \
  "$repo_dir/uninstall.sh" \
  "$repo_dir/doctor.sh" \
  "$repo_dir/bin/pi-worker" \
  "$repo_dir/bin/pi-worker-sync" \
  "$repo_dir/bin/pi-worker-update" \
  "$repo_dir/tests/fixtures/bin/curl" \
  "$repo_dir/tests/fixtures/bin/mise" \
  "$repo_dir/tests/fixtures/bin/pi" \
  "$repo_dir/tests/fixtures/bin/systemctl" \
  "$repo_dir/tests/fixtures/bin/notify-send"; do
  bash -n "$script"
done

jq -e '
  .firecrawl.keyless == false
  and .searchOrder == ["monid", "openai"]
  and .fetchOrder == ["monid", "direct"]
  and (has("openai") | not)
' "$repo_dir/config/pi-web-search.json" >/dev/null

if rg -n -i '(^|[^a-z])ocx([^a-z]|$)' \
  "$repo_dir/bin" "$repo_dir/install.sh" "$repo_dir/doctor.sh" \
  "$repo_dir/config" >/dev/null; then
  printf '%s\n' 'core worker scripts/config still depend on OpenCodex' >&2
  exit 1
fi

HOME="$tmp_root/home"
XDG_DATA_HOME="$tmp_root/data"
XDG_CONFIG_HOME="$tmp_root/config"
XDG_STATE_HOME="$tmp_root/state"
CODEX_HOME="$tmp_root/codex"
PI_WORKER_BIN_DIR="$tmp_root/bin"
export HOME XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME CODEX_HOME PI_WORKER_BIN_DIR
mkdir -p \
  "$HOME/.config/pi-web-search" \
  "$HOME/.agents/skills" \
  "$HOME/.agents/skills/orchestrate-pi-worker" \
  "$tmp_root/project/.agents/skills/project-review" \
  "$tmp_root/shared-machine-review"
printf '%s\n' \
  '---' \
  'name: project-review' \
  'description: Review this fixture project.' \
  '---' \
  '# Project Review' \
  > "$tmp_root/project/.agents/skills/project-review/SKILL.md"
printf '%s\n' \
  '---' \
  'name: machine-review' \
  'description: Review machine-specific configuration.' \
  '---' \
  '# Machine Review' \
  > "$tmp_root/shared-machine-review/SKILL.md"
ln -s "$tmp_root/shared-machine-review" "$HOME/.agents/skills/machine-review"
printf '%s\n' \
  '---' \
  'name: orchestrate-pi-worker' \
  'description: Misplaced package-owned parent skill from an older release.' \
  '---' \
  > "$HOME/.agents/skills/orchestrate-pi-worker/SKILL.md"
mkdir -p "$HOME/.pi/agent"
printf '%s\n' '{"defaultProvider":"ordinary-pi"}' > "$HOME/.pi/agent/settings.json"
plain_pi_hash="$(sha256sum "$HOME/.pi/agent/settings.json")"
mkdir -p "$XDG_CONFIG_HOME/local-ai-pi-worker"
cp "$repo_dir/config/defaults.env" "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
cat >> "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env" <<'EOF'
OPENCODEX_VERSION=legacy
OPENCODEX_PORT=4096
PI_WORKER_CLOUD_MODELS=legacy/model
PI_WORKER_DEFAULT_TOOLS=read,grep,find,ls,web_search,web_fetch
EOF
sed -i '/^LOCAL_AI_MODEL_NAME=/d;/^LOCAL_AI_API=/d;/^LOCAL_AI_THINKING_LEVELS=/d;/^PI_WORKER_DEFAULT_PROFILE=/d' \
  "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
printf '%s\n' '{"openai":{"apiKey":"existing","baseUrl":"http://gateway.example/v1/responses","model":"search-model"}}' \
  > "$HOME/.config/pi-web-search/config.json"
mkdir -p "$XDG_STATE_HOME/local-ai-pi-worker"
: > "$XDG_STATE_HOME/local-ai-pi-worker/legacy-skill-migrated"

mock_log="$tmp_root/mock.log"
export MOCK_LOG="$mock_log"
PATH="$repo_dir/tests/fixtures/bin:$PATH"
export PATH

"$repo_dir/install.sh" --skip-packages >/dev/null
test "$(sha256sum "$HOME/.pi/agent/settings.json")" == "$plain_pi_hash"
grep -q '^LOCAL_AI_MODEL_NAME=' "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
grep -q '^LOCAL_AI_API=' "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
grep -q '^LOCAL_AI_THINKING_LEVELS=' "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
grep -q '^PI_WORKER_DEFAULT_PROFILE=inspect' "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
grep -q '^PI_WORKER_MACHINE_SKILL_ROOT=' "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
grep -q '^PI_WORKER_UPDATE_REPO=arcitai/local-ai-pi-worker' "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
grep -q '^PI_WORKER_UPDATE_NOTIFY=1' "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"
if grep -q '^OPENCODEX_VERSION=\|^OPENCODEX_PORT=\|^PI_WORKER_CLOUD_MODELS=\|^PI_WORKER_DEFAULT_TOOLS=' \
  "$XDG_CONFIG_HOME/local-ai-pi-worker/config.env"; then
  printf '%s\n' 'legacy config fields survived migration' >&2
  exit 1
fi
test -x "$PI_WORKER_BIN_DIR/pi-worker"
test -x "$PI_WORKER_BIN_DIR/pi-worker-sync"
test -x "$PI_WORKER_BIN_DIR/pi-worker-update"
test -f "$CODEX_HOME/skills/orchestrate-pi-worker/SKILL.md"
test ! -e "$HOME/.agents/skills/orchestrate-pi-worker"
test ! -e "$XDG_DATA_HOME/local-ai-pi-worker/skills/bounded-worker"
test -f "$XDG_DATA_HOME/local-ai-pi-worker/worker-system-prompt.txt"
test -f "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/settings.json"
test -f "$XDG_CONFIG_HOME/systemd/user/local-ai-pi-worker-update.service"
test -f "$XDG_CONFIG_HOME/systemd/user/local-ai-pi-worker-update.timer"
grep -q "ExecStart=\"$PI_WORKER_BIN_DIR/pi-worker-update\" --notify" \
  "$XDG_CONFIG_HOME/systemd/user/local-ai-pi-worker-update.service"
grep -q 'SYSTEMCTL_ARGS=--user enable --now local-ai-pi-worker-update.timer' "$mock_log"
jq -e '
  .openai.baseUrl == "http://gateway.example/v1/responses"
  and .firecrawl.keyless == false
  and .searchOrder == ["monid", "openai"]
  and .fetchOrder == ["monid", "direct"]
' \
  "$HOME/.config/pi-web-search/config.json" >/dev/null
jq -e '
  .defaultProvider == "local-ai"
  and .defaultModel == "qwen3.8-27b-local"
' "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/settings.json" >/dev/null
jq -e '
  .providers["local-ai"].baseUrl == "http://127.0.0.1:8080/v1"
  and .providers["local-ai"].api == "openai-completions"
  and any(.providers["local-ai"].models[]?;
    .id == "qwen3.8-27b-local"
    and .contextWindow == 131072
    and .maxTokens == 8192
    and .input == ["text"])
' "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/models.json" >/dev/null
grep -q 'LOCAL_AI_RESOLVED_CONTEXT_WINDOW=131072' \
  "$XDG_STATE_HOME/local-ai-pi-worker/runtime.env"

: > "$mock_log"
update_status="$(MOCK_LATEST_VERSION=v0.6.0 "$PI_WORKER_BIN_DIR/pi-worker" --check-update)"
grep -q 'Up to date: 0.6.0' <<< "$update_status"
jq -e '
  .installed_version == "0.6.0"
  and .latest_version == "0.6.0"
  and .update_available == false
' "$XDG_STATE_HOME/local-ai-pi-worker/update.json" >/dev/null

MOCK_LATEST_VERSION=v0.7.0 "$PI_WORKER_BIN_DIR/pi-worker-update" --notify
grep -q 'NOTIFY_ARGS=.*0.6.0 -> 0.7.0' "$mock_log"
jq -e '
  .update_available == true
  and .latest_version == "0.7.0"
  and .last_notified_version == "0.7.0"
' "$XDG_STATE_HOME/local-ai-pi-worker/update.json" >/dev/null
notification_count="$(grep -c '^NOTIFY_ARGS=' "$mock_log")"
MOCK_LATEST_VERSION=v0.7.0 "$PI_WORKER_BIN_DIR/pi-worker-update" --notify
test "$(grep -c '^NOTIFY_ARGS=' "$mock_log")" == "$notification_count"
grep -q 'Update available: 0.6.0 -> 0.7.0' \
  <<< "$("$PI_WORKER_BIN_DIR/pi-worker-update" --status)"

release_fixture="$tmp_root/release/local-ai-pi-worker-0.7.0"
mkdir -p "$release_fixture"
cp -a \
  "$repo_dir/install.sh" \
  "$repo_dir/bin" \
  "$repo_dir/config" \
  "$repo_dir/skills" \
  "$repo_dir/systemd" \
  "$repo_dir/worker" \
  "$repo_dir/VERSION" \
  "$release_fixture/"
printf '%s\n' '0.7.0' > "$release_fixture/VERSION"
release_tarball="$tmp_root/local-ai-pi-worker-v0.7.0.tar.gz"
tar -czf "$release_tarball" -C "$tmp_root/release" local-ai-pi-worker-0.7.0
if MOCK_LATEST_VERSION=v0.8.0 MOCK_RELEASE_TARBALL="$release_tarball" \
  "$PI_WORKER_BIN_DIR/pi-worker" --update >/dev/null 2>&1; then
  printf '%s\n' 'updater accepted a release archive with mismatched VERSION' >&2
  exit 1
fi
grep -q '^0.6.0$' "$XDG_STATE_HOME/local-ai-pi-worker/version"
MOCK_LATEST_VERSION=v0.7.0 MOCK_RELEASE_TARBALL="$release_tarball" \
  "$PI_WORKER_BIN_DIR/pi-worker" --update >/dev/null
grep -q '^0.7.0$' "$XDG_STATE_HOME/local-ai-pi-worker/version"
test ! -e "$XDG_STATE_HOME/local-ai-pi-worker/update.json"
grep -q 'CURL_ARGS=.*archive/refs/tags/v0.7.0.tar.gz' "$mock_log"

catalog_hash="$(sha256sum "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/models.json")"
: > "$mock_log"
FIRECRAWL_API_KEY=must-not-leak "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" -- 'bounded test' >/dev/null
test "$(sha256sum "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/models.json")" == "$catalog_hash"
grep -q 'FIRECRAWL_API_KEY=unset FIRECRAWL_KEYLESS=0' "$mock_log"
grep -q -- '--tools read,grep,find,ls' "$mock_log"
grep -q -- "--skill $tmp_root/project/.agents/skills" "$mock_log"
grep -q -- "--skill $HOME/.agents/skills/machine-review" "$mock_log"
grep -q -- '--no-skills' "$mock_log"
if grep -q -- "--skill $CODEX_HOME/skills/orchestrate-pi-worker" "$mock_log"; then
  printf '%s\n' 'parent skill root leaked into the child' >&2
  exit 1
fi
if grep -q -- '--no-context-files' "$mock_log"; then
  printf '%s\n' 'rooted repository context was unexpectedly disabled' >&2
  exit 1
fi
if grep -q 'web_search\|web_fetch' "$mock_log"; then
  printf '%s\n' 'web tools leaked into the inspect profile' >&2
  exit 1
fi
if grep -q -- '--extension' "$mock_log"; then
  printf '%s\n' 'an extension leaked into the inspect profile' >&2
  exit 1
fi

: > "$mock_log"
MOCK_RUNTIME_CONTEXT=131072 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --profile research -- 'research test' >/dev/null
grep -q -- '--tools read,grep,find,ls,web_search,web_fetch' "$mock_log"
grep -q -- "--extension $XDG_DATA_HOME/local-ai-pi-worker/pi-agent/npm/node_modules/@tian.zuo/pi-web-search/index.ts" "$mock_log"

: > "$mock_log"
MOCK_RUNTIME_CONTEXT=131072 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --profile edit -- 'edit test' >/dev/null
grep -q -- '--tools read,grep,find,ls,edit,write' "$mock_log"
if grep -q 'bash\|web_search\|web_fetch' "$mock_log"; then
  printf '%s\n' 'edit profile received shell or web tools' >&2
  exit 1
fi

: > "$mock_log"
MOCK_RUNTIME_CONTEXT=131072 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --profile build -- 'build test' >/dev/null
grep -q -- '--tools read,grep,find,ls,edit,write,bash' "$mock_log"

: > "$mock_log"
MOCK_RUNTIME_CONTEXT=131072 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --profile inspect --web -- 'inspect with web test' >/dev/null
grep -q -- '--tools read,grep,find,ls,web_search,web_fetch' "$mock_log"

extra_extension="$tmp_root/audited-extension.ts"
: > "$extra_extension"
: > "$mock_log"
MOCK_RUNTIME_CONTEXT=131072 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --tools read,custom_tool \
  --extension "$extra_extension" -- 'custom extension test' >/dev/null
grep -q -- '--tools read,custom_tool' "$mock_log"
grep -q -- "--extension $extra_extension" "$mock_log"

MOCK_RUNTIME_CONTEXT=262144 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --no-web -- 'runtime drift test' >/dev/null
jq -e 'any(.providers["local-ai"].models[]?; .contextWindow == 262144)' \
  "$XDG_DATA_HOME/local-ai-pi-worker/pi-agent/models.json" >/dev/null
grep -q 'LOCAL_AI_RESOLVED_CONTEXT_WINDOW=262144' \
  "$XDG_STATE_HOME/local-ai-pi-worker/runtime.env"

: > "$mock_log"
MOCK_CURL_FAIL=1 "$PI_WORKER_BIN_DIR/pi-worker" \
  --provider openai --model gpt-test --cwd "$tmp_root/project" --no-web -- 'cloud test' >/dev/null
if grep -q '^CURL_ARGS=' "$mock_log"; then
  printf '%s\n' 'non-local provider unexpectedly required the local runtime' >&2
  exit 1
fi

result_json="$(MOCK_RUNTIME_CONTEXT=262144 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --job-id review-42 --result-json --no-tools -- 'json result test')"
jq -e \
  --arg cwd "$tmp_root/project" '
  .ok == true
  and .exit_code == 0
  and .job_id == "review-42"
  and .state == "settled"
  and .profile == "none"
  and .tools == []
  and .provider == "local-ai"
  and .model == "qwen3.8-27b-local"
  and .cwd == $cwd
  and .result == "mock result"
' <<< "$result_json" >/dev/null

rpc_output="$(printf '%s\n' \
  '{"id":"start","type":"prompt","message":"bounded RPC task"}' \
  '{"id":"state","type":"get_state"}' \
  '{"id":"result","type":"get_last_assistant_text"}' \
  '{"id":"stop","type":"abort"}' \
  | MOCK_RUNTIME_CONTEXT=262144 "$PI_WORKER_BIN_DIR/pi-worker" \
      --cwd "$tmp_root/project" --job-id rpc-42 --rpc --no-web)"
grep -q '"type":"agent_settled"' <<< "$rpc_output"
grep -q '"sessionId":"mock-session"' <<< "$rpc_output"
grep -q '"text":"mock result"' <<< "$rpc_output"
grep -q '"command":"abort"' <<< "$rpc_output"
grep -q -- '--mode rpc' "$mock_log"
grep -q -- '--name rpc-42' "$mock_log"
if grep -q -- '--mode rpc.*--print\|--mode rpc.*--no-session' "$mock_log"; then
  printf '%s\n' 'RPC worker was incorrectly made one-shot' >&2
  exit 1
fi

failed_json="$({ MOCK_RUNTIME_CONTEXT=262144 MOCK_PI_FAIL=1 \
  "$PI_WORKER_BIN_DIR/pi-worker" --cwd "$tmp_root/project" --job-id failed-7 \
    --result-json --no-tools -- 'expected failure' || true; })"
jq -e '.ok == false and .exit_code == 7 and .job_id == "failed-7" and .state == "failed"' \
  <<< "$failed_json" >/dev/null

: > "$mock_log"
MOCK_RUNTIME_CONTEXT=262144 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --no-context-files --no-tools -- 'context-free test' >/dev/null
grep -q -- '--no-context-files' "$mock_log"

: > "$mock_log"
MOCK_RUNTIME_CONTEXT=262144 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --no-skills --no-tools -- 'skill-free test' >/dev/null
if grep -q -- '--skill' "$mock_log"; then
  printf '%s\n' 'machine or project skills leaked into --no-skills invocation' >&2
  exit 1
fi

: > "$mock_log"
MOCK_RUNTIME_CONTEXT=262144 "$PI_WORKER_BIN_DIR/pi-worker" \
  --cwd "$tmp_root/project" --no-global-skills --no-tools -- 'project-skills-only test' >/dev/null
grep -q -- "--skill $tmp_root/project/.agents/skills" "$mock_log"
if grep -q -- "--skill $HOME/.agents/skills/machine-review" "$mock_log"; then
  printf '%s\n' 'machine skill leaked into --no-global-skills invocation' >&2
  exit 1
fi

MOCK_RUNTIME_CONTEXT=262144 "$repo_dir/doctor.sh" >/dev/null
MOCK_RUNTIME_CONTEXT=262144 "$PI_WORKER_BIN_DIR/pi-worker" --health >/dev/null

"$repo_dir/uninstall.sh" >/dev/null
test ! -e "$PI_WORKER_BIN_DIR/pi-worker"
test ! -e "$PI_WORKER_BIN_DIR/pi-worker-sync"
test ! -e "$PI_WORKER_BIN_DIR/pi-worker-update"
test ! -e "$CODEX_HOME/skills/orchestrate-pi-worker"
test ! -e "$HOME/.agents/skills/orchestrate-pi-worker"
test ! -e "$XDG_DATA_HOME/local-ai-pi-worker"
test ! -e "$XDG_CONFIG_HOME/systemd/user/local-ai-pi-worker-update.service"
test ! -e "$XDG_CONFIG_HOME/systemd/user/local-ai-pi-worker-update.timer"
jq -e '
  .openai.baseUrl == "http://gateway.example/v1/responses"
  and (has("searchOrder") | not)
  and (has("fetchOrder") | not)
' "$HOME/.config/pi-web-search/config.json" >/dev/null

printf '%s\n' 'tests passed'
