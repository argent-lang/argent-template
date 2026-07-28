#!/usr/bin/env bash
set -euo pipefail

template_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_dir="$(dirname -- "$template_dir")"
argent_dir="${ARGENT_TEMPLATE_ARGENT_DIR:-"$workspace_dir/argent"}"

if [[ -e "$argent_dir" ]]; then
    if [[ "$(git -C "$argent_dir" rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]]; then
        echo "error: $argent_dir exists but is not an Argent Git checkout" >&2
        exit 1
    fi
else
    echo "cloning Argent into $argent_dir"
    git clone --branch master https://github.com/argent-lang/argent "$argent_dir"
fi

print_relation() {
    local label="$1"
    local ref="$2"
    local revision
    local ahead
    local behind

    revision="$(git -C "$argent_dir" rev-parse "$ref")"
    read -r ahead behind < <(git -C "$argent_dir" rev-list --left-right --count "HEAD...$ref")
    echo "$label: $revision (HEAD ahead $ahead, behind $behind)"
}

echo "using Argent checkout at $argent_dir"
echo "HEAD: $(git -C "$argent_dir" rev-parse HEAD)"
if branch="$(git -C "$argent_dir" symbolic-ref --quiet --short HEAD)"; then
    echo "branch: $branch"
else
    echo "branch: detached"
fi
if upstream="$(git -C "$argent_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    print_relation "upstream $upstream" "$upstream"
else
    echo "upstream: none"
fi
if git -C "$argent_dir" show-ref --verify --quiet refs/heads/master; then
    print_relation "local master" refs/heads/master
else
    echo "local master: absent"
fi
if git -C "$argent_dir" show-ref --verify --quiet refs/remotes/origin/master; then
    print_relation "recorded origin/master" refs/remotes/origin/master
    if origin_url="$(git -C "$argent_dir" remote get-url origin 2>/dev/null)"; then
        echo "origin: $origin_url"
    else
        echo "origin: not configured"
    fi
    echo "note: setup does not fetch or update an existing checkout"
else
    echo "recorded origin/master: absent"
fi
if [[ -n "$(git -C "$argent_dir" status --porcelain)" ]]; then
    echo "working tree: has local changes"
else
    echo "working tree: clean"
fi

cd -- "$template_dir"

echo "building the template"
cargo build

echo "running the smoke demo"
cargo run --quiet --bin counter

echo "Argent template is ready"
