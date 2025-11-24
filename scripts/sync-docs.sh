#!/usr/bin/env bash
# sync-docs.sh
# Bash/WSL helper to synchronize three folders from a source path into the repo:
# - Datos
# - Documentación
# - media
#
# Usage:
#   ./scripts/sync-docs.sh /mnt/d/AVA/Cartografia-Forestal-AVA_source [--push]

set -euo pipefail

SOURCE=${1:-}
PUSH=false
if [[ ${2:-} == "--push" ]]; then PUSH=true; fi

if [[ -z "$SOURCE" ]]; then
  echo "Usage: $0 <SOURCE_PATH> [--push]"
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then echo "git not found"; exit 1; fi
if ! command -v rsync >/dev/null 2>&1; then echo "rsync not found"; exit 1; fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$REPO_ROOT" ]]; then echo "Not in a git repository"; exit 1; fi

cd "$REPO_ROOT"

REMOTE=origin
BRANCH=update/docs-sync

echo "Fetching ${REMOTE}..."
git fetch "$REMOTE" --prune

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Branch $BRANCH exists locally — resetting to $REMOTE/main"
  git checkout "$BRANCH"
  git reset --hard "$REMOTE/main"
else
  echo "Creating branch $BRANCH from $REMOTE/main"
  git checkout -b "$BRANCH" "$REMOTE/main"
fi

rsync -av --delete "$SOURCE/Datos/" "$REPO_ROOT/Datos/"
rsync -av --delete "$SOURCE/Documentación/" "$REPO_ROOT/Documentación/"
rsync -av --delete "$SOURCE/media/" "$REPO_ROOT/media/"

echo "Inspecting git status..."
git status --porcelain

# Restore README and Evaluación if changed accidentally
git restore --source=HEAD -- README.md 2>/dev/null || echo "README.md unchanged or not present in HEAD"
git restore --source=HEAD -- "Evaluación/" 2>/dev/null || echo "Evaluación/ unchanged or not present in HEAD"

echo "Staging only target folders..."
git add --all Datos "Documentación" media

if [[ -z $(git diff --staged --name-only) ]]; then
  echo "No changes staged for Datos/Documentación/media. Exiting."
  exit 0
fi

echo "Staged changes:"
git diff --staged --name-status

MSG="Actualizar Datos, Documentación y media desde $SOURCE (sin modificar README ni Evaluación)"
git commit -m "$MSG"

if [[ "$PUSH" == true ]]; then
  git push -u "$REMOTE" "$BRANCH"
  echo "Push complete. Open a PR from $BRANCH to main if you want review before merging."
else
  echo "Commit created on branch $BRANCH. To push, run: git push -u $REMOTE $BRANCH"
fi
