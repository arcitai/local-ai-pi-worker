# Agent instructions

## Scope

Maintain this repository as a small, harness-neutral local Pi worker package.
It owns the dedicated Pi config, direct local runtime catalog, `pi-worker` CLI
and RPC contract, worker tools/policy, and the bundled delegation skill.

Do not add or configure a parent harness, desktop app, model runtime, GPU stack,
cloud account, provider gateway, or model. OpenCodex can be recommended as an
optional adjacent bridge, but it is never a package dependency or install step.
Do not hardcode repository paths, model-file paths, machine context windows, or
parent-specific session IDs.

## Setup and audit

1. Read `README.md`, `docs/ARCHITECTURE.md`, and `config/defaults.env`.
2. Confirm the configured local endpoint is running.
3. Run `./install.sh`; use `--skip-packages` only when the pinned Pi version is
   already available.
4. Run `./doctor.sh` and `pi-worker --health`. Both synchronize runtime-derived
   metadata before reporting readiness.
5. Smoke-test a read-only one-shot worker and the RPC handshake.

Normal local invocations self-synchronize. Do not tell the user to run
`pi-worker --sync` after every runtime profile change; it is a forced recovery
command.

## Worker contract

- The default local model is direct through Pi's `models.json`.
- Parent harness/provider and worker provider are independent.
- One-shot output uses stdout/result JSON, stderr, and exit status.
- Managed integrations must use `pi-worker --rpc` and Pi's native JSONL
  protocol, not scrape terminal output or invent a second server.
- Transport settlement is neutral; parent adapters own lifecycle names such as
  AIOS `waiting-review` and Codex app-server thread states.
- Load rooted repository context files and project skill catalogs by default;
  keep global skill discovery off and preserve Pi's progressive disclosure.
- Default to the `inspect` profile. Web, writes, shell, explicit skills, and
  extra extensions are separate opt-ins selected by the lead.
- Never load the delegation skill recursively inside the child worker.
- Queue local workers when the runtime exposes one inference slot.

## Changes and release

Keep shell scripts portable Bash and machine files mode 0600. Preserve unknown
providers in the dedicated `models.json`, preserve unrelated user files, and
keep uninstall restore-based. Update docs, tests, `CHANGELOG.md`, and `VERSION`
for behavior changes.

Before release, run:

```bash
./tests/test.sh
shellcheck install.sh uninstall.sh doctor.sh bin/pi-worker bin/pi-worker-sync
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/orchestrate-pi-worker
git diff --check
./install.sh --skip-packages
./doctor.sh
pi-worker --health
```

Then perform a real one-shot local smoke test and an RPC prompt/result/abort
smoke test. Publish only from a clean commit after CI passes.
