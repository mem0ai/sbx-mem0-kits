# syntax=docker/dockerfile:1
#
# mem0 (OpenAI) is an env-carrying overlay that also ships the demo runbooks.
# As with the DMR flavor it installs no Python package into the image: mem0ai
# lands in the composed base's system Python at create time, via the lifecycle
# install hooks in mem0-openai.yaml.
#
# MIGRATION NOTE: the runbooks (travel.py, verify.py) are wired to the local
# Docker Model Runner (host.docker.internal:12434, model ai/gemma3, api_key
# "dmr"), so they are demos for the DMR flavor and will not run as-is here
# without repointing them at OpenAI. They are shipped on every flavor for a
# uniform ~/runbooks/ layout; treat them as reference on the cloud flavors.
# This copy is kept in sync with ../files/home/runbooks/ and the other flavors.

# Stage runbooks under the agent's home with agent ownership — chown starts at
# /home/agent so /home stays root-owned (overlay home-ownership invariant).
FROM busybox:1 AS build
COPY runbooks/ /out/home/agent/runbooks/
RUN chown -R 1000:1000 /out/home/agent

FROM scratch
COPY --from=build /out /

# MIGRATION NOTE: v2 also set OPENAI_API_KEY="placeholder" and NO_PROXY/no_proxy.
#   - OPENAI_API_KEY is DROPPED from ENV: the key is now supplied by the
#     credential@1 entry in mem0-openai.yaml, which sets a proxy-managed
#     sentinel in OPENAI_API_KEY (the real key never enters the sandbox).
#     Setting it here too would fight that injection.
#   - NO_PROXY/no_proxy are DROPPED: a shell/agent workload already defines
#     NO_PROXY, and a mixin setting it to a different value is a hard
#     composition conflict. sbx enforces egress at the proxy regardless.
# OPENAI_BASE_URL points the client at OpenAI's API (config.json pins the same
# value); MEM0_TELEMETRY disables telemetry. ENV must be on the final stage.
ENV OPENAI_BASE_URL="https://api.openai.com/v1" \
    MEM0_TELEMETRY="false"
