# Changelog

## 0.3.0 - 2026-08-28

- Narrow the package to a harness-neutral local Pi worker: direct local runtime
  catalog, tools, instructions, CLI, and delegation skill only.
- Remove OpenCodex/Codex installation, configuration, model catalog, sidecars,
  service checks, and cloud allowlist from the package core. Gateways remain
  optional adjacent integrations.
- Add `pi-worker --cwd`, a child-only `bounded-worker` skill, and compact
  fallback handoff guidance optimized for lightweight local models.
- Add `pi-worker --rpc` using Pi's native JSONL process protocol for managed
  prompt, steer/follow-up, state, result, and abort lifecycles.
- Add stable worker job IDs and a neutral settled boundary that parent adapters
  can map into their own lifecycle, including AIOS `waiting-review`.
- Load rooted repository instructions by default while keeping implicit skills
  and the user's ordinary Pi configuration isolated.
- Document the native desktop-thread boundary while keeping ordinary `pi`
  configuration isolated from `pi-worker`.
- Add `--result-json` for one-shot harness chaining while retaining raw Pi
  event streaming through `--json`.
- Automatically reconcile runtime context and the Pi catalog before local
  tasks; make `--health` the setup/release audit and `--sync` forced recovery.
- Add a parent-neutral assignment envelope, AIOS integration guidance, root
  `AGENTS.md`, RPC documentation, runtime-drift tests, and provider-isolation
  tests.

## 0.2.0 - 2026-08-28

- Inherit the served context window from live runtime metadata instead of
  duplicating a static value in integration config.
- Add `pi-worker-sync` and `pi-worker --sync` to refresh Codex and Pi catalogs
  after a live runtime-profile change.
- Keep a blank, explicit context override only for compatible runtimes that do
  not publish their capacity.
- Make the orchestration skill parent-harness neutral and install it in the
  shared `~/.agents/skills` location, with safe migration from the v0.1 Codex
  directory.
- Clarify that the vision sidecar describes images as text; it does not make the
  local GGUF multimodal.
- Honor the configured local default reasoning level in the OpenCodex catalog.
- Add an isolated 131,072-token runtime test for context inheritance.

## 0.1.0 - 2026-08-28

- Add a reproducible OpenCodex service and local-provider configuration.
- Isolate the worker from general Pi settings with `PI_CODING_AGENT_DIR`.
- Add the read-only-by-default `pi-worker` CLI and Codex orchestration skill.
- Add Monid/OpenCodex web-tool routing with Firecrawl disabled.
- Add idempotent install, restore-based uninstall, doctor and isolated tests.
- Preserve or discover local-runtime authentication instead of replacing it.
- Make Codex web-search and vision sidecars explicit and doctor-verified.
- Use the lightest web-search reasoning level accepted with hosted tools.
