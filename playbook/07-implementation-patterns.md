# 7. Common Implementation Patterns

## 7.1 Adding a standard gate

Pattern observed across all gates in `qiskit/circuit/library/standard_gates/`:

```python
@with_gate_array(_X_ARRAY)         # provides .__array__
class XGate(SingletonGate):        # ensures one canonical instance
    _standard_gate = StandardGate.X  # link to Rust enum (qiskit._accelerate)
    def __init__(self, label: str | None = None):
        ...
```

- **`SingletonGate`** (`qiskit/circuit/singleton.py`) ensures identity-based equality and
  reduces memory; relies on `stdlib_singleton_key()`.
- **`_standard_gate`** attribute connects the Python class to the Rust enum variant in
  `crates/circuit/src/operations/`.
- **Docstrings** include LaTeX math, circuit symbols, and the state action.

**Source:** `qiskit/circuit/library/standard_gates/x.py:27-80`. **Confidence:** High.
**Inferred** (consistent across the gate library, no single doc).

## 7.2 Adding a transpiler pass

```python
class MyPass(AnalysisPass):           # or TransformationPass
    def __init__(self, ...): ...
    def run(self, dag: DAGCircuit):   # required override
        self.property_set["x"] = ...
```

- Both base classes inherit from `BasePass` (`qiskit/transpiler/basepasses.py:29-100`),
  whose `MetaPass` metaclass auto-hashes constructor args so the pass manager can
  deduplicate runs.
- `AnalysisPass` writes only to `self.property_set`; `TransformationPass` returns a new
  DAG.
- Type hints commonly use `from __future__ import annotations` + `if TYPE_CHECKING:` to break
  circular imports of `DAGCircuit`.

**Source:** `qiskit/transpiler/basepasses.py`,
`qiskit/transpiler/passes/analysis/depth.py`. **Confidence:** High. **Explicit** in
`basepasses.py` docstrings.

## 7.3 Exception hierarchy

- Root: `QiskitError(Exception)` in `qiskit/exceptions.py:90-100`. Stores `self.message` for
  `repr()`.
- Domain subclasses: `TranspilerError`, `CouplingError`, `CircuitError`, `QASMError`, etc.
- **`MissingOptionalLibraryError(QiskitError, ImportError)`** uses multiple inheritance so
  `except ImportError:` blocks still catch missing-optional cases
  (`qiskit/exceptions.py:109-134`).
- **Warnings:** `QiskitWarning`, `ExperimentalWarning`, `OptionalDependencyImportWarning` all
  subclass `Warning`.
- **Rust → Python:** Rust crates use the PyO3 macro
  `import_exception!(qiskit.exceptions, QiskitError);` so Rust error returns produce Python
  exceptions with the right type (`crates/accelerate/src/lib.rs:13-24`).

**Confidence:** High. **Explicit.**

## 7.4 Deprecation pattern

See also: `06-release-engineering.md` § 6.4.

```python
@deprecate_func(
    since="0.23",
    additional_msg="Use new_func instead",
    removal_timeline="in release 0.27",
)
def old_func(...): ...

@deprecate_arg(
    "old_name",
    new_alias="new_name",
    since="0.25",
    predicate=lambda v: isinstance(v, dict),
)
def my_func(*, new_name=None): ...
```

- Decorators detect function/method/property automatically and rewrite docstrings.
- `pending=True` for early-stage warnings (issues `PendingDeprecationWarning`).
- **Tests:** must exercise both the warning path (with `assertWarns`) and the new path
  (CONTRIBUTING.md:928-953). Reviewers reject single-test PRs that only hit one path.

**Confidence:** High. **Explicit.**

## 7.5 Type-hint style

- Universal `from __future__ import annotations` at module top.
- Modern union syntax: `int | float | None`. No `Optional`, no `Union`.
- `if TYPE_CHECKING:` guards used liberally to defer expensive imports.
- **No runtime validators** (no pydantic / typeguard). Boundary checks are manual
  `isinstance(x, …)` raising `QiskitError` subclasses.

**Confidence:** High. **Inferred** (consistent across `qiskit/`).

## 7.6 Concurrency

- **No async/await** anywhere in `qiskit/`. `grep -r "async def\|await " qiskit/` → 0 hits.
- Parallel execution lives in `qiskit/utils/parallel.py` (`concurrent.futures`-based).
- **Determinism caveats:** parallel sorts produced ordering bugs and were rolled back in
  **#15410** ("Stop using a parallel sort in disjoint utils"). When introducing parallelism
  in transpiler passes (e.g. **#16014** CommutationAnalysis), reviewers ask for a performance
  reno entry.

**Confidence:** High.

## 7.7 Optional-dependency pattern

```python
def my_function(...):
    from qiskit.utils.optionals import HAS_MATPLOTLIB
    HAS_MATPLOTLIB.require_now("plot_state_qsphere")
    import matplotlib.pyplot as plt
    ...
```

- Lazy testers in `qiskit.utils.optionals` (e.g. `HAS_MATPLOTLIB`, `HAS_AER`,
  `HAS_QASM3_IMPORT`) defer the import and produce `MissingOptionalLibraryError` if missing.
- Optional deps are **not** imported at module top-level in user-facing modules.
  CONTRIBUTING.md:978-983 codifies this.

**Confidence:** High. **Explicit.**

## 7.8 Rust idioms preferred by reviewers

(See `09-reviewer-expectations.md` § 1.5 for inline-comment evidence.)

- **Avoid `expect`/panics.** Replace with compile-time checks, `?` propagation, or `Result`s.
  Examples: **#16010** (VF2), **#15635** (Quantum Shannon Decomposition).
- **Don't allocate when you can stack-allocate.** mtreinish in **#16123**: prefer
  `[Matrix2<Complex64>; 4]` over `SmallVec` when the size is statically known. Use
  `try_inverse_mut()` for in-place inversion.
- **Don't duplicate iterator logic.** jakelishman in **#15999**: extend a native iterator
  rather than reimplementing it.
- **Prefer `numpy`/`nalgebra`/`faer` over `scipy`** in hot Rust paths (recent moves: **#16016**,
  **#15960**, **#15874**, **#15881**, **#15928**, **#15871**).
- **No `println!` / `eprintln!`** — denied by clippy workspace-wide.

**Confidence:** High. **Inferred** (recurring review feedback) + **Explicit** for the clippy ban.

## 7.9 Python ↔ Rust re-export pattern

`qiskit/__init__.py:49-146` registers each Rust submodule into `sys.modules`:

```python
from qiskit._accelerate import circuit, transpiler, synthesis, …
sys.modules["qiskit._accelerate.circuit"] = circuit
sys.modules["qiskit._accelerate.transpiler"] = transpiler
…
```

This is a workaround for PyO3's lack of automatic nested-module registration in single-cdylib
builds. New Rust submodules added to `pyext` need a matching line here.

**Confidence:** High. **Explicit** in code.

## 7.10 QPY backward-compatibility pattern

QPY changes are gated by version numbers and tested in `test/qpy_compat/`:

- Recent format-version work: **#15663** (Rust QPY v13 compat), **#15847**, **#15649**,
  **#15623**, **#16076**, **#15934**.
- `qpy.yml` workflow runs the compat suite on every PR.
- New format versions add a reno entry under `features_qpy` or `upgrade_qpy`.

**Confidence:** High. **Inferred.**

## 7.11 Decorators worth knowing about

| Decorator | Where | Use |
|---|---|---|
| `@deprecate_func` / `@deprecate_arg` / `@deprecate_arg_default` | `qiskit/utils/deprecation.py` | Deprecations |
| `@with_gate_array` | `qiskit/circuit/_utils.py` | Provide `.to_matrix()` from a constant array |
| `@enforce_subclasses_call` | `test/utils/base.py` | Test base class enforces super().setUp() |
| `@stdlib_singleton_key` | `qiskit/circuit/singleton.py` | Singleton gate keying |

**Confidence:** High.
