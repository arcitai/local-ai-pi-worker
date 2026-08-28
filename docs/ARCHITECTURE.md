# Architecture and ownership

This repository is an integration layer. It deliberately does not own a model
runtime, model files, GPU tuning, Omarchy UI, Codex authentication, or general
Pi customization.

| Layer | Owns | Does not own |
| --- | --- | --- |
| Omarchy Local AI plugin | Profiles, llama.cpp service, model lifecycle and local UI | Pi, Codex or provider routing |
| OpenCodex | One OpenAI-compatible catalog for local and cloud providers; Codex injection; background proxy; web and vision sidecars | Local model process or Pi worker policy |
| This repository | Dedicated Pi worker config, `pi-worker`, web-tool policy and Codex orchestration skill | General `~/.pi/agent` config, sessions, themes or secrets |
| Codex | Primary orchestration, approvals and final verification | GPU runtime configuration |

```text
Codex ── OpenCodex :10100 ── cloud providers
  │             └─────────── Local AI :8080 ── llama.cpp/Vulkan
  └── orchestrate-pi-worker skill
          └── pi-worker ── Pi (dedicated config) ── OpenCodex :10100
                          └── web_search: Monid → OpenCodex
                              web_fetch: Monid → direct HTTP
```

OpenCodex is the model-provider gateway. The web extension has a separate
tool-provider fallback chain: it is not an OpenCodex combo/model failover.
Firecrawl keyless mode is disabled in config, its environment key is removed
from the worker process, and the installer removes only the stored
`websearch-firecrawl` credential after making a backup.

The local Qwen runtime is natively text-only. Its Pi catalog therefore remains
text-only. OpenCodex deliberately advertises image input to Codex because its
configured `gpt-5.6-luna` vision sidecar converts images to bounded text
descriptions before Qwen sees them. This keeps attachments usable in Codex
without pretending the GGUF itself is multimodal.

Local workers intentionally run one at a time on a single-slot local runtime.
Cloud-routed Pi workers may run concurrently without contending for that slot.
