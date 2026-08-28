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

- `PI_WORKER_DEFAULT_TOOLS`: default Pi tool allowlist.
- `PI_WORKER_SKILL_ROOT`: optional Agent Skills destination. Blank uses the
  harness-neutral `~/.agents/skills` location.
- `PI_WORKER_PROVIDER`, `PI_WORKER_MODEL`, `PI_WORKER_THINKING`,
  `PI_WORKER_TOOLS`, `PI_WORKER_SYSTEM_PROMPT`, and `PI_WORKER_JOB_ID`:
  per-process defaults useful to a parent harness.

`--cwd` selects the worker's rooted work contract and the repository context Pi
loads from `AGENTS.md`/`CLAUDE.md`. It is not an operating-system sandbox;
tool policy and the parent remain responsible for enforcement. Implicit skill
discovery stays disabled, so pass relevant task or lifecycle skills explicitly
with repeatable `--skill`. Use `--no-context-files` only for a deliberately
context-free child.

Context belongs to the runtime. Select 65,536, 131,072, or another supported
value there. The next local `pi-worker` call compares the endpoint with its
dedicated catalog and updates the catalog automatically. `pi-worker --health`
does the same before auditing readiness; `pi-worker --sync` forces a refresh
for recovery.

The installer never stores secrets in the repository. A discovered runtime key
is written only to the mode-0600 machine-local Pi catalog because Pi needs it to
call the endpoint. Set `LOCAL_AI_API_KEY` explicitly when process discovery is
not applicable.

For Monid, set `MONID_API_KEY` in the launching environment or run
`pi-worker --web-setup` and use `/websearch-auth`. Firecrawl remains disabled.

Examples:

```bash
PI_WORKER_THINKING=low pi-worker --no-web -- 'Inspect this repository.'
pi-worker --provider openai --model MODEL_ID --thinking high -- 'Review this design.'
pi-worker --cwd /path/to/project --job-id task-42 --rpc
```
