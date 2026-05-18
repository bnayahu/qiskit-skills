# 2. Build and Test Systems

## 2.1 Build system

### Build backend

- PEP 517 with `setuptools.build_meta` (`pyproject.toml:10`).
- Build requires `setuptools>=77.0` and **`setuptools-rust==1.12.0`** (hard pin, lines 3–9).
  The hard pin exists because `setup.py` monkeypatches `setuptools-rust` internals to copy
  generated artifacts (`include/`, `_ctypes.py`) into the `qiskit.capi` package. The pin will
  loosen once setuptools-rust PR #574 ships (`setup.py:20-96`).
- Python support: 3.10–3.14 (`pyproject.toml:15`).

**Confidence:** High. **Explicit.**

### Rust ↔ Python integration

- Single `cdylib` extension module `qiskit._accelerate`, built from `crates/pyext/Cargo.toml`
  (`setup.py:144-150`).
- **Build profile rules** (`setup.py:113-164`):
  - `pip install .` → release.
  - `pip install -e .` → debug.
  - `QISKIT_BUILD_PROFILE=debug|release` overrides.
  - Manual recompile in editable mode: `python setup.py build_rust --inplace [--release|--debug]`.

### Compile-time toggles (env vars)

| Variable | Effect | Source |
|---|---|---|
| `QISKIT_BUILD_PROFILE` | force `debug` / `release` Rust build | `setup.py:113` |
| `QISKIT_BUILD_WITH_MIMALLOC=1` | link mimalloc allocator | `setup.py:138-139`, reno `mimalloc-403d3300aa698fae.yaml` |
| `QISKIT_NO_CACHE_GATES=1` | disable Python gate-object caching | `setup.py:133-136` |

**Confidence:** High. **Explicit.**

### Rust workspace

- 16 workspace members (`Cargo.toml:2`).
- Workspace-shared dependencies (`Cargo.toml:16-69`): `numpy = "0.28"`, `pyo3 = "0.28.3"`,
  `rayon`, `ndarray`, etc.
- **MSRV: Rust 1.87** (`Cargo.toml:8`, `rust-toolchain.toml`, `tools/install_rust_msrv.sh`,
  `README.md`). Must be kept in sync across all four locations — see PR `msrv-187-fe3d9818f5c4103d`
  reno entry.
- Workspace lints (`Cargo.toml:71-86`): clippy `deny`s `print_stdout`, `print_stderr`,
  `unsafe_op_in_unsafe_fn`. Allows `comparison-chain`.

**Confidence:** High. **Explicit.**

### C API targets (Makefile)

| Target | Purpose | Source |
|---|---|---|
| `make c` | header + standalone C library | `Makefile:154-165` |
| `make clib` / `clib-dev` | release / debug C library | `Makefile:159-162` |
| `make ctest` | C-API CMake test suite | `Makefile:167-181` |
| `make cformat` / `fix_cformat` | clang-format check / auto-fix | `Makefile:127-130` |
| `make coverage` | LCOV coverage on `qiskit` package | tox-driven |

**Confidence:** High.

## 2.2 Test system

### Runners

- **Python:** `stestr` (`.stestr.conf:2` → `test_path=./test/python`), orchestrated by **tox**
  (`tox.ini`; minversion 4.28.0). Parallel by default; serialize with `QISKIT_PARALLEL=FALSE`.
- **Rust:** `cargo test` or `tox -erust` (`tox.ini:33-37`). Tests are inline `#[test]` with
  `#[cfg(test)]`. Rust tests can call Python via `Python::with_gil` (CONTRIBUTING.md:699-711).
- **Miri** for unsafe code (CONTRIBUTING.md:723-745); FFI tests excluded.
- **C API:** `make ctest` (CMake) — see `test/c/`.

**Confidence:** High. **Explicit.**

### Test categories

| Path | What |
|---|---|
| `test/python/` | Python unit tests, organized per package (circuit, compiler, transpiler, …). |
| `test/benchmarks/` | ASV benchmarks (`asv.conf.json:21`). |
| `test/c/` | C-API tests via CMake. |
| `test/qpy_compat/` | QPY backward-compatibility tests. |
| `test/randomized/` | Hypothesis-based randomized property tests. |
| `test/ipynb/mpl/` | Visual snapshot regression tests for mpl. |

**Confidence:** High.

### Test base class

`QiskitTestCase` in `test/utils/base.py:40-100`:

- Inherits from `testtools.TestCase` if available, else `unittest.TestCase`.
- Enforces subclass calls to `setUp`/`setUpClass`/`tearDown`/`tearDownClass`.
- Treats `DeprecationWarning` and `QiskitWarning` as **errors** by default (line 91).
  Reviewers consistently ask contributors to test *both* the deprecated path (with
  `assertWarns`) and the new path — see `CONTRIBUTING.md:928-953`.

**Confidence:** High. **Explicit.**

### Naming conventions

- Module: `test_*.py`.
- Class: `Test*` (e.g. `TestTranspile`).
- Methods inherit `unittest.TestCase`; many decorated with `@enforce_subclasses_call`.

**Confidence:** High. **Inferred** (consistent across `test/python/`).

### Coverage

- `coverage.py` configured at `pyproject.toml:503-510`.
- Excludes: `__repr__`, `NotImplementedError`, `RuntimeError`, `@abstractmethod`,
  `if TYPE_CHECKING:`.
- Run via `make coverage` / `tox -ecoverage`.

### Useful test env vars

| Variable | Effect | Source |
|---|---|---|
| `QISKIT_PARALLEL=FALSE` | serialize tests | `tox.ini:13` |
| `QISKIT_TEST_CAPTURE_STREAMS=1` | capture stdout/stderr/logs | `tox.ini:12` |
| `QISKIT_TESTS=run_slow=True` | include slow tests | CONTRIBUTING.md:576 |
| `QISKIT_IGNORE_USER_SETTINGS=TRUE` | ignore user config | `tox.ini:14` |
| `LOG_LEVEL` | logger verbosity | CONTRIBUTING.md:522 |

**Confidence:** High. **Explicit.**

## 2.3 Local lint loop

- `tox -elint` runs all linters (black, ruff, cargo fmt, clippy, slots check).
- No `pre-commit` framework — CI/tox is the gate (`.pre-commit-config.yaml` is absent).
  **Confidence:** Medium. **Inferred.**

## 2.4 Notable recent test/build fixes

- **#16156** "Fix file leak from tests" — file-handle leak in test cleanup.
- **#15332** "Memory leak in `test_get_gate_counts`".
- **#15049** "Fix UB invocation in `SparseObservable` C API test".
- **#15839** added Cargo.lock validation in lint.
- **#16128** "Enable clippy on rust tests too" — clippy now runs `--all-targets`.
- **#15721** promoted "missing argument in docstring" lint to CI-blocking.

These show that the build/test surface itself is actively maintained and tightening over time.
