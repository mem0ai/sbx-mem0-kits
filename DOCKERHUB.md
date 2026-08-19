# Mem0 memory kit for Docker Sandboxes

A standalone [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit
(`kind: mixin`) that adds the [Mem0](https://mem0.ai/) memory layer (`mem0ai`) to
any sandbox agent. Mem0 is a semantic memory store, so it needs an embedder and an
LLM. This image ships in three backend flavors, one per tag.

Source and full docs: https://github.com/ajeetraina/sbx-mem0-kits

## Image tags

| Tag | LLM | Embedder | Credential |
|-----|-----|----------|------------|
| `latest`, `dmr` | `ai/gemma3` (local DMR) | `ai/mxbai-embed-large` (local DMR) | none |
| `openai` | `gpt-4o-mini` | `text-embedding-3-small` | `OPENAI_API_KEY` |
| `gemini` | `gemini-2.5-flash` | `models/gemini-embedding-001` | `GOOGLE_API_KEY` |

DMR is the default because it needs no cloud keys. It matters most for Claude
agents: Anthropic does not offer an embeddings model
(https://docs.anthropic.com/en/docs/build-with-claude/embeddings), and Mem0 has no
Voyage provider, so a Claude user has no cloud embedder. DMR fills that gap locally.
OpenAI and Gemini users can reuse one key for both halves.

## Quick start

Local default (DMR). Enable Docker Model Runner and pull the two models on the host:

    docker model pull ai/gemma3
    docker model pull ai/mxbai-embed-large
    sbx run --kit docker.io/ajeetraina777/sbx-mem0-kits:latest claude

OpenAI. Store the key once with sbx (never on the command line), then run:

    echo "$OPENAI_API_KEY" | sbx secret set -g openai
    sbx run --kit docker.io/ajeetraina777/sbx-mem0-kits:openai claude

Gemini:

    echo "$GOOGLE_API_KEY" | sbx secret set -g google
    sbx run --kit docker.io/ajeetraina777/sbx-mem0-kits:gemini claude

The cloud tags hold no key. The sbx proxy injects it from the stored secret, so the
key never enters the sandbox. `sbx run` has no `-e` flag by design.

## How it works

Each kit writes `/home/agent/.mem0/config.json` with the right provider, model, and
vector dimensions (OpenAI 1536, Gemini 768, DMR 1024), and adds the matching API
domain to the sandbox allow list. The Gemini tag also installs the `google-genai`
SDK. No hand-editing required.

Per-provider setup notes, validation details, and the raw `spec.yaml` for each kit
live on GitHub:
https://github.com/ajeetraina/sbx-mem0-kits/tree/main/providers
