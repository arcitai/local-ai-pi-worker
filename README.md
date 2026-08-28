# local-ai-pi-worker

Reproducible Linux integration for a minimal Pi worker routed through
[OpenCodex](https://github.com/lidge-jun/opencodex), with both local and cloud
models available from one provider catalog.

The default local profile targets an OpenAI-compatible model server at
`127.0.0.1:8080`, a 65,536-token context window, one local inference slot and
native text-only input. Codex image attachments remain available through an
explicit cloud vision sidecar. Every value is machine-configurable; repository
paths and model storage paths are never hardcoded.

## What it installs

- pinned open-source OpenCodex and Pi CLI versions;
- an enabled OpenCodex user service on `127.0.0.1:10100`;
- explicit Codex web-search and vision sidecars for the text-only local model;
- a dedicated Pi config under `~/.local/share/local-ai-pi-worker/pi-agent`;
- `~/.local/bin/pi-worker` with read-only defaults and opt-in write tools;
- the `orchestrate-pi-worker` Codex skill;
- Monid-first web tools with OpenCodex search fallback and Firecrawl disabled.

It does not install a model, llama.cpp, GPU drivers, an Omarchy plugin, themes,
sessions or provider secrets. See [architecture and ownership](docs/ARCHITECTURE.md).

## Install

Prerequisites: Linux, Bash, `jq`, `curl`, and either `mise` or Node/npm. A local
OpenAI-compatible endpoint is optional for cloud-only use but required for the
default worker model.

```bash
git clone https://github.com/onlinesourdough/local-ai-pi-worker.git
cd local-ai-pi-worker
./install.sh
./doctor.sh
```

Restart Codex once after the first install so the app reloads OpenCodex's model
catalog and the new skill. The OpenCodex service starts automatically after
future logins/reboots.

Edit `~/.config/local-ai-pi-worker/config.env` and rerun `./install.sh` to use a
different endpoint, model ID, context size or cloud-model allowlist. Full options
are in [configuration](docs/CONFIGURATION.md).

## Use

```bash
pi-worker --thinking low --no-web -- 'Inspect this repository. Do not edit files.'
pi-worker --model gpt-5.6-luna --thinking high -- 'Review this design.'
pi-worker --write -- 'Implement the explicitly scoped change and run its tests.'
pi-worker --health
```

Only use `--write` when the caller has explicitly authorized that exact mutation.

## Web search

Search is a tool-provider chain, separate from OpenCodex model routing:

1. Monid/TinyFish, when a Monid API key is configured.
2. OpenCodex's OpenAI-compatible Responses endpoint.

Fetch uses Monid first and direct HTTP as fallback. Firecrawl keyless mode is
off, `FIRECRAWL_API_KEY` is removed from the worker environment, and the
installer removes a stored Firecrawl credential after backing it up.

To add Monid credentials locally:

```bash
pi-worker --web-setup
# then run /websearch-auth and choose Monid
```

No Monid login is required for the OpenCodex fallback.

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes only repo-managed files and restores first-install
backups. It leaves shared CLI packages installed. Pass `--keep-opencodex` to
leave the current OpenCodex configuration untouched.
