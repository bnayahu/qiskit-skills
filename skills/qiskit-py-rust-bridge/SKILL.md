---
name: qiskit-py-rust-bridge
description: Walk through Qiskit's single-`cdylib` build, the manual `sys.modules` registration in `qiskit/__init__.py:49-146`, and the PyO3 init-time rule that Rust extension code must not import Python submodules at module init. Use whenever the user adds or removes a Rust submodule, debugs an import-time error from `qiskit._accelerate`, ports a Python algorithm to Rust, or asks why `from qiskit._accelerate import foo` fails. Adding a Rust submodule without the registration line is the canonical "I added a crate but it doesn't import" bug.
---

# Qiskit Python ↔ Rust bridge

Qiskit's Rust workspace builds a **single** `cdylib`: `qiskit._accelerate.so`. PyO3 does not auto-register nested submodules from a single cdylib, so `qiskit/__init__.py:49-146` does it manually:

```python
# qiskit/__init__.py (~lines 49-146)
import sys
from qiskit._accelerate import (
    circuit,
    transpiler,
    synthesis,
    quantum_info,
    qpy,
    qasm2,
    qasm3,
    providers,   # added in #15993
    # ...
)
sys.modules["qiskit._accelerate.circuit"] = circuit
sys.modules["qiskit._accelerate.transpiler"] = transpiler
sys.modules["qiskit._accelerate.synthesis"] = synthesis
sys.modules["qiskit._accelerate.quantum_info"] = quantum_info
sys.modules["qiskit._accelerate.qpy"] = qpy
# ...
```

Without the matching `sys.modules[...] = ...` line, `from qiskit._accelerate.foo import …` fails with `ModuleNotFoundError` even though the symbol exists inside the `.so`.

## Adding a new Rust submodule — checklist

1. **Crate.** Add `crates/<name>/` with `Cargo.toml` and `src/lib.rs`. The crate name is `qiskit-<name>` (§11.1.2, **Mandatory**).
2. **Workspace dep.** Add `qiskit-<name>` under `[workspace.dependencies]` in the root `Cargo.toml` (`Cargo.toml:55-69`) — local-path crates live alongside external ones so members can `<crate>.workspace = true`.
3. **pyext registration.** Add a `pyo3` submodule in `crates/pyext/src/lib.rs` that exposes the new crate's `PyModule`.
4. **Python import.** Add the import + `sys.modules` line to `qiskit/__init__.py:49-146`.
5. **Test.** Run `from qiskit._accelerate.<name> import ...` in a Python REPL to confirm the import works.

#15993 ("Add DType, Tensor & friends to providers crate") is the canonical recent example — it added a new submodule and required exactly this pattern.

## PyO3 setup

`Cargo.toml:53`: `pyo3 = "0.28.3"` with feature `abi3-py310` (stable ABI; the same `.so` works on Python 3.10–3.14).

```rust
// crates/<name>/src/lib.rs
use pyo3::prelude::*;

#[pymodule]
fn <name>(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_class::<MyType>()?;
    m.add_function(wrap_pyfunction!(my_func, m)?)?;
    Ok(())
}
```

Then in `crates/pyext/src/lib.rs`:

```rust
#[pymodule]
fn _accelerate(py: Python, m: &PyModule) -> PyResult<()> {
    // ... existing modules
    add_submodule(py, m, "<name>", qiskit_<name>::<name>)?;
    Ok(())
}
```

(Read existing `pyext` registrations for the exact `add_submodule` shape.)

## The init-time rule (§11.2.2, **Mandatory**)

Rust extension code may **not** import Python submodules during `_accelerate` load — at that point `qiskit._accelerate` is still being constructed and circular imports surface as `ImportError` at startup. The documented exception is the `import_exception!` macro, which reads a Python exception class lazily.

```rust
// OK: lazy reference to a Python exception class
import_exception!(qiskit.exceptions, QiskitError);

// NOT OK: synchronous Python import at module init
fn init() {
    Python::with_gil(|py| {
        let _ = py.import("qiskit.circuit");  // crashes at init time
    });
}
```

If you need a Python class at runtime (not init), use `Python::with_gil` inside the function that uses it.

## Type bridging

`Qubit`, `Clbit`, `Var`, `Block` are transparent `u32` newtypes with `FromPyObject` impls (`crates/circuit/src/lib.rs`). They cross the Python ↔ Rust boundary cheaply.

For larger objects:

- `&PyAny` / `Bound<'_, PyAny>` — borrow a Python object from Rust.
- `PyObject` — own a reference (incref'd).
- `Py<MyPyClass>` — strongly-typed owned reference.
- Convert NumPy arrays via the `numpy` Rust crate (`PyArray<T, D>`).

## Exception bridging (§11.3.5, **Mandatory**)

Each crate that surfaces errors uses `import_exception!`:

```rust
import_exception!(qiskit.exceptions, QiskitError);
import_exception!(qiskit.exceptions, TranspilerError);

fn process() -> PyResult<()> {
    if bad { return Err(QiskitError::new_err("...")); }
    Ok(())
}
```

This produces the right Python exception type when the `Result` is converted to a `PyErr`. See [[qiskit-error-handling]].

## Debugging "from qiskit._accelerate import foo fails"

1. Was the crate added to `[workspace.dependencies]`?
2. Was the submodule registered in `crates/pyext/src/lib.rs`?
3. Was the matching `sys.modules["qiskit._accelerate.foo"] = foo` line added in `qiskit/__init__.py`?
4. Was the build redone? `pip install -e .` (debug profile) or `python setup.py build_rust --inplace` after editing Rust.
5. If editable, check `QISKIT_BUILD_PROFILE` — debug builds are slower at runtime but compile faster.

## Build profiles (§2.1)

- `pip install .` → release.
- `pip install -e .` → debug.
- `QISKIT_BUILD_PROFILE=debug|release` overrides.
- Manual recompile in editable mode: `python setup.py build_rust --inplace [--release|--debug]`.
- `QISKIT_BUILD_WITH_MIMALLOC=1` links mimalloc (faster allocator).
- `QISKIT_NO_CACHE_GATES=1` disables gate-object caching (debugging aid).

## Heuristics

- **Crate-level boundaries are real.** Don't import a higher-layer crate from a lower one (§11.2.1). `qiskit-circuit` does not depend on `qiskit-transpiler`.
- **Match the workspace pyo3 version.** `Cargo.toml:53` pins `pyo3 = "0.28.3"`; new crates use `<crate>.workspace = true` so they inherit it.
- **Cargo.lock** must be current — #15839 added a Cargo.lock currency check to lint.
- **Test the import.** After registration, `python -c "from qiskit._accelerate.<name> import *"` is the fastest sanity check.

## Related skills

- [[qiskit-architecture-map]] — crate roles and dependency direction.
- [[qiskit-rust-performance-idioms]] — what to write inside the Rust submodule.
- [[qiskit-error-handling]] — `import_exception!` usage.
- [[qiskit-build-system]] — build profiles, MSRV, env knobs.
