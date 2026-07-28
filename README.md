# Argent template

A minimal starting point for writing an [Argent](https://github.com/argent-lang/argent) application and building a
transaction against its generated artifact.

## Quick start

The setup keeps Argent and this repository as sibling checkouts:

```text
kaspanet/
  argent/
  argent-template/
```

Clone the template and let the setup script clone Argent's current `master` if it is not already present:

```bash
git clone https://github.com/argent-lang/argent-template
cd argent-template
./setup
```

If `../argent` already exists, `setup` uses it without fetching, switching, or pulling it. The script reports the
checkout's revision, branch, upstream relationship, local `master`, recorded `origin/master`, and working-tree state.
The setup also builds the Rust dependencies and runs the included smoke demo, so later runs are fast.

### VS Code extension

Optionally link the VS Code extension from the Argent checkout into your user extensions:

```bash
./setup --vscode-ext
```

The link follows updates to the local Argent checkout. Reload VS Code after installation; the extension activates when
an `.ag` file is opened. This mode installs only the extension; it does not build the template or run the smoke demo.

To uninstall the linked extension, fully exit VS Code first and run:

```bash
./setup --uninstall-vscode-ext
```

This removes only the symlink or junction and leaves the Argent checkout unchanged. Do not uninstall this linked
development extension through VS Code's Extensions view.

### Build and run

Open the directory and start with:

- `ag/counter.ag` — the Argent application;
- `src/bin/counter.rs` — transaction construction using the generated artifact;
- `src/lib.rs` — deterministic local-demo fixtures.

Build the Argent source manually or inspect its generated artifact through the local compiler wrapper:

```bash
./argentc build ag/counter.ag
./argentc inspect build/argent
```

Run the starter application:

```bash
cargo run
```

Each additional application can have its own file under `src/bin/` and build output directory. Run a specific application
with `cargo run --bin <name>`.

Run all local checks:

```bash
./check
```

The included Counter is intentionally disposable. Replace it with your own actors and states while keeping the small
build-and-run loop.

## Scope

This repository builds and executes transactions in Argent's local runtime. It does not connect to a Kaspa network,
manage a wallet, or submit transactions.
