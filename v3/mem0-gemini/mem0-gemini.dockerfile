# syntax=docker/dockerfile:1
#
# mem0 (Gemini) is an env-carrying overlay that also ships the demo runbooks.
# As with the other flavors it installs no Python package into the image:
# mem0ai and google-genai land in the composed base's system Python at create
# time, via the lifecycle install hooks in mem0-gemini.yaml.
#
# MIGRATION NOTE: the runbooks (travel.py, verify.py) are wired to the local
# Docker Model Runner, so they are demos for the DMR flavor and will not run
# as-is here without repointing them at Gemini. They ship on every flavor for a
# uniform ~/runbooks/ layout; treat them as reference on the cloud flavors.
# This copy is kept in sync with ../files/home/runbooks/ and the other flavors.

# Stage runbooks under the agent's home with agent ownership — chown starts at
# /home/agent so /home stays root-owned (overlay home-ownership invariant).
FROM busybox:1 AS build
COPY runbooks/ /out/home/agent/runbooks/
RUN chown -R 1000:1000 /out/home/agent

FROM scratch
COPY --from=build /out /

# MIGRATION NOTE: v2 also set GOOGLE_API_KEY="placeholder" and NO_PROXY/no_proxy.
#   - GOOGLE_API_KEY is DROPPED from ENV: the key is now supplied by the
#     credential@1 entry in mem0-gemini.yaml, which sets a proxy-managed
#     sentinel in GOOGLE_API_KEY (the real key never enters the sandbox). The
#     SDK still sees a non-empty value and sends the request; the proxy swaps
#     in the real key on the wire. Setting it here too would fight that.
#   - NO_PROXY/no_proxy are DROPPED: a shell/agent workload already defines
#     NO_PROXY, and a mixin setting it to a different value is a hard
#     composition conflict. sbx enforces egress at the proxy regardless.
# Only MEM0_TELEMETRY remains. ENV must be on the recipe's final stage to merge.
ENV MEM0_TELEMETRY="false"
