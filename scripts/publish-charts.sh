#!/bin/bash
# Build benchmark charts and publish them to the `docs` branch under a *versioned*
# directory: charts/v<package.json version>/. The README's <img> tags pin to that
# path, so each release's README shows a frozen chart set (regenerating a later
# version never rewrites an older README's images).
#
# Adapted from json-as/scripts/publish-benchmarks.sh (worktree -> docs branch).
#
# Usage:
#   ./scripts/publish-charts.sh [--no-run] [--v8|--wavm|--wasmtime|--wazero ...]
#     --no-run   reuse existing build/logs instead of re-running benches
#     runtime    one or more; defaults to --v8 (matches the README perf table)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE_NAME="${REMOTE_NAME:-origin}"
DOCS_BRANCH="${DOCS_BRANCH:-docs}"
VERSION="$(node -p "require('./package.json').version")"
RUN_BENCHES=1
RT_ARGS=()
TMP_CHARTS_DIR="$(mktemp -d)"
TMP_DOCS_DIR="$(mktemp -d)"
WORKTREE_ADDED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-run) RUN_BENCHES=0; shift ;;
    --v8|--wavm|--llvm|--wasmtime|--wazero) RT_ARGS+=("$1"); shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/publish-charts.sh [--no-run] [--v8|--wavm|--wasmtime|--wazero]"
      exit 1
      ;;
  esac
done
# Default runtime: V8 (the README perf table + embedded charts are node/V8).
[[ ${#RT_ARGS[@]} -eq 0 ]] && RT_ARGS=(--v8)

cleanup() {
  rm -rf "$TMP_CHARTS_DIR"
  if [[ "$WORKTREE_ADDED" == "1" ]]; then
    git worktree remove --force "$TMP_DOCS_DIR" >/dev/null 2>&1 || true
  else
    rm -rf "$TMP_DOCS_DIR"
  fi
}
trap cleanup EXIT

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Refusing to publish with a dirty tracked working tree. Commit or stash first."
  exit 1
fi

if [[ "$RUN_BENCHES" == "1" ]]; then
  for rt in "${RT_ARGS[@]}"; do
    echo "Running benchmarks ($rt)..."
    bash ./scripts/run-bench.sh "$rt"
  done
else
  echo "Skipping benchmark runs. Reusing existing logs."
fi

echo "Building charts (${RT_ARGS[*]})..."
for rt in "${RT_ARGS[@]}"; do
  bash ./scripts/build-charts.sh "$rt"
done
test -d ./charts
compgen -G "./charts/*.png" > /dev/null
cp -R ./charts/. "$TMP_CHARTS_DIR/"

echo "Preparing ${DOCS_BRANCH} worktree..."
git fetch "$REMOTE_NAME" "$DOCS_BRANCH" >/dev/null 2>&1 || true
if git show-ref --verify --quiet "refs/remotes/${REMOTE_NAME}/${DOCS_BRANCH}"; then
  git worktree add --detach "$TMP_DOCS_DIR" "refs/remotes/${REMOTE_NAME}/${DOCS_BRANCH}" >/dev/null
  WORKTREE_ADDED=1
  ( cd "$TMP_DOCS_DIR"; git checkout -B "$DOCS_BRANCH" >/dev/null )
else
  git worktree add --detach "$TMP_DOCS_DIR" >/dev/null
  WORKTREE_ADDED=1
  ( cd "$TMP_DOCS_DIR"; git checkout --orphan "$DOCS_BRANCH" >/dev/null; git rm -rf . >/dev/null 2>&1 || true )
fi

echo "Updating charts/v${VERSION} on ${DOCS_BRANCH}..."
rm -rf "$TMP_DOCS_DIR/charts/v${VERSION}"
mkdir -p "$TMP_DOCS_DIR/charts/v${VERSION}"
cp -R "$TMP_CHARTS_DIR/." "$TMP_DOCS_DIR/charts/v${VERSION}/"

(
  cd "$TMP_DOCS_DIR"
  git add "charts/v${VERSION}"
  if git diff --cached --quiet; then
    echo "No chart changes to publish for v${VERSION}."
    exit 0
  fi
  git config user.name "${GIT_AUTHOR_NAME:-$(git config --get user.name || echo zmij-as)}"
  git config user.email "${GIT_AUTHOR_EMAIL:-$(git config --get user.email || echo zmij-as@example.com)}"
  git commit -m "Update benchmark charts for v${VERSION} [skip ci]" >/dev/null
  git push "$REMOTE_NAME" "$DOCS_BRANCH"
)

# Re-pin the README's chart <img> URLs to the version just published, so the
# baked-in charts always match this release. Leaves the edit uncommitted for review.
echo "Pinning README chart URLs to v${VERSION}..."
sed -i -E "s#(/docs/charts/)v[0-9]+\.[0-9]+\.[0-9]+/#\1v${VERSION}/#g" README.md

echo "Charts published to ${REMOTE_NAME}/${DOCS_BRANCH}:charts/v${VERSION}/"
echo "README pinned to https://raw.githubusercontent.com/JairusSW/zmij-as/refs/heads/docs/charts/v${VERSION}/"
