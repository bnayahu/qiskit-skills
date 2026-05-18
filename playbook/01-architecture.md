# 1. Architecture & Subsystem Boundaries

## 1.1 Hybrid Python + Rust layout

Qiskit is a Python SDK with a single compiled extension module (`qiskit._accelerate`) backed by
a Cargo workspace of 16 Rust crates. Performance-critical algorithms and the circuit IR live in
Rust; user-facing API surface and orchestration live in Python.

**Evidence:** `Cargo.toml:1-70`, `crates/README.md`, `qiskit/__init__.py:49-146`,
`crates/pyext/Cargo.toml:8-10`.
**Confidence:** High. **Explicit** (documented in `crates/README.md`).

## 1.2 Rust crate inventory

Every workspace member lives under `crates/`. Roles are stated in `crates/README.md`:

| Crate | Role | Notes |
|-------|------|-------|
| `qiskit-pyext` | Builds the **single** `cdylib` (Python C extension) | Only crate that builds the `.so`. Imports every other crate. |
| `qiskit-circuit` | Core circuit IR (Qubit/Clbit/Var/Block u32 newtypes, CircuitData) | Foundation for everything circuit-shaped. |
| `qiskit-transpiler` | Transpiler passes (layout, routing, optimization, scheduling) | Depends on circuit, synthesis, quantum-info. |
| `qiskit-quantum-info` | Operator, DensityMatrix, Pauli, SparsePauliOp algorithms | Decoupled from circuit-level objects. |
| `qiskit-synthesis` | Permutation, linear, Clifford, QFT, MCX, Pauli evolution synthesis | |
| `qiskit-circuit-library` | Circuit constructors built on the IR | |
| `qiskit-providers` | Backend / Job interface, DType/Tensor (added in #15993) | |
| `qiskit-qasm2` | OpenQASM 2 parser | Largely standalone. |
| `qiskit-qasm3` | OpenQASM 3 importer | Wraps external `openqasm3_parser`. |
| `qiskit-qpy` | QPY serialization | |
| `qiskit-accelerate` | Catch-all for one-off accelerators | "End of dependency tree" per `crates/README.md:28-29`. |
| `qiskit-cext` | C FFI layer | Dual-mode: standalone C lib **or** embedded in pyext via `python_binding` feature. |
| `qiskit-cext-vtable` | C API vtables | Used by pyext build. |
| `qiskit-bindgen` | C-header generation library | Internal. |
| `qiskit-bindgen-cli` | Header lint binary | |
| `qiskit-util` | Tiny shared utilities | `features=["py"]` activates pyo3. |

**Evidence:** `crates/README.md:20-63`, individual `crates/*/Cargo.toml`. **Confidence:** High.
**Explicit.**

## 1.3 Python ↔ Rust integration mechanics

- **Single extension module.** `qiskit/__init__.py:49-146` registers every Rust submodule
  manually in `sys.modules` so users can `from qiskit._accelerate.circuit import …`. PyO3 does
  not auto-register nested modules from a single `.so`.
- **PyO3 version:** `0.28.3` with `abi3-py310` for stable ABI (`Cargo.toml:53`).
- **Initialization rule.** Rust extension code may **not** import Python submodules at init time
  to avoid circular imports while `_accelerate` is still loading. The `import_exception!` macro
  is the documented exception (`crates/README.md:56-63`,
  `crates/accelerate/src/lib.rs:13-24`).
- **Type bridging.** `Qubit`, `Clbit`, `Var`, `Block` are transparent `u32` newtypes with
  `FromPyObject` impls (`crates/circuit/src/lib.rs`).
- **Exception bridging.** `import_exception!(qiskit.exceptions, QiskitError);` in Rust crates
  re-uses Python exception classes so users see normal Python exceptions on Rust panics
  converted to `Result`s.

**Confidence:** High. **Explicit** (documented in `crates/README.md`).

## 1.4 Top-level Python packages

`qiskit/` directory layout (each entry is a public-facing package):

| Package | Contents |
|---------|----------|
| `circuit` | `QuantumCircuit`, `Gate`, `Instruction`, registers, `Parameter`/`ParameterExpression`, gate library. |
| `transpiler` | `BasePass` hierarchy, `PassManager`, preset pass managers (levels 0–3, Clifford-T), domain passes. |
| `dagcircuit` | DAG representation (`DAGCircuit`, `DAGOpNode`). |
| `passmanager` | Generic pass-manager infrastructure (decoupled from transpiler). |
| `primitives` | Sampler/Estimator V2 abstractions (`StatevectorSampler`, `BackendEstimatorV2`, …). |
| `providers` | `BackendV2`, `Job`, `Options`; `BasicProvider`, `FakeProvider`. |
| `quantum_info` | Operator, DensityMatrix, Statevector, Pauli, SparsePauliOp, analysis. |
| `synthesis` | Synthesis algorithms grouped by family. |
| `visualization` | Text / mpl drawers, state plots, DAG / pass-manager / gate-map plots. |
| `qasm2`, `qasm3` | OpenQASM import/export wrappers around Rust crates. |
| `qpy` | QPY serialization wrapper around Rust crate. |
| `result` | `Result`, `Counts`. |
| `converters` | Circuit ↔ DAG converters. |
| `utils` | `deprecation` decorators, `optionals` lazy testers, `parallel`. |
| `exceptions` | `QiskitError`, `MissingOptionalLibraryError`, `QiskitWarning`, `ExperimentalWarning`, `OptionalDependencyImportWarning`. |

**Evidence:** directory tree of `qiskit/`. **Confidence:** High.

## 1.5 Subsystem dependency graph (inferred from Cargo.toml + imports)

```
qiskit-pyext  (the .so)
├── qiskit-accelerate
├── qiskit-circuit  ←  qiskit-quantum-info, qiskit-util[py], rustworkx-core
├── qiskit-transpiler  ←  qiskit-circuit, qiskit-synthesis, qiskit-quantum-info, qiskit-util[py]
├── qiskit-circuit-library  ←  qiskit-circuit
├── qiskit-qasm2  ←  qiskit-circuit
├── qiskit-qasm3
├── qiskit-qpy
├── qiskit-quantum-info
├── qiskit-synthesis
├── qiskit-cext      [python_binding]
└── qiskit-cext-vtable [python_binding, addr]
```

`qiskit-util` is the shared bottom layer; `qiskit-pyext` is the top FFI layer; `qiskit-circuit`
is the central data-model layer.

**Evidence:** transitive `[dependencies]` blocks in each `crates/*/Cargo.toml`.
**Confidence:** High.

## 1.6 Architectural invariants (inferred)

- **`QuantumCircuit` is the central exchange format.** Every subsystem either consumes,
  produces, or transforms it. Even synthesis returns `QuantumCircuit`; transpiler input/output
  is `QuantumCircuit`; primitives accept it.
  **Confidence:** Medium. **Inferred.**
- **No async / await anywhere in `qiskit/`.** `grep -r "async def\|await " qiskit/` returns
  zero matches. Concurrency is `concurrent.futures`-based via `qiskit/utils/parallel.py`.
  **Confidence:** High. **Inferred** (absence is observed).
- **Module organization is by domain, not by abstraction layer.** `circuit/` mixes IR + gates
  + parameter system; `transpiler/` owns all transformation logic; `synthesis/` owns all
  algorithms. Users import from one domain at a time.
  **Confidence:** High. **Inferred.**

## 1.7 What lives where (cheat sheet)

| If you're touching… | Look in… | Likely also touch |
|---|---|---|
| A standard gate's matrix or definition | `qiskit/circuit/library/standard_gates/<gate>.py` | `crates/circuit/src/operations/standard_gate*.rs`; release note |
| A transpiler pass | `qiskit/transpiler/passes/<category>/` | `crates/transpiler/src/`; pass docs |
| QPY serialization | `qiskit/qpy/`, `crates/qpy/` | `test/qpy_compat/`; reno entry |
| Synthesis algorithm | `qiskit/synthesis/<family>/`, `crates/synthesis/` | `crates/transpiler/` if it's a default synth |
| C API surface | `crates/cext/`, `crates/cext-vtable/`, `crates/bindgen/include/qiskit/` | `test/c/`, `Makefile` C targets |
| Visualization | `qiskit/visualization/` | `test/ipynb/mpl/`, image-tests workflow |
