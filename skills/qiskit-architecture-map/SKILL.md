---
name: qiskit-architecture-map
description: Explain the Qiskit hybrid Python + Rust layout, locate where a feature should live, and surface the one-way crate dependency direction. Use whenever the user is starting work on Qiskit and asks "where do I put X?", "what files do I touch for a transpiler pass?", "is this in the right layer?", or any orientation question on Qiskit's structure. Catches wrong-layer fixes (#16062) before code is written.
---

# Qiskit architecture map

Qiskit is a Python SDK with a single compiled extension module (`qiskit._accelerate`) backed by a Cargo workspace of 16 Rust crates. Performance-critical algorithms and the circuit IR live in Rust; user-facing API and orchestration live in Python.

## Cheat-sheet: where does X live?

| If you're touching… | Look in… | Likely also touch |
|---|---|---|
| A standard gate's matrix or definition | `qiskit/circuit/library/standard_gates/<gate>.py` | `crates/circuit/src/operations/standard_gate*.rs`; reno `features_circuits` |
| A transpiler pass | `qiskit/transpiler/passes/<category>/` | `crates/transpiler/src/` if hot; reno `features_transpiler` |
| QPY serialization | `qiskit/qpy/`, `crates/qpy/` | `test/qpy_compat/`; reno `features_qpy` / `upgrade_qpy` |
| Synthesis algorithm | `qiskit/synthesis/<family>/`, `crates/synthesis/` | `crates/transpiler/` if it's a default synth |
| C API surface | `crates/cext/`, `crates/cext-vtable/`, `crates/bindgen/include/qiskit/` | `test/c/`, `Makefile` C targets |
| Visualization | `qiskit/visualization/` | `test/ipynb/mpl/`, image-tests workflow |
| Primitives (Sampler/Estimator) | `qiskit/primitives/` | reno `features_primitives` |
| OpenQASM 2 | `qiskit/qasm2/`, `crates/qasm2/` | |
| OpenQASM 3 | `qiskit/qasm3/`, `crates/qasm3/` | |
| Backend interface | `qiskit/providers/`, `crates/providers/` | |

## Rust crates (16 total)

| Crate | Role | Notes |
|---|---|---|
| `qiskit-pyext` | Builds the **single** `cdylib` (`.so`) | Imports every other crate |
| `qiskit-circuit` | Core IR (Qubit/Clbit/Var/Block u32 newtypes, CircuitData) | Foundation |
| `qiskit-transpiler` | Transpiler passes | Depends on circuit, synthesis, quantum-info |
| `qiskit-quantum-info` | Operator, DensityMatrix, Pauli algorithms | Decoupled from circuit-level objects |
| `qiskit-synthesis` | Permutation, linear, Clifford, QFT, MCX, Pauli evolution | |
| `qiskit-circuit-library` | Circuit constructors built on the IR | |
| `qiskit-providers` | Backend / Job / Tensor / DType (added in #15993) | |
| `qiskit-qasm2` | OpenQASM 2 parser | Largely standalone |
| `qiskit-qasm3` | OpenQASM 3 importer | Wraps `openqasm3_parser` |
| `qiskit-qpy` | QPY serialization | |
| `qiskit-accelerate` | Catch-all for one-off accelerators | "End of dependency tree" |
| `qiskit-cext` | C FFI layer | Dual-mode: standalone or pyext-embedded |
| `qiskit-cext-vtable` | C API vtables | Used by pyext build |
| `qiskit-bindgen` | C-header generation library | Internal |
| `qiskit-bindgen-cli` | Header lint binary | |
| `qiskit-util` | Tiny shared utilities | `features=["py"]` activates pyo3 |

## One-way dependency direction (§11.2.1, **Mandatory**)

```
qiskit-pyext  (the .so)
├── qiskit-accelerate
├── qiskit-circuit  ←  qiskit-quantum-info, qiskit-util[py], rustworkx-core
├── qiskit-transpiler  ←  qiskit-circuit, qiskit-synthesis, qiskit-quantum-info
├── qiskit-circuit-library  ←  qiskit-circuit
├── qiskit-qasm2  ←  qiskit-circuit
├── qiskit-qasm3
├── qiskit-qpy
├── qiskit-quantum-info
├── qiskit-synthesis
├── qiskit-cext      [python_binding]
└── qiskit-cext-vtable [python_binding, addr]
```

**`qiskit-circuit` is the data-model floor.** Nothing above it imports a transpiler/synthesis crate. `qiskit-circuit` does **not** import `qiskit-transpiler`. Reviewer pushback on #16062 (jakelishman: *"This is not a correct fix, because the root fault is not in the exporter but in the importer"*) shows the rule is enforced socially as well as structurally.

## Top-level Python packages (`qiskit/`)

| Package | Contents |
|---|---|
| `circuit` | `QuantumCircuit`, `Gate`, `Instruction`, registers, `Parameter`, gate library |
| `transpiler` | `BasePass`, `PassManager`, preset levels 0–3 + Clifford-T, domain passes |
| `dagcircuit` | `DAGCircuit`, `DAGOpNode` |
| `passmanager` | Generic pass-manager infrastructure |
| `primitives` | Sampler / Estimator V2 (`StatevectorSampler`, etc.) |
| `providers` | `BackendV2`, `Job`, `Options`; `BasicProvider`, `FakeProvider` |
| `quantum_info` | Operator, DensityMatrix, Pauli, SparsePauliOp |
| `synthesis` | Synthesis grouped by family |
| `visualization` | Text / mpl drawers, state plots, DAG plots |
| `qasm2`, `qasm3` | OpenQASM wrappers |
| `qpy` | QPY wrapper |
| `result` | `Result`, `Counts` |
| `converters` | Circuit ↔ DAG converters |
| `utils` | `deprecation`, `optionals`, `parallel` |
| `exceptions` | `QiskitError`, warnings |

## Architectural invariants

- **`QuantumCircuit` is the universal exchange format** (§11.2.4). Synthesis returns `QuantumCircuit`; transpiler I/O is `QuantumCircuit`; primitives accept it. Internally Rust uses `CircuitData`, transpiler uses `DAGCircuit` — both are intentional internal substitutions.
- **No async/await anywhere in `qiskit/`** (§11.8.1). `grep -r "async def\|await " qiskit/` returns zero matches. Concurrency goes through `qiskit/utils/parallel.py` (`concurrent.futures`).
- **Modules organized by domain, not abstraction layer** (§11.2.3). `circuit/` mixes IR + gates + parameter system; `transpiler/` owns *all* transformation logic; `synthesis/` owns *all* algorithms.
- **Single `cdylib` extension module** (§11.2.5, **Mandatory**). New Rust submodules require a matching `sys.modules[...] = ...` line in `qiskit/__init__.py:49-146`. See [[qiskit-py-rust-bridge]].

## How to use this skill

When the user describes what they want to do, route them to the right files:

> *"I want to add a new transpiler pass for Pauli simplification — what files do I touch?"*

Answer: `qiskit/transpiler/passes/optimization/` for the Python pass; `crates/transpiler/src/` for the Rust counterpart if hot; reno entry under `features_transpiler`. Hand off to [[qiskit-add-transpiler-pass]].

> *"There's a bug in QASM2 export — fix it in the exporter, right?"*

Investigate first. The root cause may be in the importer (cf. #16062, where exactly this happened — a fix in the QASM exporter was closed because the importer was the source). Trace the bad value backwards before deciding which module is wrong.

## Related skills

- [[qiskit-py-rust-bridge]] — single-cdylib mechanics, `sys.modules` registration.
- [[qiskit-add-transpiler-pass]] — transpiler-pass scaffolding.
- [[qiskit-add-standard-gate]] — gate scaffolding.
- [[qiskit-qpy-compatibility]] — QPY format mechanics.
- [[qiskit-bug-triage]] — recurring bug categories by area.
