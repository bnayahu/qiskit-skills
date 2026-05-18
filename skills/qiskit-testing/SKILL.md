---
name: qiskit-testing
description: Run the right Qiskit tests in the right runner — `tox -epy*`, `tox -erust`, `cargo test`, `make ctest`, `tox -eminoptional`. Knows about `QiskitTestCase` (treats `DeprecationWarning` and `QiskitWarning` as errors), `QISKIT_PARALLEL=FALSE`, `QISKIT_TESTS=run_slow=True`, snapshot tests in `test/ipynb/mpl/`, and Hypothesis tests in `test/randomized/`. Use whenever the user asks to run a test, write a regression test, debug a CI failure, or asks "did the test fail before my fix?".
---

# Qiskit testing

## Runners

| Suite | Runner | Path |
|---|---|---|
| Python unit tests | `tox -epy*` (orchestrates `stestr`) | `test/python/` |
| Rust unit tests | `cargo test` or `tox -erust` | inline `#[test]` in each crate |
| Rust unsafe / UB | `miri` (CI: `miri.yml`) | unsafe paths only; FFI tests excluded |
| C API tests | `make ctest` (CMake) | `test/c/` |
| QPY backward-compat | `qpy.yml` workflow / `tox -eqpy_compat` | `test/qpy_compat/` |
| ASV benchmarks | `asv` | `test/benchmarks/` |
| Visual snapshots | `image-tests` workflow | `test/ipynb/mpl/` |
| Hypothesis randomized | `randomized_tests.yml` (cron) | `test/randomized/` |

`stestr` runs in parallel by default; serialize with `QISKIT_PARALLEL=FALSE`.

## `QiskitTestCase` (`test/utils/base.py:40-100`)

The base class enforces several rules:

- Inherits from `testtools.TestCase` if available, else `unittest.TestCase`.
- Calls to `setUp` / `setUpClass` / `tearDown` / `tearDownClass` are enforced via `@enforce_subclasses_call`.
- **Treats `DeprecationWarning` and `QiskitWarning` as errors** by default (`test/utils/base.py:91`). Tests forgetting to silence one of these will fail.

Practical consequence for deprecation tests: you need **two** tests — one with `assertWarns(DeprecationWarning)` for the old path, one warning-free for the new path (§11.5.2, **Mandatory**). See [[qiskit-deprecation]].

## Naming conventions

- Modules: `test_*.py`.
- Classes: `Test*` (e.g. `TestTranspile`).
- Methods: `test_*` (`unittest` convention).
- Test files mirror source: `qiskit/transpiler/passes/optimization/foo.py` → `test/python/transpiler/test_foo.py` (§11.1.3, **Preferred**).

## Useful test env vars

| Variable | Effect | Source |
|---|---|---|
| `QISKIT_PARALLEL=FALSE` | Serialize tests | `tox.ini:13` |
| `QISKIT_TEST_CAPTURE_STREAMS=1` | Capture stdout/stderr/logs | `tox.ini:12` |
| `QISKIT_TESTS=run_slow=True` | Include slow-marked tests | CONTRIBUTING.md:576 |
| `QISKIT_IGNORE_USER_SETTINGS=TRUE` | Ignore user config | `tox.ini:14` |
| `LOG_LEVEL` | Logger verbosity | CONTRIBUTING.md:522 |

## Running a focused subset

```bash
# Single test module:
tox -epy311 -- test.python.transpiler.test_basis_translator

# Single test class:
tox -epy311 -- test.python.transpiler.test_basis_translator.TestBasisTranslator

# Single test method:
tox -epy311 -- test.python.transpiler.test_basis_translator.TestBasisTranslator.test_simple

# Without tox (faster, requires editable install):
stestr run test.python.transpiler.test_basis_translator

# Rust:
cargo test -p qiskit-circuit
cargo test --workspace          # all crates
tox -erust                      # the same but env-controlled

# Minimum optional deps environment (catches module-top optional imports):
tox -eminoptional
```

## Regression-test discipline (§11.5.1, **Mandatory**)

Every bug fix PR must include a test that fails *before* the fix and passes *after*. The verification protocol:

```bash
# 1. Stash your source change (keep the test).
git stash push -m "source-change" -- <files>

# 2. Run the new test. It must fail.
tox -epy311 -- test.python.<your-module>.<TestClass>.<test_method>

# 3. Un-stash.
git stash pop

# 4. Run the test again. It must pass.
tox -epy311 -- test.python.<your-module>.<TestClass>.<test_method>
```

Reviewers reject "fix that worsens the symptom" PRs (jakelishman closed #16124 because `cs(0,1)` actually does cancel with `csdg(1,0)` and the fix made the example worse).

## Control-flow tests for transpiler passes (§11.5.3, near-Mandatory)

If your change touches a transpiler pass that walks DAG nodes, test with nested `IfElseOp`/`ForLoopOp`/`WhileLoopOp`/`BreakLoopOp`. The pass must descend into `ControlFlowOp.blocks`. Eight previously-merged passes were patched for this in 6 months (#15875, #15581/#15626, #15413, #15083, #15143, #15155, #15941, #15147). See [[qiskit-add-transpiler-pass]].

## Visual snapshot tests

mpl drawer changes are checked against `test/ipynb/mpl/` baselines. Reviewers ask for the new baselines to be **visually inspected**, not just regenerated (§11.5.5). #15973, #16074, #16080.

## Memory and file-handle tests

`QISKIT_TEST_CAPTURE_STREAMS=1` captures stdout/stderr so tests can assert on log content. Recent leaks fixed in #16156 (file leak from tests), #15332 (memory leak in `test_get_gate_counts`), #15049 (UB invocation in `SparseObservable` C API test). When adding tests that open files / spawn subprocesses, use `with` / context managers / explicit `close()`.

## Hypothesis tests

`test/randomized/` uses Hypothesis property tests. They run on a nightly cron (`randomized_tests.yml`, `42 3 * * *`), not on every PR. If you change something invariant, add a Hypothesis test that asserts the invariant.

## QPY round-trip tests

`test/qpy_compat/` holds version-corpus tests; `qpy.yml` is a required check. See [[qiskit-qpy-compatibility]] for what to add when bumping the format.

## Coverage

- `coverage.py` configured at `pyproject.toml:503-510`.
- Excludes: `__repr__`, `NotImplementedError`, `RuntimeError`, `@abstractmethod`, `if TYPE_CHECKING:`.
- Run via `make coverage` / `tox -ecoverage`.

## Heuristics

- **Run the relevant test before push.** Full `tox -epy311` is slow; pick the test module that matches your diff.
- **Use `QiskitTestCase`, not bare `unittest.TestCase`.** You'll miss the deprecation/warning enforcement otherwise.
- **Write test names that describe the bug, not the fix.** `test_basis_translator_recurses_into_if_else` is better than `test_pr_15875_fix`.
- **No mocks across the language boundary** (§11.5.6, **Preferred**). Tests that exercise Rust↔Python use the real extension.
- **For deprecation tests: both paths.** Single-path tests get rejected.

## Related skills

- [[qiskit-deprecation]] — both-path test pattern.
- [[qiskit-add-transpiler-pass]] — control-flow test scaffold.
- [[qiskit-qpy-compatibility]] — QPY corpus.
- [[qiskit-good-pr-checklist]] — verifies regression-test gate.
- [[qiskit-debugging]] — `LOG_LEVEL`, capture streams.
- [[qiskit-ci-workflows]] — which workflow runs each suite.
