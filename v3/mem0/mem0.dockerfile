# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
# (OPENAI_API_KEY below is the literal DMR sentinel "dmr", not a real secret —
#  the DMR endpoint ignores it. The lint rule is a false positive here.)
#
# mem0 (DMR) is an env-carrying overlay that also ships the demo runbooks. It
# installs no Python package into the image: the mem0ai wheel and the spaCy
# model land in the *composed base's* system Python at create time, via the
# lifecycle install hooks in mem0.yaml (a mixin overlay lands on an unknown
# base, so relocating site-packages here would not resolve).
#
# What the recipe DOES carry:
#   - the runtime environment (ENV), merged onto the composed image config;
#   - the demo runbooks under /home/agent/runbooks/, owned by the agent.
#
# v2 shipped runbooks via the sbx-kits-contrib `files/home/` convention
# (everything under files/home/ mirrored into /home/agent/). v3 has no such
# convention — content rides in this overlay. The runbooks here are a copy of
# ../files/home/runbooks/ (a kit's build context is rooted at its own dir and
# cannot reach a sibling's tree), so the two copies must be kept in sync.

# Stage the runbooks under the agent's home with the right ownership. The
# chown starts exactly at /home/agent so /home itself stays root-owned — the
# overlay home-ownership invariant is /home = root, /home/agent = uid 1000, and
# a `COPY --chown` onto scratch would wrongly hand /home to uid 1000.
FROM busybox:1 AS build
COPY runbooks/ /out/home/agent/runbooks/
RUN chown -R 1000:1000 /out/home/agent

# The overlay: FROM scratch keeps the layer purely the content above plus this
# ENV, which rides in the image config. The frontend stages the descriptor as a
# content layer alongside it.
FROM scratch
COPY --from=build /out /

# MIGRATION NOTE: v2 also set NO_PROXY / no_proxy so the mem0 client would reach
# the host's Docker Model Runner directly. Those are DROPPED here: a shell/agent
# workload already defines NO_PROXY, and a mixin setting the same variable to a
# different value is a hard composition conflict ("env conflict on NO_PROXY").
# They are also unnecessary — the runtime network policy in mem0.yaml allows
# host.docker.internal:12434, and sbx enforces egress transparently at the proxy
# boundary regardless of the app-level NO_PROXY. (The runbooks still strip the
# stray IPv6 "[::1]" NO_PROXY entry at runtime; that is app-level and unrelated.)
# OPENAI_* point the OpenAI-compatible client at the DMR; the api_key is the DMR
# sentinel "dmr", not a real credential — which is why this kit declares no
# credential@1. ENV must be on the recipe's final stage to merge at assembly.
ENV OPENAI_BASE_URL="http://host.docker.internal:12434/engines/v1" \
    OPENAI_API_KEY="dmr" \
    MEM0_TELEMETRY="false"
