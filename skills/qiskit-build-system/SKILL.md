---
name: qiskit-build-system
description: Cheat-sheet for the Qiskit build pipeline — PEP 517 with `setuptools-rust==1.12.0` (hard pin), the `pip install .` (release) vs `pip install -e .` (debug) profile rule, `QISKIT_BUILD_PROFILE` / `QISKIT_BUILD_WITH_MIMALLOC` / `QISKIT_NO_CACHE_GATES` env knobs, MSRV 1.87 mirrored across four files, and the `make c` / `make ctest` / `make coverage` Makefile targets. Use whenever the user is debugging a Qiskit build, asks why an editable install is slow, bumps the MSRV, or needs to build the C library.
---

# Qiskit build system

## Build backend

- PEP 517 with `setuptools.build_meta` (`pyproject.toml:10`).
- Build requires `setuptools>=77.0` and **`setuptools-rust==1.12.0`** (hard pin, lines 3-9). The pin exists because `setup.py` monkeypatches `setuptools-rust` internals to copy generated artifacts (`include/`, `_ctypes.py`) into the `qiskit.capi` package. The pin will loosen once `setuptools-rust` PR #574 ships (`setup.py:20-96`).
- Python support: 3.10–3.14 (`pyproject.toml:15`).

## Build profile rules (the #1 confusing thing)

`setup.py:113-164` decides debug vs release:

| Command | Profile | Why |
|---|---|---|
| `pip install .` | **release** | One-shot install; user wants speed |
| `pip install -e .` | **debug** | Editable; expected to recompile often |
| `QISKIT_BUILD_PROFILE=release pip install -e .` | release | Override |
| `python setup.py build_rust --inplace --release` | release | Manual recompile |

If the user says "editable install runtime is slow", the answer is: it's a debug build by default. Set `QISKIT_BUILD_PROFILE=release` or run `python setup.py build_rust --inplace --release`.

## Compile-time env knobs

| Variable | Effect | Source |
|---|---|---|
| `QISKIT_BUILD_PROFILE` | force `debug` / `release` Rust build | `setup.py:113` |
| `QISKIT_BUILD_WITH_MIMALLOC=1` | link mimalloc allocator (faster) | `setup.py:138-139`; reno `mimalloc-403d3300aa698fae.yaml` |
| `QISKIT_NO_CACHE_GATES=1` | disable Python gate-object caching (debugging) | `setup.py:133-136` |

## Rust workspace

- 16 workspace members (`Cargo.toml:2`).
- Workspace-shared dependencies live under `[workspace.dependencies]` (`Cargo.toml:16-69`): `numpy = "0.28"`, `pyo3 = "0.28.3"`, `rayon`, `ndarray`, etc.
- **MSRV: Rust 1.87** — pinned in **four** locations that must stay in sync (§4.5, **Mandatory**):
  1. `Cargo.toml` (`rust-version = "1.87"`)
  2. `rust-toolchain.toml`
  3. `tools/install_rust_msrv.sh`
  4. `README.md`
  Bumping MSRV adds a reno entry (e.g. `releasenotes/notes/msrv-187-fe3d9818f5c4103d.yaml`).
- Workspace lints (`Cargo.toml:71-86`): clippy `deny`s `print_stdout`, `print_stderr`, `unsafe_op_in_unsafe_fn`. Allows `comparison-chain`.

## C API targets (Makefile)

| Target | Purpose | Source |
|---|---|---|
| `make c` | header + standalone C library | `Makefile:154-165` |
| `make clib` / `make clib-dev` | release / debug C library | `Makefile:159-162` |
| `make ctest` | C-API CMake test suite | `Makefile:167-181` |
| `make cformat` / `make fix_cformat` | clang-format check / auto-fix | `Makefile:127-130` |
| `make coverage` | LCOV coverage on the `qiskit` package | tox-driven |

## Lockfile policy

- `Cargo.lock` is **tracked** and validated in lint (#15839 added the currency check).
- `uv.lock` is tracked at repo root for dev convenience; `uv` itself is not mandated.
- No pip-tools-style Python lock; `constraints.txt` covers CI pins.

## `constraints.txt` (CI-only)

`constraints.txt`:

- `scipy < 1.11` for Python < 3.12 (eigenvalue stability).
- `z3-solver==4.12.2.0` on macOS.
- `pydot >= 4.0.0` (test-output compat).
- `snowballstemmer < 3.0.0` (Sphinx compat).

These are **CI-only** pins — they don't appear in `requirements.txt` and aren't user-facing. Each entry is a workaround for a specific upstream issue (§11.10.4, **Preferred**: only pin when forced).

## Common build problems

### "setuptools-rust missing patches"

The hard pin to `setuptools-rust==1.12.0` (`pyproject.toml:3-9`) is load-bearing. If a contributor relaxes it to `>=1.12.0`, the monkeypatched copy of generated artifacts breaks.

### "MSRV bump didn't update everything"

The four locations in §4.5 must all change. Use `grep -r "1.87" Cargo.toml rust-toolchain.toml tools/install_rust_msrv.sh README.md` to verify.

### "QPY tests fail after Rust change"

`qpy.yml` is a separate workflow. Run `tox -erust` and `cargo test -p qiskit-qpy` locally; QPY round-trip uses fixtures in `test/qpy_compat/`. See [[qiskit-qpy-compatibility]].

### "Image tests fail after a visualization change"

Snapshot-based; baselines under `test/ipynb/mpl/`. Regenerate locally and visually inspect (§11.5.5).

### "C tests don't see the library"

`make clib` builds the standalone C library; `make ctest` builds and runs the CMake test suite. Both depend on `make c` having generated headers.

## Heuristics

- **For development**: use `pip install -e .` (debug) for fast rebuilds; switch to release with `QISKIT_BUILD_PROFILE=release` when measuring runtime or running benchmarks.
- **For benchmarking**: never use a debug build. ASV must run release.
- **For MSRV**: don't bump unless a feature genuinely requires it; the bump is a coordinated event with a reno entry.
- **For mimalloc**: opt-in only. Don't enable in CI; users opt in when they want the perf win.

## Related skills

- [[qiskit-py-rust-bridge]] — single-cdylib mechanics, `sys.modules` registration.
- [[qiskit-testing]] — how to run the test suites the build feeds.
- [[qiskit-dependency-policy]] — when to add to `[workspace.dependencies]` vs `constraints.txt`.
- [[qiskit-ci-workflows]] — which workflow corresponds to which build target.
