# Argent template

A minimal starting point for writing an [Argent](https://github.com/michaelsutton/argent) application and building a
transaction against its generated artifact.

## Quick start

The setup keeps Argent and this repository as sibling checkouts:

```text
kaspanet/
  argent/
  argent-template/
```

Clone the template and let the setup script fetch the compatible Argent revision if it is not already present:

```bash
git clone https://github.com/michaelsutton/argent-template
cd argent-template
./setup.sh
```

If `../argent` already exists, `setup.sh` verifies that it is at the revision recorded in `.argent-revision`. The setup
also builds the Rust dependencies and runs the included smoke demo, so later runs are fast.

Open the directory and start with:

- `ag/counter.ag` — the Argent application;
- `src/bin/counter.rs` — transaction construction using the generated artifact;
- `src/lib.rs` — deterministic local-demo fixtures.

Run the starter application:

```bash
cargo run
```

Each additional application can have its own file under `src/bin/` and build output directory. Run a specific application
with `cargo run --bin <name>`.

Run all local checks on macOS or Linux:

```bash
./check.sh
```

On Windows, use the CMD launchers from Command Prompt or PowerShell:

```text
setup.cmd
check.cmd
```

The launchers invoke the matching `setup.ps1` and `check.ps1` scripts without requiring a permanent PowerShell
execution-policy change.

The included Counter is intentionally disposable. Replace it with your own actors and states while keeping the small
build-and-run loop.

## Scope

This repository builds and executes transactions in Argent's local runtime. It does not connect to a Kaspa network,
manage a wallet, or submit transactions.
