---
name: orchestrate-pi-worker
description: Delegate one bounded, independently verifiable task to the isolated Pi worker configured by local-ai-pi-worker. Use from Codex, Pi, Claude Code, Hermes, AIOS, another Agent Skills-compatible harness, or a shell when selecting a minimal capability profile, starting or steering a one-shot/RPC worker, or consuming its handoff; do not use for user interaction, parent-only tools, or broad unsupervised mutation.
---

# Orchestrate Pi Worker

Keep the lead responsible for decomposition, authority, lifecycle, Review, and
the user. Give the worker one compact assignment:

```text
Responsibility: one non-overlapping role
Root: absolute project root
Goal: one observable outcome
Context: only necessary facts and paths
Authority: read-only or exact authorized edits
Constraints: relevant exclusions and proof
Handoff: evidence the lead needs back
```

Do not forward the parent transcript, secrets, unrelated decisions, or optional
work. `Goal` is the worker's logical goal; `--job-id` is its stable identity;
an RPC session provides continuation. Do not create a second child goal system.

## Select the least capability

| Profile | Tools | Use |
| --- | --- | --- |
| `none` | none | transformation or classification from supplied text |
| `inspect` | read, grep, find, ls | default repository investigation |
| `research` | inspect + web search/fetch | current external research |
| `edit` | inspect + edit/write | precise file changes without shell |
| `build` | edit + bash | authorized implementation and checks |

Profiles never select a provider, model, context window, role, or project
skill. Add web to another profile with `--web`; use `--tools` only for a narrow
custom allowlist. `--write` is a compatibility alias for `build`.

Pi automatically receives `AGENTS.md`/`CLAUDE.md`, neutral machine skills from
`~/.agents/skills`, and project `.agents/skills`/`.pi/skills` from the selected
Git-root hierarchy. Only skill metadata is initially exposed; Pi reads matching
bodies on demand. The orchestration skill itself belongs in the parent
harness's separate global skill root. Use `--no-global-skills` to omit machine
skills, `--no-skills` for a deliberately skill-free child, and `--skill PATH`
only to force one relevant exception.

Use `--extension SOURCE` only for a reviewed, task-required extension and pair
it with the exact tool names in `--tools`. Extensions execute with the worker
process's full OS permissions. The built-in profiles and optional web extension
cover normal work; do not turn the worker into a general parent harness.

## Invoke and collect

```bash
pi-worker --cwd "$PROJECT_ROOT" --profile inspect -- "$ASSIGNMENT"
pi-worker --cwd "$PROJECT_ROOT" --profile research --result-json -- "$ASSIGNMENT"
pi-worker --cwd "$PROJECT_ROOT" --profile build --job-id "$JOB_ID" -- "$ASSIGNMENT"
pi-worker --cwd "$PROJECT_ROOT" --job-id "$JOB_ID" --rpc
```

For one-shot work, stdout is the handoff, stderr is diagnostics, and exit status
is authoritative. `--result-json` adds job ID, neutral process state, selected
profile/tools, provider/model, cwd, and final text.

For managed work, speak Pi's native JSONL protocol over stdin/stdout. After
`prompt`, consume events until `agent_settled`, then request
`get_last_assistant_text`. Use `steer`, `follow_up`, `get_state`, and `abort` as
needed. Retain the process handle plus Pi session ID and terminate the child
during cleanup. Never scrape terminal presentation text.

Settlement means a handoff is available, not accepted. The parent verifies the
result and maps it into its lifecycle. AIOS may map a settled Build handoff to
`waiting-review`; another harness may not. A process worker does not become a
native clickable child task unless the parent app implements that adapter.

## Preserve boundaries

Run at most one worker against a single-slot local runtime; queue additional
local jobs. A cloud-backed parent may still use the local worker, and an
explicitly configured worker provider may replace the local default.

Treat `--cwd` as the rooted contract, not an OS sandbox. Reject roots outside
the parent's allowed registry. Use `edit`/`build` only with exact mutation
authority, verify consequential results in the lead, and keep user questions,
approvals, release actions, credentials, and final presentation in the parent.

Web is opt-in. The installed extension makes Monid primary only when its
credential exists; otherwise the next configured provider search is primary.
It uses direct fetch as the keyless fetch fallback and keeps Firecrawl keyless
disabled. Preserve primary-source URLs in the handoff.
