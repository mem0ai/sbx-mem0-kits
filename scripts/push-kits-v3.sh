#!/usr/bin/env bash
# Build and push the Kit v3 mixins (mem0/, mem0-openai/, mem0-gemini/) to Docker
# Hub. A v3 kit is an ordinary OCI image: BuildKit reads each descriptor's
# `# syntax=docker/sandbox-kit:3` line, pulls the kit frontend, validates the
# descriptor, builds the overlay and attaches the descriptor to the manifest.
#
#   ./scripts/push-kits-v3.sh                          # push all three flavors
#   DOCKERHUB_NAMESPACE=me ./scripts/push-kits-v3.sh   # push to another namespace
#   PUSH=0 ./scripts/push-kits-v3.sh                   # build only, into OCI layouts
#   KITS="mem0-openai" ./scripts/push-kits-v3.sh       # push a subset
#
# The v3 kit directories live under v3/ (v3/mem0, v3/mem0-openai, v3/mem0-gemini).
#
# This is the v3 counterpart to push-kits.sh (which publishes the v2 spec.yaml
# kits with `sbx kit push`). Both the v2 and v3 kits stay published: a v3 mixin
# only composes onto v3 workloads, a v2 mixin only onto v2 agents.
#
# NOTE ON TAGS: per the migration decision, the v3 kits reuse the existing
# docker.io/<ns>/sbx-mem0-kits repository and the same provider tags the README
# documents (:latest, :dmr, :openai, :gemini). The v3 loader is strict and
# single-version, and current sbx releases are v3-capable, so v3 is the
# go-forward artifact on those tags. Each flavor also gets a <tag>-<version>
# tag so a pull is pinnable (a bare provider tag says nothing about the build).
# Do not run push-kits.sh (v2) against the same tags afterward — it would
# overwrite these with v2 images.
set -euo pipefail

namespace="${DOCKERHUB_NAMESPACE:-${DOCKER_NAMESPACE:-mem0}}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
image="docker.io/$namespace/sbx-mem0-kits"
push="${PUSH:-1}"
platforms="${PLATFORMS:-linux/amd64,linux/arm64}"

command -v docker >/dev/null 2>&1 || { echo "push-kits-v3: docker not found." >&2; exit 1; }
docker buildx version >/dev/null 2>&1 || { echo "push-kits-v3: docker buildx not available." >&2; exit 1; }

# Read the descriptor's own `version:` so the pinned tag says what the image is.
kit_version() {
  sed -n 's/^version:[[:space:]]*"\{0,1\}\([0-9][^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "$1"
}

# publish KIT_DIR DESCRIPTOR "TAG[ TAG...]"
publish() {
  local kit_dir="$1" descriptor="$2"; shift 2
  local tags=("$@")
  local version; version="$(kit_version "$kit_dir/$descriptor")"
  [ -n "$version" ] || { echo "push-kits-v3: $descriptor has no version: field" >&2; exit 1; }

  local args=()
  for t in "${tags[@]}"; do
    args+=(-t "$image:$t" -t "$image:$t-$version")
  done

  if [ "$push" = "1" ]; then
    docker buildx build "$kit_dir" -f "$kit_dir/$descriptor" \
      --platform "$platforms" --push --provenance=true "${args[@]}"
    echo "Pushed ${tags[*]} (and -$version pins) from $kit_dir"
  else
    local layout="/tmp/sbx-mem0-kits-${tags[0]}-layout"
    rm -rf "$layout"
    docker buildx build "$kit_dir" -f "$kit_dir/$descriptor" \
      -t "sbx-mem0-kits:${tags[0]}-$version" \
      --output "type=oci,dest=$layout,tar=false"
    echo "Built ${tags[0]} $version into $layout"
    echo "  kit-tck validate --layout $layout ${tags[0]}-$version"
  fi
}

# Which flavors to publish (space-separated kit directory names).
KITS="${KITS:-mem0 mem0-openai mem0-gemini}"
for kit in $KITS; do
  case "$kit" in
    mem0)        publish "$repo_root/v3/mem0"        mem0.yaml        latest dmr ;;
    mem0-openai) publish "$repo_root/v3/mem0-openai" mem0-openai.yaml openai ;;
    mem0-gemini) publish "$repo_root/v3/mem0-gemini" mem0-gemini.yaml gemini ;;
    *) echo "push-kits-v3: unknown kit '$kit'" >&2; exit 1 ;;
  esac
done

if [ "$push" = "1" ]; then
  echo
  echo "Compose one onto a v3 workload, e.g.:"
  echo "  sbx run docker/sbx-kit-shell:1.0.0 --kit $image:latest ."
fi
