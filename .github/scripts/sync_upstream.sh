#!/usr/bin/env bash
set -e

echo "=== Checking Upstream Release ==="
UPSTREAM_TAG=$(gh api repos/RyanYuuki/AnymeX/releases/latest --jq '.tag_name' 2>/dev/null || echo "")
echo "Upstream latest tag: $UPSTREAM_TAG"

FORK_TAG=$(gh api repos/${GITHUB_REPOSITORY}/releases/latest --jq '.tag_name' 2>/dev/null || echo "")
echo "Fork latest tag: $FORK_TAG"

if [ -z "$UPSTREAM_TAG" ]; then
  echo "Error: Could not determine upstream release tag."
  exit 1
fi

if [ "$UPSTREAM_TAG" = "$FORK_TAG" ]; then
  echo "Fork is already up to date with upstream release ($FORK_TAG)."
  exit 0
fi

echo "New upstream release detected: $UPSTREAM_TAG (current fork tag: $FORK_TAG)"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

echo "Adding upstream remote..."
git remote add upstream https://github.com/RyanYuuki/AnymeX.git || true
git fetch upstream --tags

echo "Checking out main branch..."
git checkout main
git pull origin main

echo "Attempting to merge upstream tag $UPSTREAM_TAG into main..."
if git merge --no-edit "$UPSTREAM_TAG" -m "chore: sync upstream release $UPSTREAM_TAG"; then
  echo "Merge successful! Pushing changes to fork..."
  git push origin main
  git push origin "$UPSTREAM_TAG" || true

  echo "Triggering build and release workflow..."
  gh workflow run "Build and Release AnymeX (Android)" --ref "$UPSTREAM_TAG" || true
else
  echo "Merge conflict detected!"
  git merge --abort || true

  gh issue create \
    --title "Sync conflict with upstream release $UPSTREAM_TAG" \
    --body "Automated sync encountered a merge conflict with upstream release **$UPSTREAM_TAG**.

Please resolve manually on your machine:
\`\`\`bash
git fetch upstream --tags
git checkout main
git merge $UPSTREAM_TAG
# Resolve conflicts in your editor
git commit -m \"chore: resolve merge conflicts with upstream $UPSTREAM_TAG\"
git push origin main
git push origin $UPSTREAM_TAG
\`\`\`"
  exit 1
fi
