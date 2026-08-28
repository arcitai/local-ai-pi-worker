# Changelog

## 0.6.0 - 2026-08-28

- Supply every valid machine-global Agent Skill from `~/.agents/skills` to Pi
  workers by default while retaining metadata-first progressive disclosure.
- Keep the parent-only `orchestrate-pi-worker` skill in the parent harness's
  global skill root—Codex `~/.codex/skills` by default—and migrate the
  package-owned copy that releases 0.2-0.5 placed in `~/.agents/skills`.
- Separate parent and child skill roots through `PI_WORKER_SKILL_ROOT` and
  `PI_WORKER_MACHINE_SKILL_ROOT`, so other harnesses can select their own
  parent location without hardcoded repository paths.
- Add `--no-global-skills` for project-only discovery; retain `--no-skills` as
  the fully skill-free mode and leave capability-profile tool limits intact.

## 0.5.0 - 2026-08-28

- Add `pi-worker --check-update` and `pi-worker --update` backed by stable
  GitHub releases, with archive layout and release-version validation before
  the installer runs.
- Add a lightweight daily systemd user timer that caches update status and
  sends at most one desktop notification per release. Worker invocations never
  perform an implicit network check.
- Surface a cached update notice only in interactive worker terminals and keep
  RPC, JSON, and headless callers free of update protocol noise.
- Make the release repository and automatic notification behavior configurable
  through `PI_WORKER_UPDATE_REPO` and `PI_WORKER_UPDATE_NOTIFY`.
- Install, diagnose, and restore the updater plus its systemd units within the
  existing package ownership boundary.

## 0.4.0 - 2026-08-28

- Replace the always-loaded `bounded-worker` skill with a 75-word system guard;
  the lead's compact assignment remains the task contract.
- Add capability profiles: context-free `none`, default read-only `inspect`,
  opt-in `research`, shell-free `edit`, and shell-enabled `build`.
- Make web tools and their extension opt-in. Monid is primary only when
  configured; provider search otherwise leads, with direct fetch fallback and
  Firecrawl keyless disabled.
- Discover only project `.agents/skills` and `.pi/skills` from the selected Git
  root while keeping global child skill discovery off. Preserve Pi's
  progressive disclosure and add `--no-skills` as the zero-catalog escape hatch.
- Add audited extension passthrough with `--extension`, retain custom `--tools`,
  and include the resolved profile/tools in one-shot result JSON.
- Use Pi's native agent loop, sessions, compaction, steering, follow-up, and RPC
  instead of inventing a duplicate worker goal engine. The assignment goal and
  parent lifecycle remain authoritative.

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
