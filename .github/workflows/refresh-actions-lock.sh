#!/usr/bin/env bash

set -Eeuo pipefail

readonly EXTENSION_VERSION=${FAFOTHON_ACTIONS_LOCK_VERSION:-v0.4.1}

if [[ -n $(git status --porcelain=v1 --untracked-files=all) ]]; then
    echo "The worktree must be clean before refreshing the Actions lockfile." >&2
    git status --short >&2
    exit 1
fi

gh extension install github/gh-actions-lock --pin "$EXTENSION_VERSION"
gh actions-lock
gh actions-lock --verify

declare -a unexpected_paths=()
while IFS= read -r -d '' path; do
    case $path in
        .github/workflows/actions.lock | \
        .github/workflows/*.yml | \
        .github/workflows/*.yaml)
            ;;
        *)
            unexpected_paths+=("$path")
            ;;
    esac
done < <(
    git diff --name-only -z -- .
    git ls-files --others --exclude-standard -z
)

if (( ${#unexpected_paths[@]} )); then
    echo "Refreshing the Actions lockfile changed unexpected files:" >&2
    printf '%s\n' "${unexpected_paths[@]}" >&2
    exit 1
fi

# The generator may update workflow references together with actions.lock.
git add -- .github/workflows
git diff --cached --check
if ! git diff --cached --quiet; then
    git -c commit.gpgsign=false commit \
        -m "Refresh GitHub Actions lockfile after upstream sync"
fi

if [[ -n $(git status --porcelain=v1 --untracked-files=all) ]]; then
    echo "The worktree is dirty after refreshing the Actions lockfile." >&2
    git status --short >&2
    exit 1
fi
