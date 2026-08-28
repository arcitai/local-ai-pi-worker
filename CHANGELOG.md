# Changelog

## 0.1.0 - 2026-08-28

- Add a reproducible OpenCodex service and local-provider configuration.
- Isolate the worker from general Pi settings with `PI_CODING_AGENT_DIR`.
- Add the read-only-by-default `pi-worker` CLI and Codex orchestration skill.
- Add Monid/OpenCodex web-tool routing with Firecrawl disabled.
- Add idempotent install, restore-based uninstall, doctor and isolated tests.
- Preserve or discover local-runtime authentication instead of replacing it.
- Make Codex web-search and vision sidecars explicit and doctor-verified.
- Use the lightest web-search reasoning level accepted with hosted tools.
