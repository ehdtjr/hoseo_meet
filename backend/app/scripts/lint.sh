#!/usr/bin/env bash

set -e 
set -x

# 프로젝트 루트 디렉토리로 이동
cd "$(dirname "$0")/../.."

CHANGES_FILE="./detailed_lint_changes.txt"
> $CHANGES_FILE

mypy app

echo -e "\n=== Ruff Check: Initial Issues ===" >> $CHANGES_FILE
ruff check . --show-fixes >> $CHANGES_FILE 2>&1 || true

echo -e "\n=== Ruff Check: Applying Fixes ===" >> $CHANGES_FILE
ruff check --fix . >> $CHANGES_FILE 2>&1 || true

echo -e "\n=== Ruff Check: Remaining Issues ===" >> $CHANGES_FILE
ruff check . >> $CHANGES_FILE 2>&1 || true

echo -e "\n=== Ruff Format: Proposed Changes ===" >> $CHANGES_FILE
ruff format --diff . >> $CHANGES_FILE 2>&1 || true

echo -e "\n=== Ruff Format: Applying Changes ===" >> $CHANGES_FILE
ruff format . >> $CHANGES_FILE 2>&1 || true

echo -e "\n=== Ruff Format: Verification ===" >> $CHANGES_FILE
ruff format --check . >> $CHANGES_FILE 2>&1 || true

echo "Detailed lint changes have been saved to $CHANGES_FILE"
cat $CHANGES_FILE