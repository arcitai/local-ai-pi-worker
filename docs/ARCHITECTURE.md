# Architecture and ownership

This repository is a local worker package, not an agent platform or provider
gateway.

| Layer | Owns | Does not own |
| --- | --- | --- |
| Local runtime or machine plugin | Model process, profiles, context, GPU tuning and model lifecycle | Pi policy or parent orchestration |
| This repository | Dedicated Pi config, direct local-provider catalog, worker CLI/RPC, safe tool policy and portable delegation skill | Runtime, parent app, general Pi config, cloud auth or gateway |
| Parent harness or app | Task decomposition, worker process lifecycle, approvals, result verification and user interaction | Worker model internals |
| Optional gateway | Unified catalogs, auth forwarding or modality sidecars | This worker's policy and tools |

```text
Parent harness / app / human
  ├── one shot: pi-worker ... ── stdout or final JSON
  └── managed:  pi-worker --rpc
                     ├── stdin  JSONL commands
                     └── stdout JSONL responses and events
                              │
                              ▼
                    Pi (dedicated config)
                              │
                              ▼
                 local OpenAI-compatible runtime
```

The parent provider is unrelated to the worker provider. A cloud-backed parent
may start a local worker, and a shell-only parent may do the same. The portable
skill is the behavioral adapter for Agent Skills-compatible harnesses; the CLI
and its process protocol are the universal integration boundary.

Runtime capabilities flow one way. The endpoint publishes its active context;
`pi-worker-sync` validates it and writes the same value to Pi's dedicated
`models.json`. A local invocation first performs a small consistency check and
repairs drift. An explicit override exists only for compatible endpoints that
omit context metadata.

The local model is natively text-only and is advertised as such. Image
description or vision remains an optional responsibility of a parent/gateway;
this package never makes a text model appear multimodal.

One local worker should run at a time when the runtime has one inference slot.
The parent owns scheduling and may queue additional local tasks. A worker
started with another independently configured provider does not consume that
slot.

The RPC mode intentionally reuses Pi's native protocol rather than inventing a
server. A future AIOS adapter can spawn one process per worker, keep the process
handle as its session reference, map Pi's neutral settled event into AIOS's
`waiting-review` lifecycle, let the lead accept or revise it, send `steer` or
`follow_up`, and send `abort` before terminating the child. Other parents keep
their own lifecycle vocabulary. See [RPC and app integration](RPC.md).
