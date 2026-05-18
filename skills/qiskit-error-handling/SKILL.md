---
name: qiskit-error-handling
description: Choose the right exception class for a Qiskit raise site — `QiskitError` subclass for domain errors (`TranspilerError`, `CircuitError`, `CouplingError`, `QASMError`), `ValueError`/`TypeError` for boundary type/value mismatches, `MissingOptionalLibraryError` for absent extras. Also covers the Rust `import_exception!` bridge. Use whenever the user asks how to raise an error, which exception to throw, or is reviewing error-handling code in `qiskit/` or `crates/`.
---

# Qiskit error handling

The exception hierarchy lives in `qiskit/exceptions.py`. The rule (§11.3.1, **Preferred**): domain errors get domain types; pure type/value mismatches at user boundaries can use Python builtins.

Quantitatively (§11.3.1): ~764 occurrences of `QiskitError` / `TranspilerError` / `CircuitError` raises versus ~374 occurrences of `ValueError` / `TypeError` — Qiskit-specific raises dominate but builtins still appear at boundaries.

## Hierarchy

```
Exception
└── QiskitError(Exception)            qiskit/exceptions.py:90-100
    ├── TranspilerError                qiskit/transpiler/exceptions.py
    ├── CouplingError
    ├── CircuitError                   qiskit/circuit/exceptions.py
    ├── QASMError
    └── MissingOptionalLibraryError(QiskitError, ImportError)  ← dual-inherits!

Warning
├── DeprecationWarning  (Python builtin; QiskitTestCase treats as error)
├── QiskitWarning(Warning)
│   └── ExperimentalWarning            qiskit/exceptions.py:65-72
└── OptionalDependencyImportWarning
```

## Choosing the right class

| Situation | Raise |
|---|---|
| Invalid quantum circuit construction | `CircuitError` |
| Transpile / pass / DAG operation failed | `TranspilerError` |
| QASM parse / serialize problem | `QASMError` |
| Coupling map invalid | `CouplingError` |
| Generic Qiskit-domain failure with no narrower type | `QiskitError` |
| User passed a wrong-typed argument at the public API | `TypeError` |
| User passed a value out of range at the public API | `ValueError` |
| Optional dependency not installed | `MissingOptionalLibraryError` |
| Internal invariant violated (programmer error) | `RuntimeError` or domain error with clear message |

The Cryoris on #15832 sketch: domain types when the failure is a domain concept; Python builtins for *boundary* issues that exist independently of Qiskit semantics.

## Examples

```python
from qiskit.exceptions import QiskitError, MissingOptionalLibraryError
from qiskit.transpiler.exceptions import TranspilerError
from qiskit.circuit.exceptions import CircuitError


def add_gate(self, gate, qargs):
    if gate.num_qubits != len(qargs):
        raise CircuitError(
            f"gate {gate.name} expects {gate.num_qubits} qubits, got {len(qargs)}"
        )

def transpile(circuit, target):
    if not target.has_calibration_for(...):
        raise TranspilerError(
            f"target lacks calibration for {...}"
        )

def plot(...):
    from qiskit.utils.optionals import HAS_MATPLOTLIB
    HAS_MATPLOTLIB.require_now("plot_state_qsphere")
    import matplotlib.pyplot as plt   # imported inside the function
    ...
```

`HAS_MATPLOTLIB.require_now("...")` raises `MissingOptionalLibraryError` if matplotlib isn't installed. The dual inheritance with `ImportError` means `except ImportError:` catches it (§11.3.2; **Mandatory** — changing the MRO would silently break user code).

## Rust → Python bridging (§11.3.5, **Mandatory**)

Each Rust crate that surfaces errors to Python uses the PyO3 macro:

```rust
use pyo3::prelude::*;
use pyo3::import_exception;

import_exception!(qiskit.exceptions, QiskitError);
import_exception!(qiskit.exceptions, TranspilerError);

fn process() -> PyResult<()> {
    if bad_input {
        return Err(QiskitError::new_err("input matrix is not unitary"));
    }
    Ok(())
}
```

`import_exception!` reads the Python class object once at import time and reuses it. The result is a `PyErr` carrying the right Python type, so users see `QiskitError`, not a generic `RuntimeError` or panic traceback.

## Don't

- **Don't raise bare `Exception`.** Use a domain class.
- **Don't raise `RuntimeError` for user-facing errors.** That's for programmer-error invariants only (`coverage.py` even excludes `RuntimeError` lines from coverage — `pyproject.toml:503-510`).
- **Don't use `pydantic` / `typeguard` for runtime validation.** §11.3.3 (**Preferred**); reviewers reject runtime-validator dependencies.
- **Don't `expect`/panic in Rust on user-reachable paths.** §11.3.4. Replace with `?` propagation, compile-time checks, or `Result`. PRs #16010, #15635, #16054 are panic-class bugs that surfaced exactly because of this.
- **Don't mask the original error.** Use `raise X from e` to preserve traceback chains where helpful.

## Warnings, not errors

Choose `warnings.warn(msg, QiskitWarning)` instead of raising when:

- The user is doing something the API still supports but probably shouldn't (e.g. deprecated default).
- An experimental feature is being used (`ExperimentalWarning`).
- An optional-dependency import succeeded but the version is older than recommended.

Reno entry for behavior changes that emit a new warning: `Changelog: Changed`. For deprecations: see [[qiskit-deprecation]].

## Related skills

- [[qiskit-deprecation]] — `@deprecate_func`, deprecation warnings, both-path tests.
- [[qiskit-optional-dependencies]] — `MissingOptionalLibraryError`, lazy testers.
- [[qiskit-rust-performance-idioms]] — `import_exception!`, no-panic rule.
- [[qiskit-bug-triage]] — panic-class bugs (§8.7).
