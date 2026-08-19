# DMR: Docker Model Runner (default, local, no keys)

This is what the kit ships with. Both the LLM (fact extraction) and the embedder
run locally via [Docker Model Runner](https://docs.docker.com/ai/model-runner/),
so no cloud credentials and no external vector database are needed.

DMR isn't a separate Mem0 provider. It's a local model runtime that Mem0 reaches
through the `openai` provider, with `openai_base_url` pointed at the DMR endpoint.

| | |
|---|---|
| Mem0 provider | `openai` (pointed at the DMR endpoint via `openai_base_url`) |
| Runs where | Local (host's Docker Model Runner) |
| Credential | none (`api_key: "dmr"` is a placeholder DMR ignores) |
| LLM model | `ai/gemma3` |
| Embedder model | `ai/mxbai-embed-large` |
| Vector dimensions | 1024 |
| Network | already covered by the kit |

## Prerequisites

Enable Docker Model Runner (Docker Desktop → Settings → AI / Beta features) and
pull both models on the host:

```console
docker model pull ai/gemma3              # LLM for memory extraction
docker model pull ai/mxbai-embed-large   # embedder (1024-dim)
```

## Config (`/home/agent/.mem0/config.json`)

This is the default the kit installs; you don't have to write it yourself.

```json
{
  "vector_store": {
    "provider": "qdrant",
    "config": {
      "collection_name": "mem0",
      "path": "/home/agent/.mem0/qdrant",
      "on_disk": true,
      "embedding_model_dims": 1024
    }
  },
  "llm": {
    "provider": "openai",
    "config": {
      "model": "ai/gemma3",
      "openai_base_url": "http://host.docker.internal:12434/engines/v1",
      "api_key": "dmr"
    }
  },
  "embedder": {
    "provider": "openai",
    "config": {
      "model": "ai/mxbai-embed-large",
      "openai_base_url": "http://host.docker.internal:12434/engines/v1",
      "api_key": "dmr",
      "embedding_dims": 1024
    }
  }
}
```

## Run

Published as the Hub image (`:latest`, also tagged `:dmr`), or run the standalone
spec from this repo:

```console
sbx run --kit docker.io/ajeetraina777/sbx-mem0-kits:latest claude
# or from this repo:
sbx run --kit ./kits/dmr claude
```

## Verify (inside the sandbox)

```console
!curl -s http://host.docker.internal:12434/engines/v1/models | head
```

Expect a JSON list including `ai/gemma3` and `ai/mxbai-embed-large`.

## Notes

DMR is the well-justified default for Claude agents specifically: Anthropic
ships no embeddings API, so this is the only zero-extra-vendor way to give a
Claude agent semantic memory. Small local embedders like `mxbai-embed-large` are
near state-of-the-art, so you lose almost nothing on retrieval quality.
