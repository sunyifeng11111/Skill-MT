#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$REPO_ROOT/Skill-MT.xcodeproj/project.pbxproj"

TAG="${GIT_TAG:-}"
if [[ -z "$TAG" ]]; then
  TAG="$(git -C "$REPO_ROOT" describe --tags --exact-match 2>/dev/null || true)"
fi

if [[ -z "$TAG" ]]; then
  echo "No git tag found (set GIT_TAG or build from tagged commit)."
  exit 1
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Tag must match vX.Y.Z, got: $TAG"
  exit 1
fi

TAG_VERSION="${TAG#v}"
PROJECT_VERSION="$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/')"

if [[ "$TAG_VERSION" != "$PROJECT_VERSION" ]]; then
  echo "Version mismatch: tag=$TAG_VERSION project=$PROJECT_VERSION"
  exit 1
fi

echo "Version check passed: $TAG_VERSION"
