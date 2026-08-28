# Configuration

The installer creates `~/.config/local-ai-pi-worker/config.env` from
`config/defaults.env`. Edit that machine-local file and rerun `./install.sh`.
No repository path or model storage path is embedded in the installed setup.

Important values:

- `LOCAL_AI_BASE_URL`: OpenAI-compatible endpoint exposed by the local runtime.
- `LOCAL_AI_MODEL_ID`: model ID returned by `/v1/models`.
- `LOCAL_AI_API_KEY`: optional explicit runtime key. Blank preserves an
  existing provider key or discovers it from a matching running llama-server.
- `LOCAL_AI_CONTEXT_WINDOW_OVERRIDE`: normally blank. OpenCodex reads the served
  window from live `/v1/models` metadata (`meta.n_ctx` on llama.cpp). Set an
  integer only for a compatible runtime that cannot publish its context.
- `LOCAL_AI_MAX_OUTPUT_TOKENS`: conservative worker output cap.
- `PI_WORKER_CLOUD_MODELS`: comma-separated cloud models exposed for manual use.
- `PI_WEB_SEARCH_MODEL`: cloud model used by the OpenCodex-backed search tool.
- `CODEX_WEB_SEARCH_MODEL`: native cloud sidecar for Codex web-search calls.
- `CODEX_VISION_MODEL`: native cloud sidecar that describes Codex image input
  for the text-only local model.
- `PI_WORKER_SKILL_ROOT`: optional Agent Skills destination. Blank uses the
  harness-neutral `~/.agents/skills` location discovered by Codex and Pi.

Context belongs to the runtime, not this integration. Select 65,536, 131,072 or
another supported value in the runtime profile, then run `pi-worker --sync` if
the profile changed while the machine was already running. The sync fails rather
than advertising a missing context or an output cap larger than that context.

The installer never stores provider secrets in this repository. To make Monid
the first web provider, run `pi-worker --web-setup`, enter
`/websearch-auth`, and add a Monid API key. Without that key, search uses the
OpenCodex-backed provider and fetch uses direct HTTP. Firecrawl remains off.

Useful overrides for one invocation:

```bash
PI_WORKER_MODEL=gpt-5.6-luna pi-worker --thinking high -- 'Review this design.'
PI_WORKER_TOOLS=read,grep,find,ls pi-worker -- 'Inspect this repository.'
```
