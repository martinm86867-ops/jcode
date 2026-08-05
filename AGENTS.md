# Repository Guidelines

## Development Workflow

- **Stay on your own branch** - Do not take, cherry-pick, merge, or copy code from other
  people's or other agents' branches. Only work from your branch and its base (e.g. `main`).
  If you need something that lives on another branch, tell the user and let them decide;
  never pull it in yourself.
- **First-time setup** - Run `scripts/setup.sh` to install Linux system dependencies (fontconfig, clang, mold, lld) and verify the Rust stable toolchain. Use `--check` to verify without installing.
- **Commit as you go** - Make small, focused commits after completing each feature or fix
- If the git state is not clean, or there are other agents working in the codebase in parallel, do your best to still commit your work. 
- **Push when done** - Push all commits to remote when finishing a task or session
- **Run the guardrails before pushing** - `scripts/check_guardrails.sh` runs every gate in
  CI's Format + Quality Guardrails jobs (fmt, clippy `-D warnings`, and the warning,
  code-size, test-size, panic, swallowed-error, dependency-boundary, and wildcard-reexport
  ratchets). Use `--skip-slow` to skip cargo check/clippy, and `--fix` to rustfmt and
  rebaseline ratchets after intentional growth. CI tracks the `stable` toolchain, so run
  `rustup update stable` too: a stale local clippy passes on lints that CI enforces.
- **Use fast iteration by default** - Prefer `cargo check`, targeted tests, and dev builds while iterating
- **Rebuild when done** - When you are done making changes, build the source.
- **Bump version for releases** - Update version in `Cargo.toml` when making releases. When cutting a new release, look at all the changes that happened since the last release and determine what the version bump should be ie patch or minor, etc. 
- **Remote builds available** - Use `scripts/remote_build.sh` to offload heavy cargo work to another machine. If your build is terminated, likely is because there are not enough resources on this machine to build. use remote build in that case. Try checking the resource avaliablity on the machine before you run a build. 

## Crate Routing

See [docs/CRATE_OWNERSHIP_BOUNDARIES.md](docs/CRATE_OWNERSHIP_BOUNDARIES.md) for crate boundaries, ownership rules, and the move checklist.

| Crate group | CI test cohort / check route |
| --- | --- |
| Providers (`jcode-provider-*`) | `provider_matrix` integration tests (Build & Test job) |
| TUI (`jcode-tui-*`) | `jcode-tui --lib` serial cohort (Build & Test, Linux) |
| Desktop (`jcode-desktop2`) | `profile::` frame-budget tests (Quality Guardrails job) |
| Core (`jcode-core`, `jcode-app-core`, `jcode-base`) | `retention_readiness`, `secret_input`, `test_stdin_forwarding` cohorts + `--lib --bins` compile (Build & Test) |
| Type crates (`jcode-*-types`) | dependency-boundary ratchet (Quality Guardrails) + focused `cargo check` per CRATE_OWNERSHIP_BOUNDARIES.md |

Delivery policy: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Logs
- Logs are written to `~/.jcode/logs/` (daily files like `jcode-YYYY-MM-DD.log`).

## Debug Socket
- Use the debug socket for runtime level debugging

## Install Notes
- `~/.local/bin/jcode` is the launcher symlink used from `PATH`.
- `~/.jcode/builds/current/jcode` is the active local/source-build channel; self-dev builds and `scripts/install_release.sh` point the launcher here.
- `~/.jcode/builds/stable/jcode` is the stable release channel; `scripts/install.sh` installs this and points the launcher here.
- `~/.jcode/builds/versions/<version>/jcode` stores immutable binaries.
- `~/.jcode/builds/canary/jcode` still exists for canary/testing flows, but it is not the primary self-dev install path.
- On Windows, the equivalents are `%LOCALAPPDATA%\\jcode\\bin\\jcode.exe` for the launcher, `%LOCALAPPDATA%\\jcode\\builds\\stable\\jcode.exe` for stable, and `%LOCALAPPDATA%\\jcode\\builds\\versions\\<version>\\jcode.exe` for immutable installs; `scripts/install.ps1` currently installs the stable channel.
- Ensure `~/.local/bin` is **before** `~/.cargo/bin` in `PATH`.

## Verifying a change at runtime

`cargo build` alone proves nothing about behavior. `jcode run` and interactive
sessions are served by the long-lived daemon at
`~/.jcode/builds/shared-server/jcode`, which is a symlink into
`~/.jcode/builds/versions/<version>/`. Until that symlink is repointed and the
daemon restarted (`jcode self-dev --build`), a freshly built binary is inert and
every runtime check silently measures the old code.

To test a change without disturbing the shared daemon or the caller's session,
run your build against its own socket:

```bash
cargo build --profile selfdev
./target/selfdev/jcode run --no-update --socket /run/user/1000/jcode-mytest.sock '<prompt>'
```

Two things that waste time otherwise:

- `crate::logging::info` writes to a log file, not stderr, so instrumenting a
  code path with it produces no visible output under `--trace`. Use `eprintln!`
  for throwaway diagnostics and delete it before committing.
- Confirm which binary you are actually inspecting. `strings` on
  `builds/shared-server/jcode` reads a 70-byte symlink, not a program; resolve it
  with `readlink -f` first.