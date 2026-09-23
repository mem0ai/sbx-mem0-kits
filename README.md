# sbx kits for mem0


This is a standalone [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit (`kind: mixin`) that adds the [Mem0](https://mem0.ai/) memory layer (`mem0ai`)
to any sandbox agent, pre-wired to a local [Docker Model Runner](https://docs.docker.com/ai/model-runner/) (DMR) for both the LLM and the embedder.

<img width="1747" height="857" alt="image" src="https://github.com/user-attachments/assets/82a44ff3-ec17-440d-bd30-31c2fe320c17" />


DMR is the zero-config default. It works with no cloud keys, but the embedder and LLM are both swappable. See [providers/](./providers/) for copy-paste config for OpenAI and Gemini.

> **Schema v2.** These kits use the sbx kit **schema v2** (`schemaVersion: "2"`).
> If you are porting from the older v1 layout, the field renames are:
> `network.allowedDomains` → `permissions.network.allow`,
> `commands.install` → `setup.install`,
> `commands.initFiles` → `setup.files`, and
> top-level `memory` → `agentInstructions.content`.


## Prerequisites

### 0. Login to Docker Hub

```console
sbx login
```


### 1. Preparing the host 

Docker Model Runner must be enabled in Docker Desktop (Settings → AI / Beta features) and the two models pulled before you start:

```console
docker model pull ai/gemma3              # LLM for memory extraction
docker model pull ai/mxbai-embed-large   # embedder (1024-dim)
```

### 2. Setting up the secret key (cloud providers only)

The DMR default needs no key — skip this step. You only set a secret when you
swap in a cloud provider (OpenAI or Gemini). Store it once with sbx's secret
manager; the key is never baked into the kit, and the sbx proxy injects it into
the sandbox at runtime (`sbx run` has no `-e` flag).

```console
echo "$OPENAI_API_KEY" | sbx secret set -g openai   # OpenAI (-g = all sandboxes)
echo "$GOOGLE_API_KEY" | sbx secret set -g google   # Gemini
```

Running `sbx secret set -g openai` (or `-g google`) with no piped value prompts
you for the key interactively instead. Then confirm it's stored:

```console
 sbx secret ls
```

Result:

```console
 sbx secret ls
 SCOPE      TYPE      NAME        SECRET                                                                               
  (global)   service   google      AQ.Ab8******...******wZ8Q                                                            
  (global)   service   openai      sk-pro******...******YGQA                                                            
  (global)   service   anthropic   (oauth configured) 
```

### 3. Launch the sandbox with the kit

Layer the mixin onto an agent. Each provider is published as its own image tag -
pick the one matching the secret you stored in step 2:

```console
# DMR (default, no key needed) — :latest is the same as :dmr
sbx run --kit docker.io/mem0/sbx-mem0-kits:latest claude

# OpenAI — store the key and launch in one line
sbx secret set -g openai && sbx run --kit docker.io/mem0/sbx-mem0-kits:openai claude

# Gemini
sbx secret set -g google && sbx run --kit docker.io/mem0/sbx-mem0-kits:gemini claude
```

Or straight from this repo over git:

```console
sbx run --kit "git+https://github.com/mem0ai/sbx-mem0-kits.git" claude
```

Or from a local clone (the kit lives at the repo root):

```console
git clone https://github.com/mem0ai/sbx-mem0-kits.git
sbx run --kit ./sbx-mem0-kits/ claude
```

#### Choosing the agent

The trailing argument (`claude` above) is the **coding agent** that runs inside
the sandbox. It is a separate axis from the provider kit tag. The provider tag
(`:openai`, `:gemini`, `:dmr`) decides what the Mem0 memory layer uses for its
LLM and embedder; the agent decides which assistant you actually interact with.
Any supported agent pairs with any provider tag.

`sbx run --help` lists the available agents:

```
claude, claude-bedrock, codex, copilot, cursor, docker-agent, droid, gemini, kiro, opencode, shell
```

So you can swap `claude` for any of these, for example Codex on OpenAI-backed
memory:

```console
sbx secret set -g openai && sbx run --kit docker.io/mem0/sbx-mem0-kits:openai codex
```

Note that `gemini` here is an agent (Google's Gemini CLI), which is unrelated to
the `:gemini` kit tag (Mem0's Gemini provider), they are independent choices.
Arguments meant for the agent itself go after a `--` separator, e.g.
`sbx run --kit ...:openai codex -- --help`.

### 4. Confirm the kit installed correctly 

Once you're in the sandbox's Claude session, use `!` shell escapes to prove the
mixin is really inside. The kit does four observable things — installs
`mem0ai`, sets env vars, writes `~/.mem0/config.json`, and injects a memory
note — so you can verify it on independent layers, from a cheap import check up
to a full end-to-end run.

**4a. The package is installed (the pinned version, in the user-site path):**

```console
!python3 -c "import mem0, importlib.metadata as m; print('mem0ai', m.version('mem0ai'), '->', mem0.__file__)"
```

Expect `mem0ai 2.0.5` (the exact pin from this kit's `spec.yaml`) installed
under `/home/agent/.local/lib/.../site-packages/` — the user-site location that
matches the kit installing as user `1000` rather than as root.

**4b. The mixin's env vars are present** — these are declared only in the kit's
`spec.yaml`, so they are a fingerprint that the kit (not a manual `pip install`)
wired things up:

```console
!env | grep -E 'OPENAI_BASE_URL|OPENAI_API_KEY|MEM0_TELEMETRY|NO_PROXY'
```

Expect `OPENAI_BASE_URL=http://host.docker.internal:12434/engines/v1`,
`OPENAI_API_KEY=dmr`, and `MEM0_TELEMETRY=false`.

**4c. The init file the kit wrote exists** (the qdrant + DMR-wired config):

```console
!cat /home/agent/.mem0/config.json
```

**4d. End-to-end functional proof** — add a memory and read it back through the
local DMR. This single command transitively exercises the package, the config
file, the env vars, and the DMR connection, so if you only run one check, run
this one:

```console
!python3 - <<'PY'
import os, json
for var in ("NO_PROXY", "no_proxy"):
    if var in os.environ:
          os.environ[var] = ",".join(e for e in os.environ[var].split(",") if e.strip() != "[::1]")

from mem0 import Memory

with open("/home/agent/.mem0/config.json") as f:
    m = Memory.from_config(json.load(f))

m.add([{"role": "user", "content": "I prefer dark roast coffee"}], user_id="alice")
print(m.search("what coffee do they like?", filters={"user_id": "alice"}))
PY
```

Expect the search to return the stored "dark roast coffee" memory.

 ### 5. Check the sandbox can reach DMR on the host

 ```
!curl -s http://host.docker.internal:12434/engines/v1/models | head
```

Expect a JSON list including ai/gemma3 and ai/mxbai-embed-large. 

### 6. Try a runbook

The kit ships runnable demos under `~/runbooks/`. They are plain files under
[`files/home/runbooks/`](./files/home/runbooks/) in this repo (the
[sbx-kits-contrib][contrib] `files/home/` convention — everything under it is
mirrored into `/home/agent/`), **not** hard-coded into `spec.yaml`. The DMR tags
include `travel.py`, a travel assistant that remembers the traveler across
separate runs:

```console
!python3 ~/runbooks/travel.py "I'm vegetarian, I like aisle seats. Book me to Lisbon."
!python3 ~/runbooks/travel.py "Plan my return leg."   # fresh process; it still knows you
```

To add a runbook, drop a `*.py` in `files/home/runbooks/` — it ships
automatically, no `spec.yaml` change. Because the tree lives at the repo root,
`sbx run --kit ./` picks it up for local testing too.

[contrib]: https://github.com/docker/sbx-kits-contrib

## Swapping the embedding / LLM provider

Mem0 is a semantic memory store, so an embedder is mandatory. There is no
"memory without embeddings" mode. DMR provides it locally by default, which
matters most for Claude agents: Anthropic
[ships no embeddings API](https://docs.anthropic.com/en/docs/build-with-claude/embeddings)
(it points to Voyage, which Mem0 doesn't support as a provider). OpenAI and Gemini
users can instead reuse one key for both the LLM and the embedder.

| Provider | Mem0 provider | Runs where | Credential | Example embed model | Dims |
|---|---|---|---|---|---|
| [DMR](./providers/dmr.md) (default) | `openai` (+ base_url) | local | none | `ai/mxbai-embed-large` | 1024 |
| [OpenAI](./providers/openai.md) | `openai` | cloud | `OPENAI_API_KEY` | `text-embedding-3-small` | 1536 |
| [Gemini](./providers/gemini.md) | `gemini` | cloud | `GOOGLE_API_KEY` | `models/gemini-embedding-001` | 768 |

Each page has the exact `config.json`, run command, and the dimension/network
notes. More detail: [providers/README.md](./providers/README.md).

## Troubleshooting

In case you face the following error message while runnng `sbx run --kit docker.io/..`:

```
sbx run --kit docker.io/mem0/sbx-mem0-kits:openai claude
Creating new sandbox 'claude-yourname'...
ERROR: failed to create sandbox: create runtime: create runtime: sandboxd error: status 403: mount policy denied: /Users/yourname: no applicable policies for op(action=fs:mount:write, resource=fs:path:/Users/yourname)
```

Here `yourname` is your account name (e.g. `/Users/John`); the sandbox name `claude-yourname` is derived from it.

The error is from the sbx sandbox runtime refusing to mount your home directory (/Users/your-home-directory). When you run sbx run from a folder, it tries to mount that folder (your current working directory) into the sandbox with write access and there's a policy that forbids mounting /Users/your-home-directory directly (mounting your entire home dir is blocked for safety). Pick up any other director other than home directory.
