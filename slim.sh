#!/bin/bash
set -euo pipefail

# --- CONFIG ---
SOURCE_REPO="https://github.com/soto-project/soto.git"
TARGET_REPO="https://github.com/ltetzlaff/soto-slim.git"
START_COMMIT="1f7fd0f"
TEMP_DIR="soto-temp"
CLEAN_DIR="soto-slim"

# --- CLEANUP ---
rm -rf "$TEMP_DIR" "$CLEAN_DIR"

# --- Clone original repo ---
git clone "$SOURCE_REPO" "$TEMP_DIR"
cd "$TEMP_DIR"

# Make sure full history and refs are available
git fetch --unshallow || true
git fetch origin main --tags

# Checkout base commit
git checkout "$START_COMMIT"

# Get commits AFTER base
COMMITS=$(git rev-list --reverse "${START_COMMIT}..origin/main")

# --- Create clean repo ---
cd ..
mkdir "$CLEAN_DIR"
cd "$CLEAN_DIR"
git init
git checkout --orphan main

# --- Copy working tree WITHOUT .git ---
rsync -a --exclude=".git" ../"$TEMP_DIR"/ ./

# --- First commit (clean root) ---
git add .
git commit -m "New root: state from $START_COMMIT"

# --- Add original as remote for cherry-picking ---
git remote add source "../$TEMP_DIR"
git fetch source main

# --- Cherry-pick all later commits ---
for commit in $COMMITS; do
  echo "Cherry-picking $commit"
  git cherry-pick "$commit" || {
    echo "⚠️ Conflict at $commit"
    exit 1
  }
done

# --- Final cleanup ---
git reflog expire --expire=now --all
git gc --aggressive --prune=now

# --- Push to clean repo ---
git remote add origin "$TARGET_REPO"
git push -u origin main --force

echo "✅ Done: slim repo pushed to $TARGET_REPO"
