# local-ai-pi-worker

A small, reproducible Linux package for running an isolated
[Pi coding agent](https://github.com/earendil-works/pi-mono) against a local
OpenAI-compatible model server.

It owns one thing: the local Pi worker boundary. That includes a dedicated Pi
configuration, a capability-profile CLI, runtime-derived model metadata, an
optional web tool, and a portable delegation skill. It does not install or
configure a parent agent, gateway, desktop app, local model runtime, GPU stack,
or model.

The default endpoint is `127.0.0.1:8080`. Context is inherited from live
runtime metadata rather than duplicated in this repo, so changing a runtime
profile from 65K to 128K changes the worker on its next invocation.

## What it installs

- a pinned Pi CLI version;
- a dedicated Pi home under `~/.local/share/local-ai-pi-worker/pi-agent`;
- `pi-worker`, a read-only-by-default one-shot and RPC worker CLI;
- `pi-worker-sync`, which discovers and atomically updates the local catalog;
- `pi-worker-update`, which checks and applies stable GitHub releases;
- a 75-word child system guard with no always-loaded child skill;
- the portable `orchestrate-pi-worker` skill in the parent harness's global
  skill root (Codex `~/.codex/skills` by default);
- optional credential-aware web tools: Monid is primary when configured;
  otherwise the configured provider search is primary. Direct fetch remains
  available and Firecrawl keyless is disabled;
- a daily systemd user timer that sends one desktop notification per new
  release without keeping a background process alive.

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
different endpoint, model ID, API dialect, reasoning levels, or skill roots.
Context normally has no integration setting: it is read from `/v1/models`.
See [configuration](docs/CONFIGURATION.md).

The orchestration skill belongs to the parent, not the child. Installation
defaults its destination to `$CODEX_HOME/skills` (normally
`~/.codex/skills`). Set `PI_WORKER_SKILL_ROOT` to another harness's global
Agent Skills-compatible directory before reinstalling when that harness is the
parent. `PI_WORKER_MACHINE_SKILL_ROOT` separately controls which neutral
machine skills children receive and defaults to `~/.agents/skills`; keep these
roots separate.

If an agent is doing the setup, point it at [AGENTS.md](AGENTS.md). That file
defines the package boundary and separates read-only inspection from installation,
live readiness, and release checks.

## Use

One-shot workers return their final answer on stdout, diagnostics on stderr,
and success/failure through the process exit code.

```bash
pi-worker --cwd /path/to/project --profile inspect -- 'Inspect this repository. Do not edit files.'
pi-worker --cwd /path/to/project --profile research -- 'Research the current upstream API.'
pi-worker --cwd /path/to/project --profile build -- 'Implement the explicitly scoped change and run its tests.'
pi-worker --cwd /path/to/project --job-id review-42 --result-json --no-tools -- 'Classify this input.'
pi-worker --health
```

The default `inspect` profile exposes only `read`, `grep`, `find`, and `ls`.
`research` adds the optional web extension; `edit` adds file mutation without a
shell; `build` adds `bash`. `none` exposes no tools. Use `--tools`, `--web`, or
an audited `--extension` only for a task that needs a narrower custom surface.
Only use `edit` or `build` when the caller authorized that exact mutation.
Every local invocation first performs a lightweight runtime/catalog check and
self-synchronizes on drift. `pi-worker --sync` remains available as a forced
recovery command; it is not a routine step.

`--cwd` is the rooted task contract and context origin, not a kernel sandbox.
Keep `edit`/`build` for trusted workers with precise authority; a parent needing
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

Pi already supplies the agent loop, sessions, compaction, steering, follow-up,
and built-in code tools; this package does not recreate them. The assignment's
`Goal:` is the logical worker goal, `--job-id` is its identity, and an RPC
session is its continuation mechanism. Lifecycle state remains in the parent.

Repository `AGENTS.md`/`CLAUDE.md` instructions load from the selected cwd.
Neutral machine skills from `~/.agents/skills` plus project `.agents/skills`
and `.pi/skills` inside the selected Git root are supplied explicitly. Pi keeps
progressive disclosure: descriptions are cataloged, while matching bodies load
on demand. The parent-only orchestration skill lives in the parent harness's
separate global root and is therefore not in the child catalog. Use
`--no-global-skills` to omit the machine catalog, `--no-skills` to omit both
machine and project catalogs, and `--skill PATH` for one explicit exception.

The bundled skill teaches an Agent Skills-compatible parent when and how to use
both modes. A parent Pi session may itself use OpenAI while delegating to the
local model; a different parent can invoke the same CLI if it can run a process
and consume stdout. Install the skill in that parent's own global skill root.

The ordinary `pi` command and its general config are unchanged. Only
`pi-worker` exports the dedicated Pi home and disables Pi's implicit skill,
extension, prompt, and theme discovery. It then injects the separate
machine/project skill catalogs explicitly, preserving progressive disclosure
and predictable scope. `--no-context-files`, `--no-global-skills`, and
`--no-skills` provide independent escape hatches.

The CLI also accepts `--provider NAME --model ID`. That is an escape hatch for
providers available to the dedicated worker through environment credentials or
its own Pi home; managing those providers is outside this repo's scope.

See [RPC and app integration](docs/RPC.md) and
[architecture and ownership](docs/ARCHITECTURE.md).

## Web tools

Web tools are absent from the default worker. `--profile research` or `--web`
loads the small `pi-web-search` extension and exposes only `web_search` and
`web_fetch`. It can use any independently configured supported provider. Monid
is first in the preference order, but the extension filters that order by
available credentials: without a Monid key, the configured provider search is
primary instead. Direct HTTP remains the keyless fetch fallback. Firecrawl
keyless mode is off and its environment key is removed from worker processes.

An existing OpenAI-compatible search endpoint is preserved as machine-local
web-tool configuration; this package neither creates nor owns it.

To configure the extension interactively:

```bash
export MONID_API_KEY="..."  # set through your preferred secret manager
pi-worker --web-setup
# alternatively run /websearch-auth and configure Monid there
```

The package never stores a Monid key in the repository. Without a Monid key,
the extension removes Monid from the active chain instead of attempting it;
on this machine the primary search is then the existing OpenAI-compatible Luna
loopback.

Pi extensions run as local code with the worker's OS permissions. Additional
extensions are never auto-discovered; pass a reviewed source with `--extension`
and allow only its required tool names with `--tools`.

## Updates

Installed copies check the latest stable GitHub release once per day through a
short-lived systemd user timer. A new release produces one desktop notification
and a cached status; normal worker calls never perform a network update check.
An interactive worker terminal may show that cached notice, while JSON and RPC
streams stay unchanged.

```bash
pi-worker --check-update  # force a network check now
pi-worker --update        # download, verify, and install the newest release
pi-worker-update --status # read only the cached result
```

The updater accepts only stable GitHub release metadata, checks the archive has
one expected root, verifies its `VERSION` matches the release tag, and then
runs the release's installer. It never updates automatically. This is a shell
distribution, so npm publishing is not required.

Set `PI_WORKER_UPDATE_NOTIFY=0` in the machine config and rerun `./install.sh`
to disable the timer while retaining manual checks. A maintained fork can set
`PI_WORKER_UPDATE_REPO=owner/repository`.

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
