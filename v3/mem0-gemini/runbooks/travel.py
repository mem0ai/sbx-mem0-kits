#!/usr/bin/env python3
"""A tiny travel assistant that remembers the traveler across runs.

Ships with the sbx-mem0-kits kit. Both the chat model and the Mem0 memory
layer talk to the local Docker Model Runner, so it runs with no cloud keys.

Usage (inside the sandbox):
    python3 ~/runbooks/travel.py "I'm vegetarian, I like aisle seats. Book me to Lisbon."
    python3 ~/runbooks/travel.py "Plan my return leg."     # a fresh process; it still knows you
"""
import os
import sys
import json

# sbx leaves an IPv6 "[::1]" entry in NO_PROXY that breaks the HTTP client's
# proxy-bypass matching, so calls to host.docker.internal get routed through the
# sandbox egress proxy and dropped. Strip it before any client is created.
for var in ("NO_PROXY", "no_proxy"):
    if var in os.environ:
        os.environ[var] = ",".join(e for e in os.environ[var].split(",") if e.strip() != "[::1]")

# sbx injects "proxy-managed" credential sentinels for openai/openrouter even
# when no secret is configured. Mem0's extractor reads OPENAI_API_KEY from the
# environment, so the sentinel overrides the kit's "dmr" key and the extraction
# call gets routed to openrouter.ai (which the sandbox then blocks). Force the
# local key and drop the openrouter sentinel before mem0 is imported.
os.environ["OPENAI_API_KEY"] = "dmr"
os.environ.pop("OPENROUTER_API_KEY", None)

from openai import OpenAI
from mem0 import Memory

USER = "traveler_123"

# Chat model and memory both point at the local Docker Model Runner.
llm = OpenAI(base_url="http://host.docker.internal:12434/engines/v1", api_key="dmr")
with open("/home/agent/.mem0/config.json") as f:
    memory = Memory.from_config(json.load(f))


def reply(question):
    # Load everything we already know about this traveler, not just query matches.
    profile = [m["memory"] for m in memory.get_all(filters={"user_id": USER})["results"]]
    print("known so far:", profile or "(nothing yet)")

    prompt = (
        "You are a travel assistant.\n"
        f"What you already know about this traveler: {', '.join(profile)}\n\n"
        f"Traveler: {question}"
    )
    answer = llm.chat.completions.create(
        model="ai/gemma3",
        messages=[{"role": "user", "content": prompt}],
    ).choices[0].message.content

    memory.add(question, user_id=USER)  # remember it for next time
    return answer


if __name__ == "__main__":
    question = " ".join(sys.argv[1:]) or "Plan me a trip somewhere warm."
    print(reply(question))
    # The local Qdrant client's __del__ runs during interpreter shutdown and
    # prints a harmless "Exception ignored ... sys.meta_path is None" traceback.
    # All work is already done and printed above, so exit cleanly and skip it.
    sys.stdout.flush()
    os._exit(0)
