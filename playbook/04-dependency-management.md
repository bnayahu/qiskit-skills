# 4. Dependency Management

## 4.1 Python runtime requirements

`requirements.txt`:

- `rustworkx >= 0.15.0`
- `numpy >= 1.21, < 3`
- `scipy >= 1.5`
- `dill >= 0.3`
- `stevedore >= 3.0.0`
- `typing-extensions`

**Pattern:** lower-bound runtime pins are loose (just `>=`); upper bounds appear only when a
breaking upstream is known (`numpy < 3`).

**Confidence:** High. **Explicit.**

## 4.2 Optional extras

`pyproject.toml:56-81` defines extras:

- `qasm3-import`, `visualization`, `crosstalk-pass`, `csp-layout-pass`, `qpy-compat`.
- Probed at runtime via `qiskit.utils.optionals` lazy testers — code paths that need an
  optional dep import it inside the function and raise `MissingOptionalLibraryError` if absent.

**Confidence:** High. **Explicit.**

## 4.3 Dependency groups

`pyproject.toml:189-269` (PEP 735 `[dependency-groups]`):

| Group | Purpose | Notable pins |
|---|---|---|
| `build` | Build system | `setuptools>=77.0`, `setuptools-rust==1.12.0` (hard pin) |
| `lint` | Linters | `ruff==0.15.2`, `black[jupyter]~=25.1`, `reno>=4.1.0` |
| `test` | Test runtime | `stestr>=2.0`, `ddt>=1.2.0`, `coverage>=4.4.0`, `threadpoolctl` |
| `test-random` | Hypothesis tests | `qiskit-aer`, `hypothesis>=4.24.3`, `ddt` |
| `doc` | Sphinx docs | `Sphinx==9.1.0`, `docutils==0.22.4`, `sphinxcontrib-katex==0.9.9`, `breathe>=4.35.0`; **requires Python ≥ 3.12** |
| `optionals-test` / `interactive` / `functional` | Visualization, etc. | |
| `dev` | Aggregate of all above | |

**Pattern:** **Tooling pinned tightly, libraries pinned loosely.** Linter/doc-generator
versions are exact pins because they affect CI behavior; user-runtime libs use floors.

**Confidence:** High. **Explicit.**

## 4.4 CI constraint file

`constraints.txt`:

- `scipy < 1.11` for Python < 3.12 (eigenvalue stability issue).
- `z3-solver==4.12.2.0` on macOS.
- `pydot >= 4.0.0` (test-output compat).
- `snowballstemmer < 3.0.0` (Sphinx compat).

These are **CI-only constraints**, not user-facing requirements. Reflects an "only pin when
forced" policy: each constraint is a workaround for a specific upstream issue.

**Confidence:** High. **Explicit.**

## 4.5 Rust dependencies

- Centralized in `[workspace.dependencies]` (`Cargo.toml:16-69`).
- Local-path crates listed alongside external (lines 55-69) so workspace members can
  `<crate>.workspace = true`.
- `pyo3 = "0.28.3"` with `abi3-py310`.
- **MSRV: 1.87** — `Cargo.toml:8`, mirrored in `rust-toolchain.toml`,
  `tools/install_rust_msrv.sh`, `README.md`. PRs that bump MSRV add a reno entry (e.g.
  `releasenotes/notes/msrv-187-fe3d9818f5c4103d.yaml`).

**Confidence:** High. **Explicit.**

## 4.6 Lockfile policy

| Lock | Tracked? | Notes |
|---|---|---|
| `Cargo.lock` | **Yes** | Validated in lint job. PR **#15839** added Cargo.lock currency check. |
| `uv.lock` | **Yes** (sits in repo root) | Optional dev convenience; project doesn't mandate `uv`. |
| Python `requirements*.txt` | n/a | No pip-tools-style lock; `constraints.txt` covers CI pins. |

**Confidence:** High. **Explicit** for Cargo.lock; **Inferred** (file exists) for uv.lock.

## 4.7 Dependency-update workflow

- **Dependabot** opens routine bumps. Recent examples: **#16019**, **#15989**, **#15952**,
  **#15942**, **#15888**, **#15889**, **#16101**.
- All carry `Changelog: None` and `dependencies` labels; superseded Dependabot PRs are closed
  in favor of newer ones (e.g. **#16056**).
- Major-version Rust crate moves are explicit, hand-authored PRs (e.g. moves to `nalgebra` /
  `faer` for matrix work in **#16016**, **#15960**, **#15874**, **#15881**, **#15928**,
  **#15871**).

**Confidence:** High. **Inferred** from PR stream.

## 4.8 Adding a dependency — implicit checklist

Reconstructed from PR review behavior:

1. Justify the addition (one-liner: why isn't `numpy`/`scipy`/`rustworkx` enough?).
2. Choose tightest reasonable lower-bound; avoid upper-bound unless a known break exists.
3. If it's optional, add to `pyproject.toml` extras + `qiskit/utils/optionals.py` lazy tester.
4. If it's a Rust crate, add to `[workspace.dependencies]` (not the leaf crate's table) so
   versions stay consistent.
5. Update `Cargo.lock` and ensure lint passes.
6. If it's a CI-only pin, append to `constraints.txt` with a comment explaining the reason.

**Confidence:** Medium. **Inferred.**

## 4.9 Versions are dynamic

- `pyproject.toml` declares `version`, `readme`, `dependencies` as `dynamic` and reads them
  from `qiskit/VERSION.txt` and `requirements.txt` at build time. This makes the version
  bump a one-line edit (see `06-release-engineering.md`).

**Confidence:** High. **Explicit.**
