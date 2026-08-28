---
name: orchestrate-pi-worker
description: Delegate bounded repository investigation, read-only coding analysis, live web research, or explicitly authorized scoped edits to the Pi worker routed through OpenCodex. Use when Codex should offload a small independent task to a local or cloud Pi worker in a machine configured by local-ai-pi-worker; do not use for tasks requiring Codex-only tools or broad unsupervised mutation.
---

# Orchestrate Pi Worker

Use `pi-worker` for one bounded, independently verifiable subtask. Default to
the local model. Choose a cloud model explicitly only when the task needs more
context, vision, higher reliability, or parallel work without local-runtime
contention.

Run at most one local-model worker at a time. The optimized local runtime has a
single inference slot, so parallel local calls queue or reduce throughput.
Cloud workers may run independently.

Pass the complete task in one argument or on stdin. Request concrete evidence:
paths and line numbers for repository work; primary-source links for current
web claims. Treat the result as input to Codex judgment and verify consequential
claims before acting.

```bash
pi-worker --thinking low --no-web -- 'Find the test command and cite its source files. Do not modify files.'
pi-worker --thinking low -- 'Find the current official release and return primary-source links.'
pi-worker --model gpt-5.6-luna --thinking high -- 'Review this bounded design decision.'
pi-worker --json --no-tools -- 'Return a concise classification.'
pi-worker --health
```

The default tools are read-only filesystem discovery plus `web_search` and
`web_fetch`. Use `--no-web` for local-only tasks. Use `--write` only when the
user explicitly authorized the delegated mutation and the target is precise.
Never infer write permission from an unrelated implementation request.

Web search prefers Monid when its key is configured and otherwise uses the
OpenCodex-backed search provider. Firecrawl is disabled by the installed policy.
Preserve source URLs and verify important current claims against primary sources.
