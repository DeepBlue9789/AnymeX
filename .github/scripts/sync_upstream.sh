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
  if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    echo "### ℹ️ Fork is up to date" >> "$GITHUB_STEP_SUMMARY"
    echo "Fork is currently on the latest release: \`$FORK_TAG\`." >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi

echo "New upstream release detected: $UPSTREAM_TAG (current fork tag: $FORK_TAG)"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

echo "Adding upstream remote..."
git remote add upstream https://github.com/RyanYuuki/AnymeX.git || true
git fetch upstream --tags --force

echo "Checking out main branch..."
git checkout main
git pull origin main

echo "Attempting to merge upstream tag $UPSTREAM_TAG into main..."
if git merge --no-edit "$UPSTREAM_TAG" -m "chore: sync upstream release $UPSTREAM_TAG"; then
  echo "Merge successful! Pushing changes to fork..."
  git push origin main
  git push origin "$UPSTREAM_TAG" || true

  echo "Triggering build and release workflow..."
  gh workflow run build.yml --ref "$UPSTREAM_TAG" || true

  if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    echo "### ✅ Successfully Synced Upstream Release \`$UPSTREAM_TAG\`" >> "$GITHUB_STEP_SUMMARY"
    echo "Pushed tag \`$UPSTREAM_TAG\` and triggered Android build." >> "$GITHUB_STEP_SUMMARY"
  fi
else
  echo "Merge conflict detected!"
  git merge --abort || true

  if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    cat >> "$GITHUB_STEP_SUMMARY" << EOF
### ⚠️ Merge Conflict with Upstream Release \`$UPSTREAM_TAG\`

An automated sync was attempted with upstream release **\`$UPSTREAM_TAG\`**, but encountered merge conflicts due to upstream code restructuring.

#### To resolve manually on your machine:
\`\`\`bash
git fetch upstream --tags
git checkout main
git merge $UPSTREAM_TAG
# Resolve conflicts in your editor
git commit -m "chore: resolve merge conflicts with upstream $UPSTREAM_TAG"
git push origin main
git push origin $UPSTREAM_TAG
\`\`\`
EOF
  fi

  # Create an issue on the fork using GitHub REST API
  gh api repos/${GITHUB_REPOSITORY}/issues \
    -f title="⚠️ Sync conflict with upstream release $UPSTREAM_TAG" \
    -f body="Automated sync encountered a merge conflict with upstream release **$UPSTREAM_TAG**.

Please resolve manually on your machine:
\`\`\`bash
git fetch upstream --tags
git checkout main
git merge $UPSTREAM_TAG
# Resolve conflicts in your editor
git commit -m \"chore: resolve merge conflicts with upstream $UPSTREAM_TAG\"
git push origin main
git push origin $UPSTREAM_TAG
\`\`\`" || true

  exit 1
fi
