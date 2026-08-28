# Configuration

The installer creates `~/.config/local-ai-pi-worker/config.env` from
`config/defaults.env`. Edit that machine-local file and rerun `./install.sh`.
No repository path or model storage path is embedded in the installed setup.

Local runtime values:

- `LOCAL_AI_PROVIDER_ID`: Pi provider name owned by this worker.
- `LOCAL_AI_BASE_URL`: local OpenAI-compatible API base URL.
- `LOCAL_AI_MODEL_ID` and `LOCAL_AI_MODEL_NAME`: runtime ID and display name.
- `LOCAL_AI_API`: Pi API dialect. `openai-completions` is the compatible
  default; use another Pi-supported dialect only when the runtime requires it.
- `LOCAL_AI_API_KEY`: optional explicit runtime key. Blank discovers a matching
  running `llama-server` key or uses a keyless local connection.
- `LOCAL_AI_CONTEXT_WINDOW_OVERRIDE`: normally blank. The worker reads live
  `/v1/models` metadata, including llama.cpp `meta.n_ctx`. Set an integer only
  for a compatible runtime that cannot publish context.
- `LOCAL_AI_MAX_OUTPUT_TOKENS`: conservative output cap, always smaller than
  context.
- `LOCAL_AI_DEFAULT_REASONING`: default Pi thinking level.
- `LOCAL_AI_THINKING_LEVELS`: comma-separated levels actually supported by the
  runtime/model pair.

Worker values:

- `PI_WORKER_DEFAULT_PROFILE`: default capability profile. `inspect` is the
  minimal read-only default.
- `PI_WORKER_SKILL_ROOT`: parent orchestration-skill destination. Blank uses
  `$CODEX_HOME/skills` (normally `~/.codex/skills`). Set it to another parent
  harness's global Agent Skills-compatible directory when appropriate.
- `PI_WORKER_MACHINE_SKILL_ROOT`: neutral machine-skill catalog exposed to
  child workers. Blank uses `~/.agents/skills`. Keep it separate from the
  parent orchestration-skill root.
- `PI_WORKER_PROVIDER`, `PI_WORKER_MODEL`, `PI_WORKER_THINKING`,
  `PI_WORKER_PROFILE`, `PI_WORKER_TOOLS`, `PI_WORKER_SYSTEM_PROMPT`, and
  `PI_WORKER_JOB_ID`: per-process defaults useful to a parent harness.
- `PI_WORKER_UPDATE_REPO`: stable GitHub release source in `owner/repository`
  form. It defaults to this repository and can point at a maintained fork.
- `PI_WORKER_UPDATE_NOTIFY`: `1` installs/enables the daily systemd user timer;
  `0` keeps only manual `--check-update` and `--update` commands.

`--cwd` selects the worker's rooted work contract and the repository context Pi
loads from `AGENTS.md`/`CLAUDE.md`. It is not an operating-system sandbox;
tool policy and the parent remain responsible for enforcement. The launcher
disables Pi's implicit skill discovery, then explicitly supplies valid skills
from the machine root plus project `.agents/skills` and `.pi/skills` catalogs
in the selected Git-root hierarchy. Pi retains progressive disclosure.
`--no-global-skills` omits the machine catalog, `--no-skills` omits both
catalogs, and `--skill` forces one exceptional path. Use `--no-context-files`
only for a deliberately context-free child.

Capability profiles are intentionally small:

| Profile | Tool allowlist |
| --- | --- |
| `none` | none |
| `inspect` | `read,grep,find,ls` |
| `research` | inspect plus `web_search,web_fetch` |
| `edit` | inspect plus `edit,write` |
| `build` | edit plus `bash` |

Use `--web` to add the optional web tools, `--tools` for a custom allowlist,
and `--extension` only for reviewed local code. Profiles do not select model,
context, reasoning, provider, goal, or skills.

Context belongs to the runtime. Select 65,536, 131,072, or another supported
value there. The next local `pi-worker` call compares the endpoint with its
dedicated catalog and updates the catalog automatically. `pi-worker --health`
does the same before auditing readiness; `pi-worker --sync` forces a refresh
for recovery.

The installer never stores secrets in the repository. A discovered runtime key
is written only to the mode-0600 machine-local Pi catalog because Pi needs it to
call the endpoint. Set `LOCAL_AI_API_KEY` explicitly when process discovery is
not applicable.

Web is opt-in. Monid is the preferred search/fetch provider only when
`MONID_API_KEY` or its `/websearch-auth` credential is present. The extension
filters unconfigured providers out of the active chain, so an independently
configured provider search becomes primary when Monid is absent; fetch falls
back to direct HTTP. Firecrawl keyless remains disabled.

Update checks are separate from model/runtime synchronization. The timer and
`--check-update` contact only the GitHub Releases API and cache non-secret
status in `~/.local/state/local-ai-pi-worker/update.json`. Worker inference
never waits for that network request. `--update` must be invoked explicitly;
it installs only a release archive whose version matches its stable tag.

Examples:

```bash
PI_WORKER_THINKING=low pi-worker --profile inspect -- 'Inspect this repository.'
pi-worker --profile research -- 'Research the current dependency behavior.'
pi-worker --provider openai --model MODEL_ID --profile edit --thinking high -- 'Review and edit this design.'
pi-worker --cwd /path/to/project --job-id task-42 --rpc
```
