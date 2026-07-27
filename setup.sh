#!/usr/bin/env bash
set -euo pipefail

template_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_dir="$(dirname -- "$template_dir")"
argent_dir="${ARGENT_TEMPLATE_ARGENT_DIR:-"$workspace_dir/argent"}"
expected_revision="$(tr -d '[:space:]' < "$template_dir/.argent-revision")"

if [[ ! -d "$argent_dir/.git" ]]; then
    if [[ -e "$argent_dir" ]]; then
        echo "error: $argent_dir exists but is not an Argent Git checkout" >&2
        exit 1
    fi

    echo "cloning Argent into $argent_dir"
    git clone https://github.com/argent-lang/argent "$argent_dir"
    git -C "$argent_dir" checkout --detach "$expected_revision"
fi

current_revision="$(git -C "$argent_dir" rev-parse HEAD)"
if [[ "$current_revision" != "$expected_revision" ]]; then
    echo "error: incompatible Argent checkout" >&2
    echo "expected: $expected_revision" >&2
    echo "found:    $current_revision" >&2
    echo "use ARGENT_TEMPLATE_ARGENT_DIR to select a compatible checkout" >&2
    exit 1
fi

cd -- "$template_dir"

echo "building the template"
cargo build

echo "running the smoke demo"
cargo run --quiet --bin counter

echo "Argent template is ready"
