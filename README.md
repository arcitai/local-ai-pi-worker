# local-ai-pi-worker

A small, reproducible Linux package for running an isolated
[Pi coding agent](https://github.com/earendil-works/pi-mono) against a local
OpenAI-compatible model server.

It owns one thing: the local Pi worker boundary. That includes a dedicated Pi
configuration, a safe CLI, runtime-derived model metadata, a compact web-tool
policy, and a portable delegation skill. It does not install or configure a
parent agent, gateway, desktop app, local model runtime, GPU stack, or model.

The default endpoint is `127.0.0.1:8080`. Context is inherited from live
runtime metadata rather than duplicated in this repo, so changing a runtime
profile from 65K to 128K changes the worker on its next invocation.

## What it installs

- a pinned Pi CLI version;
- a dedicated Pi home under `~/.local/share/local-ai-pi-worker/pi-agent`;
- `pi-worker`, a read-only-by-default one-shot and RPC worker CLI;
- `pi-worker-sync`, which discovers and atomically updates the local catalog;
- a small child-only bounded-task and handoff skill;
- the portable `orchestrate-pi-worker` skill under `~/.agents/skills`;
- Monid-first web tools, direct fetch fallback, and Firecrawl disabled.

Nothing is written to general Pi settings. The web extension currently uses
its upstream shared config/auth paths; the installer backs those files up and
restores them on uninstall.

## Install

Prerequisites: Linux, Bash, `jq`, `curl`, and either `mise` or Node/npm. The
configured local OpenAI-compatible endpoint must be running.

```bash
git clone https://github.com/onlinesourdough/local-ai-pi-worker.git
cd local-ai-pi-worker
./install.sh
./doctor.sh
```

Edit `~/.config/local-ai-pi-worker/config.env` and rerun `./install.sh` for a
different endpoint, model ID, API dialect, reasoning levels, or skill root.
Context normally has no integration setting: it is read from `/v1/models`.
See [configuration](docs/CONFIGURATION.md).

If an agent is doing the setup, point it at [AGENTS.md](AGENTS.md). That file
defines the package boundary and the exact install, audit, and release checks.

## Use

One-shot workers return their final answer on stdout, diagnostics on stderr,
and success/failure through the process exit code.

```bash
pi-worker --cwd /path/to/project --thinking low --no-web -- 'Inspect this repository. Do not edit files.'
pi-worker --cwd /path/to/project --write -- 'Implement the explicitly scoped change and run its tests.'
pi-worker --cwd /path/to/project --job-id review-42 --result-json --no-tools -- 'Classify this input.'
pi-worker --health
```

Only use `--write` when the caller explicitly authorized that exact mutation.
Every local invocation first performs a lightweight runtime/catalog check and
self-synchronizes on drift. `pi-worker --sync` remains available as a forced
recovery command; it is not a routine step.

`--cwd` is the rooted task contract and context origin, not a kernel sandbox.
Keep write mode for trusted workers with precise authority; a parent needing
hard isolation should add its own container/sandbox around the same CLI.

## Harness integration

The caller and worker are deliberately separate:

```text
any parent harness or human
        │ shell process + stdout/JSONL
        ▼
    pi-worker
        │ dedicated Pi config
        ▼
local runtime (default) or an explicitly selected Pi provider
```

For a one-shot task, capture stdout or use `--result-json`. For a managed
worker, launch `pi-worker --rpc` in the task working directory and speak Pi's
native JSONL RPC protocol over stdin/stdout. That protocol provides prompt,
steering, follow-up, state, final-result retrieval and abort, so an app such as
AIOS can wrap it with the same worker lifecycle it uses for other harnesses
without this repo depending on that app.

Successful worker settlement is reported neutrally as `settled`; the parent
adapter decides whether that means AIOS `waiting-review`, a completed shell
job, or another harness state. `--job-id` provides a stable identifier and
becomes the Pi session name in RPC mode. A process worker can appear in
terminal/tool activity, but it is not automatically a native, clickable child
thread in a desktop app; that presentation belongs to the parent app's adapter.

Every child gets only the bundled `bounded-worker` skill by default. Implicit
skill discovery is disabled to keep context small and prevent recursive
delegation, while repository `AGENTS.md`/`CLAUDE.md` instructions load from the
selected cwd. A lead passes relevant task/lifecycle capabilities with repeated
`--skill /absolute/path` options. The worker follows the caller's handoff shape,
or falls back to a concise evidence-backed summary.

The bundled skill teaches an Agent Skills-compatible parent when and how to use
both modes. A parent Pi session may itself use OpenAI while delegating to the
local model; a different parent can invoke the same CLI if it can run a process
and consume stdout. Set `PI_WORKER_SKILL_ROOT` when a harness uses another
global skill directory.

The ordinary `pi` command and its general config are unchanged. Only
`pi-worker` exports the dedicated Pi home and disables implicit skills,
extensions, prompts, and themes. Its rooted repository context remains intact;
`--no-context-files` disables that too when deliberately required.

The CLI also accepts `--provider NAME --model ID`. That is an escape hatch for
providers available to the dedicated worker through environment credentials or
its own Pi home; managing those providers is outside this repo's scope.

See [RPC and app integration](docs/RPC.md) and
[architecture and ownership](docs/ARCHITECTURE.md).

## Web tools

Search prefers Monid when `MONID_API_KEY` or its Pi web-search credential is
available. Other providers supported by the installed web extension may be
used when independently authenticated. Fetch falls back to direct HTTP.
Firecrawl keyless mode is off and its environment key is removed from worker
processes.

An existing OpenAI-compatible search endpoint is preserved as machine-local
web-tool configuration; this package neither creates nor owns it.

To configure the extension interactively:

```bash
pi-worker --web-setup
# run /websearch-auth and choose Monid
```

## Optional gateways

A gateway can still be useful when a parent app needs a unified catalog,
provider-owned authentication, or modality sidecars. OpenCodex is one possible
adapter, but it is not installed, configured, required, or owned here. Keep
that bridge beside this package rather than inside the local worker.

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes only repo-managed worker files and restores the shared
web-extension files it backed up. It leaves Pi itself, runtimes, gateways,
parent harnesses, models, and credentials it did not manage untouched.
