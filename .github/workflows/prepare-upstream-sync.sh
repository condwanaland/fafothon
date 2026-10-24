#!/usr/bin/env bash

set -Eeuo pipefail

UPSTREAM_URL=${FAFOTHON_UPSTREAM_URL:-https://github.com/python/cpython.git}
UPSTREAM_BRANCH=${FAFOTHON_UPSTREAM_BRANCH:-main}
UPSTREAM_REF=${FAFOTHON_UPSTREAM_REF:-refs/remotes/fafothon-upstream/main}
FORK_REF=${FAFOTHON_FORK_REF:-refs/remotes/origin/main}
WORK_BRANCH=${FAFOTHON_WORK_BRANCH:-sync-upstream-result}
OUTPUT_FILE=${FAFOTHON_OUTPUT:-${GITHUB_OUTPUT:-}}

summary() {
    if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
        printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
    fi
}

fail() {
    printf 'error: %s\n' "$*" >&2
    summary "### Upstream synchronisation failed"
    summary ""
    summary "$*"
    exit 1
}

output() {
    if [[ -n $OUTPUT_FILE ]]; then
        printf '%s=%s\n' "$1" "$2" >> "$OUTPUT_FILE"
    fi
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) ||
    fail "Run this script from a Git worktree."
cd "$repo_root"

if [[ -n $(git status --porcelain=v1 --untracked-files=all) ]]; then
    fail "The worktree must be clean before synchronisation."
fi

git show-ref --verify --quiet "$FORK_REF" ||
    fail "Fork ref $FORK_REF does not exist."

git check-ref-format "refs/heads/$WORK_BRANCH" >/dev/null ||
    fail "Invalid work branch name: $WORK_BRANCH"

if git show-ref --verify --quiet "refs/heads/$WORK_BRANCH"; then
    fail "Work branch $WORK_BRANCH already exists."
fi

printf 'Fetching CPython %s from %s\n' "$UPSTREAM_BRANCH" "$UPSTREAM_URL"
git fetch --no-tags "$UPSTREAM_URL" \
    "+refs/heads/$UPSTREAM_BRANCH:$UPSTREAM_REF"

original_sha=$(git rev-parse "$FORK_REF^{commit}")
upstream_sha=$(git rev-parse "$UPSTREAM_REF^{commit}")

output original_sha "$original_sha"
output upstream_sha "$upstream_sha"

if git merge-base --is-ancestor "$upstream_sha" "$original_sha"; then
    printf 'FAFOthon already contains CPython %s; nothing to do.\n' "$upstream_sha"
    output update_needed false
    summary "### Upstream synchronisation"
    summary ""
    summary "No update was needed. FAFOthon already contains CPython \`$upstream_sha\`."
    exit 0
fi

base_sha=$(git merge-base "$original_sha" "$upstream_sha") ||
    fail "Could not find a common ancestor for FAFOthon and CPython main."
fork_commit_count=$(git rev-list --count "$base_sha..$original_sha")

if [[ -n $(git rev-list --merges "$base_sha..$original_sha") ]]; then
    fail "The FAFOthon-specific range contains merge commits; refusing to flatten them."
fi

output base_sha "$base_sha"
output fork_commit_count "$fork_commit_count"

git switch --create "$WORK_BRANCH" "$original_sha"

if ! GIT_SEQUENCE_EDITOR=: git rebase \
    --reapply-cherry-picks \
    --empty=keep \
    --onto "$upstream_sha" \
    "$base_sha"
then
    {
        printf '\nRebase status:\n'
        git status --short
        printf '\nUnmerged paths:\n'
        git diff --name-only --diff-filter=U
    } >&2
    summary "### Upstream rebase conflict"
    summary ""
    summary "The rebase stopped without publishing anything. Resolve it locally and update the FAFOthon patchset separately."
    exit 1
fi

git merge-base --is-ancestor "$upstream_sha" HEAD ||
    fail "The rebased result does not contain the fetched CPython commit."

rebased_commit_count=$(git rev-list --count "$upstream_sha..HEAD")
if [[ $rebased_commit_count != "$fork_commit_count" ]]; then
    fail "Expected $fork_commit_count FAFOthon commits after rebase; found $rebased_commit_count."
fi

if [[ -n $(git rev-list --merges "$upstream_sha..HEAD") ]]; then
    fail "The rebased FAFOthon range unexpectedly contains a merge commit."
fi

if [[ -n $(git status --porcelain=v1 --untracked-files=all) ]]; then
    fail "The rebase completed with a dirty worktree."
fi

result_sha=$(git rev-parse HEAD)
output result_sha "$result_sha"
output update_needed true

printf '\nRebased %s FAFOthon commit(s) onto CPython %s.\n' \
    "$fork_commit_count" "$upstream_sha"
git log --oneline --reverse "$upstream_sha..HEAD"
printf '\nPatch comparison before and after rebase:\n'
git range-diff "$base_sha..$original_sha" "$upstream_sha..HEAD"

summary "### Upstream rebase prepared"
summary ""
summary "Rebased $fork_commit_count FAFOthon commit(s) from \`$original_sha\` onto CPython \`$upstream_sha\`."
