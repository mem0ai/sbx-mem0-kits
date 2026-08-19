# Runbooks

Runnable demos shipped with the Mem0 kit. They live at `~/runbooks/` in the
sandbox and talk to the local Docker Model Runner, so they need no cloud keys.

## travel.py

A travel assistant that remembers the traveler across separate runs:

```console
python3 ~/runbooks/travel.py "I'm vegetarian, I like aisle seats. Book me to Lisbon."
python3 ~/runbooks/travel.py "Plan my return leg."   # fresh process; it still knows you
```

The first run starts with an empty profile; the second recalls what you told it.
