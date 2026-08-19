#!/usr/bin/env python3
"""Smoke-test the Mem0 memory layer end to end, with no cloud call.

Ships with the sbx-mem0-kits kit. Writes one fact and reads it back, exercising
the whole loop: fact extraction and embedding on the local Docker Model Runner,
storage in the on-disk Qdrant vector store. If the preference comes back, memory
is working with no cloud call anywhere in the path.

Usage (inside the sandbox):
    python3 ~/runbooks/verify.py
"""
import os

# sbx leaves an IPv6 "[::1]" entry in NO_PROXY that breaks the HTTP client's
# proxy-bypass matching, so calls to host.docker.internal get routed through the
# sandbox egress proxy and dropped. Strip it before any client is created.
for var in ("NO_PROXY", "no_proxy"):
    if var in os.environ:
        os.environ[var] = ",".join(e for e in os.environ[var].split(",") if e.strip() != "[::1]")

# sbx injects "proxy-managed" credential sentinels for openai/openrouter even
# when no secret is configured, and that injection overrides the values the kit
# sets in its environment. Mem0's OpenAI-compatible client honors
# OPENROUTER_API_KEY when present and reroutes extraction to openrouter.ai (which
# the sandbox then blocks), so force the local key and drop the openrouter
# sentinel before mem0 is imported.
os.environ["OPENAI_API_KEY"] = "dmr"
os.environ.pop("OPENROUTER_API_KEY", None)

import json
from mem0 import Memory

with open("/home/agent/.mem0/config.json") as f:
    m = Memory.from_config(json.load(f))

m.add([{"role": "user", "content": "I prefer dark roast coffee"}], user_id="alice")
print(m.search("what coffee do they like?", filters={"user_id": "alice"}))

# The local Qdrant client's __del__ runs during interpreter shutdown and prints a
# harmless "Exception ignored ... sys.meta_path is None" traceback. All work is
# already done and printed above, so exit cleanly and skip it.
import sys
sys.stdout.flush()
os._exit(0)
