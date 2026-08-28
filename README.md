# local-ai-pi-worker

Reproducible Linux integration for a minimal Pi worker routed through
[OpenCodex](https://github.com/lidge-jun/opencodex), with both local and cloud
models available from one provider catalog.

The default local integration targets an OpenAI-compatible model server at
`127.0.0.1:8080`, one local inference slot and native text-only input. Its
served context window is inherited from live runtime metadata, so a 65K or 128K
runtime profile is configured only in the runtime. Codex image attachments
remain available through an explicit cloud sidecar that converts an image to a
bounded text description before the local model receives it. Repository paths,
model storage paths and machine-specific runtime profiles are never hardcoded.

## What it installs

- pinned open-source OpenCodex and Pi CLI versions;
- an enabled OpenCodex user service on `127.0.0.1:10100`;
- explicit Codex web-search and vision sidecars for the text-only local model;
- a dedicated Pi config under `~/.local/share/local-ai-pi-worker/pi-agent`;
- `~/.local/bin/pi-worker` with read-only defaults and opt-in write tools;
- `~/.local/bin/pi-worker-sync` for runtime-to-catalog synchronization;
- the portable `orchestrate-pi-worker` skill under `~/.agents/skills`;
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
different endpoint, model ID or cloud-model allowlist. Context normally has no
integration setting: OpenCodex reads the served value from `/v1/models`. Full
options are in [configuration](docs/CONFIGURATION.md).

## Use

```bash
pi-worker --thinking low --no-web -- 'Inspect this repository. Do not edit files.'
pi-worker --model gpt-5.6-luna --thinking high -- 'Review this design.'
pi-worker --write -- 'Implement the explicitly scoped change and run its tests.'
pi-worker --sync
pi-worker --health
```

Only use `--write` when the caller has explicitly authorized that exact mutation.
Run `pi-worker --sync` after changing a live runtime profile; OpenCodex refreshes
the Codex catalog and the command writes the same discovered context to Pi's
dedicated model catalog. OpenCodex also re-discovers the active context whenever
its service starts, including after a reboot.

The bundled skill is a generic parent/worker contract: the parent may be Codex,
Pi, another Agent Skills-compatible harness, or a human operator. The shared
`~/.agents/skills` location is discovered by both Codex and Pi; override
`PI_WORKER_SKILL_ROOT` for a harness with another skill root. The dedicated
worker itself stays isolated and never loads this orchestration skill recursively.

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
