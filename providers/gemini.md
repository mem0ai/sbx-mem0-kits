# Gemini: Google (cloud)


| | |
|---|---|
| Mem0 provider | `gemini` |
| Runs where | Cloud (`generativelanguage.googleapis.com`) |
| Credential | `GOOGLE_API_KEY` |
| LLM model | `gemini-2.5-flash` |
| Embedder model | `models/gemini-embedding-001` |
| Vector dimensions | 768 |

## Credential (store it as a secret, never on the command line)

`sbx run` has no `-e` flag. Store the key once with sbx's secret manager.
`google` is a built-in service, so the proxy injects it into outbound requests
and it never enters the sandbox or your shell history:

```bash
echo "$GOOGLE_API_KEY" | sbx secret set -g google   # -g = all sandboxes
# or run `sbx secret set -g google` for an interactive prompt
```

## Run

This provider is published as a ready-made image. Store your key, then launch:

```bash
echo "$GOOGLE_API_KEY" | sbx secret set -g google
sbx run --kit docker.io/ajeetraina777/sbx-mem0-kits:gemini claude
```

Or run the same spec straight from this repo, no Hub pull:

```bash
sbx run --kit ./kits/gemini claude
```

## What the kit contains

Gemini needs two things beyond the OpenAI setup, and `kits/gemini/spec.yaml`
already handles both:

- It installs the `google-genai` SDK (Mem0's `gemini` provider imports it, but it
  is not a `mem0ai` dependency).
- It sets a placeholder `GOOGLE_API_KEY`, because the SDK won't send a request
  without a key present and the proxy only replaces the value on the wire. The
  real key arrives from the stored `google` secret.

It also adds `generativelanguage.googleapis.com` to `permissions.network.allow` and writes
this `config.json`:

```json
{
  "vector_store": {
    "provider": "qdrant",
    "config": {
      "collection_name": "mem0_gemini",
      "path": "/home/agent/.mem0/qdrant",
      "on_disk": true,
      "embedding_model_dims": 768
    }
  },
  "llm": {
    "provider": "gemini",
    "config": { "model": "gemini-2.5-flash" }
  },
  "embedder": {
    "provider": "gemini",
    "config": { "model": "models/gemini-embedding-001" }
  }
}
```

Validated June 2026: with `GOOGLE_API_KEY=placeholder` in the sandbox env, a real
768-dim embedding came back from `generativelanguage.googleapis.com`, proving the
proxy injected the stored `google` secret.

## Notes

- Model names move. Google retires Gemini model ids over time. The pair
  validated here (June 2026) is `models/gemini-embedding-001` + `gemini-2.5-flash`;
  older ids like `text-embedding-004` and `gemini-1.5-flash` now return 404.
  If you hit a 404, list what your key can actually use:
  ```python
  from google import genai
  for m in genai.Client(api_key="...").models.list():
      print(m.name, m.supported_actions)
  ```
- Dimensions come from `output_dimensionality`. `gemini-embedding-001`
  natively defaults to 3072 but supports Matryoshka truncation. Mem0 requests
  whatever `embedding_dims` is set to (defaulting to 768), so the config
  above yields 768-dim vectors that match `embedding_model_dims`. To use 1536 or
  3072, set `embedding_dims` in the embedder config and `embedding_model_dims`
  in `vector_store` to the same value, then start a fresh collection.
