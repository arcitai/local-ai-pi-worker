# RPC and app integration

`pi-worker --job-id JOB_ID --rpc` starts the configured worker as a persistent
JSONL process. The job ID becomes Pi's session display name and should also be
the parent application's durable worker-record key.
It uses Pi's native RPC protocol unchanged, which keeps this repository usable
from desktop apps, terminal orchestrators, Agent Skills-compatible harnesses,
and small scripts.

Process contract:

- launch it with `--cwd /absolute/project/root` (or set that child cwd);
- write one JSON object plus `\n` per stdin command;
- parse stdout strictly as newline-delimited JSON;
- treat stderr as diagnostics, never as trusted worker state;
- retain the child process handle as the live session reference;
- send `abort` and terminate the process during cancellation/cleanup.

A minimal lifecycle:

```json
{"id":"start","type":"prompt","message":"Inspect the repository and report evidence. Do not edit files."}
{"id":"state","type":"get_state"}
{"id":"result","type":"get_last_assistant_text"}
{"id":"stop","type":"abort"}
```

The prompt response only confirms acceptance. Events continue asynchronously.
Use `agent_settled` as the process-level settled boundary, then request
`get_last_assistant_text`. Settlement says a handoff is available; it does not
assign a parent-owned lifecycle state or imply acceptance. Use `steer` while
running and `follow_up` after the current run. `get_state` exposes the session
ID, selected model, thinking level, streaming state, and session file.

Safety is established before RPC starts:

- default tools are read-only plus configured web tools;
- `--no-web` removes network tools;
- `--write` explicitly enables shell/edit/write tools;
- implicit skills, prompts, themes, and extensions are disabled in the child;
- repository `AGENTS.md`/`CLAUDE.md` files are loaded from the selected cwd by
  default, while `--no-context-files` provides a context-free escape hatch;
- the orchestration skill is not loaded recursively;
- the local runtime/catalog check runs quietly before protocol output begins.

For applications, prefer this mapping:

| App operation | Pi RPC operation |
| --- | --- |
| start worker | spawn `pi-worker --job-id ID --cwd ROOT --rpc`, then `prompt` |
| observe | consume events; use `get_state` |
| send guidance | `steer` or `follow_up` |
| read result | wait for `agent_settled`, then `get_last_assistant_text` |
| interrupt | `abort`, then terminate after acknowledgement/timeout |
| session reference | child handle plus Pi `sessionId` from `get_state` |

The parent remains responsible for directory allowlists, approval UX,
concurrency, durable worker records, and final verification. On a one-slot local
runtime, queue local workers rather than running them concurrently.

Lifecycle names belong to the parent adapter. For example, AIOS may map a
settled Build handoff to `waiting-review` and later lead acceptance to
`complete`. The CLI itself reports `settled` (or `failed`) and does not impose
that AIOS-specific state machine on other harnesses.

## Desktop UI boundary

A process-level worker is not automatically a native child task in its parent
desktop app. Codex app-server, for example, renders real subagents from its own
persisted thread hierarchy (`parentThreadId`) and streams thread, turn, and item
events. `pi-worker` does not forge those objects or require that server. A
Codex lead can still expose the launch command/job ID in tool activity and fold
the returned handoff into the lead task; an AIOS-style adapter can provide its
own worker list using the same job ID, state, process handle, and Pi session ID.

This separation keeps the CLI usable by plain Pi, Claude Code, Codex, AIOS, or
another process-capable harness without changing the user's normal `pi` setup.
