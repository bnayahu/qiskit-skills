---
name: qiskit-dependency-policy
description: Apply Qiskit's dependency-addition checklist — justify the addition (why isn't `numpy`/`scipy`/`rustworkx` enough?), pick tightest reasonable lower bound, avoid upper bound unless a known break exists, register optional dependencies in `pyproject.toml` extras + `qiskit.utils.optionals`, add Rust crates to `[workspace.dependencies]` not the leaf, refresh `Cargo.lock`, and only add to `constraints.txt` when a specific upstream issue forces it. Use whenever the user wants to add a new Python or Rust dependency, bump a pin, or asks "should I add X?".
---

# Qiskit dependency policy

The principle (§4.1, §11.10): minimal runtime, justify additions, **tooling pinned tight, libraries pinned loose**.

## Runtime requirements (`requirements.txt`)

```
rustworkx >= 0.15.0
numpy >= 1.21, < 3
scipy >= 1.5
dill >= 0.3
stevedore >= 3.0.0
typing-extensions
```

Pattern: **lower bounds loose** (just `>=`); **upper bounds only when a breaking upstream is known** (`numpy < 3`).

## Adding a Python runtime dependency

The implicit checklist (§4.8):

1. **Justify the addition.** One-liner: why isn't `numpy` / `scipy` / `rustworkx` enough? Reviewers will ask, so answer in the PR body.
2. **Tightest reasonable lower bound.** `>=X.Y` where X.Y is the oldest version you've actually tested. Don't go lower.
3. **No upper bound** unless a known break exists. Pre-emptive upper-bounding is not done.
4. **If it's optional, use the optional-deps machinery.** Do NOT add to `requirements.txt`. See [[qiskit-optional-dependencies]] for the lazy-tester wiring. Register the extra in `pyproject.toml:56-81`.
5. **Update `requirements.txt`** for true runtime, not optional.
6. **Don't add to `constraints.txt`** unless a specific CI failure forces it.

## Optional extras (`pyproject.toml:56-81`)

```toml
[project.optional-dependencies]
qasm3-import = ["qiskit-qasm3-import>=0.2.0"]
visualization = [
    "matplotlib>=3.3",
    "pillow>=4.2.1",
    "pylatexenc>=1.4",
    "seaborn>=0.9.0",
    "pydot>=4.0.0",
]
crosstalk-pass = ["z3-solver>=4.7"]
csp-layout-pass = ["python-constraint>=1.4"]
qpy-compat = ["qiskit-terra==0.46.3"]
```

Group related deps under one extra. Don't sprinkle one-dep extras unless they're truly independent.

## Dependency groups (`pyproject.toml:189-269`, PEP 735)

```
[dependency-groups]
build = ["setuptools>=77.0", "setuptools-rust==1.12.0"]
lint = ["ruff==0.15.2", "black[jupyter]~=25.1", "reno>=4.1.0"]
test = ["stestr>=2.0", "ddt>=1.2.0", "coverage>=4.4.0", "threadpoolctl"]
test-random = ["qiskit-aer", "hypothesis>=4.24.3", "ddt"]
doc = ["Sphinx==9.1.0", "docutils==0.22.4", ...]   # requires Python ≥ 3.12
optionals-test = [...]
interactive = [...]
functional = [...]
dev = [...]   # aggregate
```

**Pattern:** **tooling exact-pinned**, **libraries loosely pinned**. Linter/doc-generator versions affect CI behavior, so they're pinned exactly. User-runtime libs use floors.

## Pinning rules summary (§11.10.3, **Mandatory**)

| Kind | Pin |
|---|---|
| `setuptools-rust` | `==1.12.0` (hard pin; `setup.py` monkeypatches it) |
| `ruff`, `black`, `Sphinx`, `docutils` | `==X.Y` exact (CI-affecting) |
| Runtime libs (`numpy`, `scipy`, `rustworkx`) | `>= X.Y` loose |
| `numpy < 3` | upper bound for known-incompatible major |

## Rust dependencies

- **Centralized in `[workspace.dependencies]`** in the root `Cargo.toml:16-69`. Workspace members opt in with `<crate>.workspace = true`.
- Add to the **workspace table**, not the leaf crate's `[dependencies]`. This keeps versions consistent across crates.
- Local-path crates listed alongside external (lines 55-69) so workspace members can `<crate>.workspace = true`.
- `pyo3 = "0.28.3"` with `abi3-py310` (stable ABI).

```toml
# Cargo.toml (root)
[workspace.dependencies]
nalgebra = "0.33"
faer = "0.20"
my-new-crate = "1.2"     # <- new addition
```

```toml
# crates/<member>/Cargo.toml
[dependencies]
my-new-crate.workspace = true
```

After adding, run `cargo build` (or `cargo update -p my-new-crate`) and **commit `Cargo.lock`**. #15839 added a Cargo.lock currency check to lint.

## `constraints.txt` (CI-only)

Each entry is a workaround for a specific known upstream problem (§11.10.4, **Preferred**: only pin when forced):

- `scipy < 1.11` for Python < 3.12 (eigenvalue stability).
- `z3-solver==4.12.2.0` on macOS.
- `pydot >= 4.0.0` (test-output compat).
- `snowballstemmer < 3.0.0` (Sphinx compat).

**Don't add to `constraints.txt`** without a comment explaining the reason, and a CI failure log to back it up.

## Dependency-update workflow

- **Dependabot** opens routine bumps. Recent examples: #16019, #15989, #15952, #15942, #15888, #15889, #16101.
- All Dependabot PRs carry `Changelog: None` and `dependencies` labels.
- Superseded Dependabot PRs are closed in favor of newer ones (e.g. #16056).
- **Major-version Rust crate moves are explicit, hand-authored PRs** (§11.10.6). Examples: scipy → nalgebra/faer in #16016, #15960, #15874, #15881, #15928, #15871.

## Push-back patterns

When someone proposes a new dep, the recurring questions:

- **Why isn't `numpy`/`scipy`/`rustworkx` enough?** State the gap.
- **Is it truly required, or can it be optional?** Default to optional.
- **What's the maintenance burden?** Adding a dep means tracking its breakage forever.
- **Is the upstream stable?** Active project, semver-disciplined, license-compatible (Apache-2.0 ideally).

`tqdm` for progress bars is the canonical "no, don't add it" — Qiskit's logging channels are the established way to report progress.

## Heuristics

- **Default to optional.** If a dep can be optional, make it optional.
- **No `dev`-only deps in `requirements.txt`.** Use `dependency-groups`.
- **Refresh `Cargo.lock` on every `Cargo.toml` change.** The lint check will fail otherwise.
- **For Python deps, run `tox -eminoptional`** before push to confirm the absent-dep path raises cleanly.
- **For Rust deps, the workspace table is canonical.** Don't put a version in a leaf crate.

## Related skills

- [[qiskit-optional-dependencies]] — lazy testers and `MissingOptionalLibraryError`.
- [[qiskit-build-system]] — `Cargo.lock` currency, MSRV.
- [[qiskit-coding-conventions]] — pinning style.
- [[qiskit-rust-performance-idioms]] — when to choose `nalgebra`/`faer` over `scipy`.
