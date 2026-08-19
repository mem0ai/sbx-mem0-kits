#!/usr/bin/env bash
set -euo pipefail

namespace="${DOCKERHUB_NAMESPACE:-${DOCKER_NAMESPACE:-ajeetraina777}}"
tag="${TAG:-latest}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
image="docker.io/$namespace/sbx-mem0-kits"

# publish SPEC_DIR IMAGE_TAG README_FILE [FILES_DIR]
# Stages a kit (spec.yaml + README + LICENSE), validates it, and pushes one tag.
# If FILES_DIR is given, its whole tree is staged as the kit's files/ dir — the
# sbx-kits-contrib convention where everything under files/home is mirrored into
# /home/agent/ in the sandbox. That's how demo runbooks ship without being
# hard-coded into spec.yaml: drop a *.py in files/home/runbooks/, no spec edit.
#
# The canonical files/ tree lives at the repo root, so `sbx run --kit ./` picks
# it up directly for local testing. The :dmr tag reuses that same root tree
# (it mirrors the root kit). :openai/:gemini ship no files/ until a
# provider-specific runbook exists — travel.py is wired to the local DMR.
publish() {
  local spec_dir="$1" image_tag="$2" readme="$3" files_dir="${4:-}"
  local stage
  stage="$(mktemp -d /tmp/mem0-kits-push.XXXXXX)"
  mkdir -p "$stage/mem0"
  cp "$spec_dir/spec.yaml" "$stage/mem0/spec.yaml"
  cp "$readme" "$stage/mem0/README.md"
  cp "$repo_root/LICENSE" "$stage/mem0/LICENSE"
  if [ -n "$files_dir" ] && [ -d "$files_dir" ]; then
    cp -R "$files_dir" "$stage/mem0/files"
  fi
  sbx kit validate "$stage/mem0"
  sbx kit push "$stage/mem0" "$image:$image_tag"
  rm -rf "$stage"
  echo "Pushed $image:$image_tag"
}

# Default kit (DMR) at the repo root -> :$tag (default :latest), with the
# canonical files/ tree (runbooks).
publish "$repo_root" "$tag" "$repo_root/README.md" "$repo_root/files"

# Per-provider kits under kits/ -> :<provider> (e.g. :dmr, :openai, :gemini).
# Each tag uses its provider doc as the image README. Those docs use repo-relative
# links (e.g. ../kits/openai); fine on GitHub, cosmetic-only on the Hub page.
for dir in "$repo_root"/kits/*/; do
  provider="$(basename "$dir")"
  readme="$repo_root/providers/$provider.md"
  [ -f "$readme" ] || readme="$repo_root/README.md"
  # :dmr mirrors the root kit, so it reuses the root files/ tree. Other
  # providers ship their own files/ if present, else none.
  if [ "$provider" = "dmr" ]; then
    publish "$dir" "$provider" "$readme" "$repo_root/files"
  else
    publish "$dir" "$provider" "$readme" "$dir/files"
  fi
done
