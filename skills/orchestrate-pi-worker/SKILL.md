---
name: orchestrate-pi-worker
description: Delegate bounded repository investigation, coding analysis, live web research, or explicitly authorized scoped edits to an isolated headless Pi worker. Use when any parent harness or human operator should offload a small independent task to the local model configured by local-ai-pi-worker, or deliberately select another Pi provider; do not use for tasks requiring parent-only tools, user interaction, or broad unsupervised mutation.
---

# Orchestrate Pi Worker

Use `pi-worker` for one bounded, independently verifiable subtask. The worker
is headless and does not inherit the parent conversation, so include the full
task, working directory, constraints, relevant context and expected report.
The parent harness and worker provider are independent. A Pi parent using
OpenAI, Codex, Claude Code, another Agent Skills-compatible harness, or a plain
shell caller can invoke the same worker. Default to the directly configured
local runtime. Select another Pi provider explicitly only when it is already
authenticated and the task requires it; this repository does not configure
that provider.

Before a setup or release-readiness audit, run `pi-worker --health`. Normal
local invocations automatically compare live runtime metadata with the worker
catalog and repair drift, so do not ask the user to remember a separate sync
step. Reserve `pi-worker --sync` for an explicit forced refresh or recovery.

Run at most one local-model worker at a time. The optimized local runtime has a
single inference slot, so parallel local calls queue or reduce throughput.
Cloud workers may run independently.

Build a compact assignment before invoking the worker. Include only:

```text
Responsibility: one non-overlapping role
Root: absolute allowed project directory
Goal: one observable outcome
Context: only facts and paths needed for this task
Authority: read-only, or the exact edits explicitly authorized
Constraints: commands, standards, exclusions, and time/size bounds
Handoff: evidence and verification the lead needs back
```

Keep this envelope short for a lightweight local model. Do not forward the
parent transcript, unrelated decisions, secrets, or ambiguous optional work.

Pass the complete task in one argument or on stdin. Request concrete evidence:
paths and line numbers for repository work; primary-source links for current
web claims. Treat the result as input to the parent orchestrator's judgment and
verify consequential claims before acting. The worker cannot ask the user or
delegate further work, so keep ambiguity resolution in the parent.

```bash
pi-worker --cwd "$PROJECT_ROOT" --thinking low --no-web -- "$ASSIGNMENT"
pi-worker --cwd "$PROJECT_ROOT" --job-id "$JOB_ID" --result-json --no-tools -- "$ASSIGNMENT"
pi-worker --cwd "$PROJECT_ROOT" --provider openai --model MODEL_ID --thinking high -- "$ASSIGNMENT"
pi-worker --health
```

For a one-shot child, stdout is the return channel, stderr carries diagnostics,
and the process exit code is authoritative. Use `--result-json` when the parent
needs one stable result envelope with job ID, process state, execution
metadata, and handoff; use `--json` for Pi's raw event stream.

For a managed, resumable worker, start
`pi-worker --job-id "$JOB_ID" --cwd "$PROJECT_ROOT" --rpc` and use Pi's JSONL
protocol on stdin/stdout. It supports prompt, steer/follow-up, state, result
retrieval and abort. Treat `agent_settled` as a transport-level settled
boundary, then request `get_last_assistant_text`. It means the handoff is
available, not that the parent accepted or completed the work. Keep the process
handle as the worker session reference and terminate it during cleanup. Do not
scrape terminal presentation text.

The worker cannot inject itself into an arbitrary lead thread. Stdout is the
handoff channel: a one-shot caller receives the final handoff directly; an app
or AIOS-style lead must consume RPC events, retrieve the final assistant text,
store it in its worker record, and bring that result into the lead context.
Send `steer` for a correction during work or `follow_up` for another bounded
turn. Send `abort` before killing a cancelled process.

When the parent has a user-visible activity channel, announce the job ID and
bounded responsibility at start, then surface the returned handoff for review.
This gives an audit trail in terminal/tool output, but it does not register a
native child thread in a desktop app.

The installed child always receives the small `bounded-worker` skill while
implicit skill discovery stays off. Pi still loads `AGENTS.md` or `CLAUDE.md`
from the exact `--cwd` hierarchy so repository rules follow the rooted worker;
use `--no-context-files` only when the caller deliberately wants none. Add each
relevant task or lifecycle capability explicitly with repeatable
`--skill /absolute/path`; never pass the parent orchestration skill into the
child.

For an AIOS-style parent, treat the AIOS/project registry as the source of
allowed roots. Reject a `--cwd` outside those roots. Record the worker's
responsibility, root, actual provider, model, reasoning, process handle, Pi
session ID, status, and final handoff. Keep the CLI's transport state separate
from the app's lifecycle. In AIOS specifically, its canonical lifecycle maps a
successful settled Build handoff to `waiting-review`, then lead PASS to
`complete`; another parent may use different names. Protocol/process errors map
to failure and abort to interruption. Keep at most one active local worker for
a single-slot runtime. The lead remains responsible for approvals, durable
state, review, and presenting any outcome to the user.

The default tools are read-only filesystem discovery plus `web_search` and
`web_fetch`. Use `--no-web` for local-only tasks. Use `--write` only when the
user explicitly authorized the delegated mutation and the target is precise.
Never infer write permission from an unrelated implementation request. Keep
parent-only capabilities and final verification in the parent harness.

Web search prefers Monid when its key is configured and can use another
explicitly authenticated provider in the installed extension. Direct HTTP is
the fetch fallback. Firecrawl is disabled by policy. Preserve source URLs and
verify important current claims against primary sources.
