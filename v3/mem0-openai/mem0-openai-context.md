## Mem0 memory layer (OpenAI)

The mem0ai package is installed and wired to OpenAI for both the LLM and the
embedder. `openai` is a built-in sbx service: the API key is supplied by the
sbx proxy from the stored openai secret, so it is not present in the sandbox.

Config is at `~/.mem0/config.json`, so `Memory.from_config(...)` add/search
works once the key is stored (`sbx secret set openai`).
