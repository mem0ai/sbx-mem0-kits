## Mem0 memory layer

The `mem0ai` package is installed and pre-wired to a local Docker Model
Runner (config at `~/.mem0/config.json`), so `Memory.from_config(...)`
add/search works with no cloud keys or external vector database.

Runnable demos ship under `~/runbooks/`:

    python3 ~/runbooks/verify.py                                  # one-shot smoke test
    python3 ~/runbooks/travel.py "Book me to Lisbon, I'm vegetarian."
    python3 ~/runbooks/travel.py "Plan my return leg."            # fresh process; it still knows you
