# Changelog

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
