# OpenAI (cloud)


| | |
|---|---|
| Mem0 provider | `openai` |
| Runs where | Cloud (`api.openai.com`) |
| Credential | `OPENAI_API_KEY` |
| LLM model | `gpt-4o-mini` (or any chat model) |
| Embedder model | `text-embedding-3-small` (1536) or `text-embedding-3-large` (3072) |
| Vector dimensions | 1536 for `3-small` |

## Credential (store it as a secret, never on the command line)

`sbx run` has no `-e` flag, and you should never put a key in the command anyway.
Store it once with sbx's secret manager. `openai` is a built-in service, so the
proxy injects the key into outbound OpenAI requests and it never enters the
sandbox, shell history, or `ps`:

```bash
echo "$OPENAI_API_KEY" | sbx secret set -g openai   # -g = all sandboxes
# or run `sbx secret set -g openai` for an interactive prompt
```

## Run

This provider is published as a ready-made image. Store your key, then launch:

```bash
echo "$OPENAI_API_KEY" | sbx secret set -g openai
sbx run --kit docker.io/mem0/sbx-mem0-kits:openai claude
```

Or run the same spec straight from this repo, no Hub pull:

```bash
sbx run --kit ./kits/openai claude
```

## What the kit contains

`kits/openai/spec.yaml` already wires everything:

- `permissions.network.allow` includes `api.openai.com`.
- `config.json` uses the `openai` provider for both halves, with `openai_base_url`
  pinned to `https://api.openai.com/v1`:

```json
{
  "vector_store": {
    "provider": "qdrant",
    "config": {
      "collection_name": "mem0_openai",
      "path": "/home/agent/.mem0/qdrant",
      "on_disk": true,
      "embedding_model_dims": 1536
    }
  },
  "llm": {
    "provider": "openai",
    "config": {
      "model": "gpt-4o-mini",
      "openai_base_url": "https://api.openai.com/v1"
    }
  },
  "embedder": {
    "provider": "openai",
    "config": {
      "model": "text-embedding-3-small",
      "openai_base_url": "https://api.openai.com/v1"
    }
  }
}
```

The key is never in the kit or `config.json`. The sbx proxy injects it from the
stored `openai` secret.

## Notes

Using `text-embedding-3-large` instead? That's 3072 dims, so change
`embedding_model_dims` to `3072` and start a fresh collection
(`rm -rf /home/agent/.mem0/qdrant` or a new `collection_name`).
