## Mem0 memory layer (Gemini)

The mem0ai package plus the google-genai SDK are installed and wired to Gemini
for both the LLM and the embedder. `google` is a built-in sbx service: the API
key is supplied by the sbx proxy from the stored google secret, so it is not
present in the sandbox.

Config is at `~/.mem0/config.json`, so `Memory.from_config(...)` add/search
works once the key is stored (`sbx secret set google`).
