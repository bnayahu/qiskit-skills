---
name: qiskit-add-standard-gate
description: Generate the canonical scaffolding for a new Qiskit standard gate — `qiskit/circuit/library/standard_gates/<name>.py` (`SingletonGate` subclass with `@with_gate_array`, `_standard_gate = StandardGate.<NAME>` link), the corresponding Rust enum entry under `crates/circuit/src/operations/`, gate test, mpl visualization snapshot, and a reno entry under `features_circuits`. Use whenever the user asks to add a standard gate, create a new fundamental gate type, or add a built-in to the gate library. Bakes in the `global_phase` invariant test so silent global-phase drops (#15943, #15944) don't recur.
---

# Add a Qiskit standard gate

Standard gates live under `qiskit/circuit/library/standard_gates/<short_name>.py` and have a parallel Rust enum variant under `crates/circuit/src/operations/`. Filenames use the gate's canonical short name (`x.py`, `rz.py`, `xx_minus_yy.py`, …) — see §11.1.1.

This skill bakes in:

- `SingletonGate` subclassing for identity-based equality and reduced memory (§11.9.4).
- `@with_gate_array` for the `__array__` matrix.
- `_standard_gate = StandardGate.<NAME>` Python ↔ Rust enum link.
- Both the Python class and the Rust enum entry.
- A `global_phase` invariant test — #15943 and #15944 fixed silent global-phase drops in template optimization; the scaffold tests for it.
- mpl visualization snapshot (image-tests workflow gates merge).
- `features_circuits` reno entry.

## Python scaffold

`qiskit/circuit/library/standard_gates/xy.py` (example for a hypothetical `XYGate`):

```python
# This file is part of Qiskit.
#
# (C) Copyright IBM ...
#
# Licensed under the Apache License, Version 2.0 ...

"""XY rotation gate."""

from __future__ import annotations

import math

import numpy as np

from qiskit.circuit._utils import with_gate_array
from qiskit.circuit.gate import Gate
from qiskit.circuit.parameterexpression import ParameterValueType
from qiskit.circuit.quantumregister import QuantumRegister
from qiskit.circuit.singleton import SingletonGate, stdlib_singleton_key
from qiskit._accelerate.circuit import StandardGate


_XY_ARRAY = ...  # Define the constant matrix or omit if parametric.


@with_gate_array(_XY_ARRAY)
class XYGate(SingletonGate):
    r"""XY rotation gate.

    **Circuit symbol:**

    .. parsed-literal::

             ┌─────────┐
        q_0: ┤0        ├
             │  Xy(θ)  │
        q_1: ┤1        ├
             └─────────┘

    **Matrix representation:**

    .. math::

        XY(\theta) = \begin{pmatrix}
            ...
        \end{pmatrix}
    """

    _standard_gate = StandardGate.XY  # link to Rust enum

    def __init__(
        self,
        theta: ParameterValueType,
        label: str | None = None,
    ):
        super().__init__("xy", 2, [theta], label=label)

    _singleton_lookup_key = stdlib_singleton_key(num_qubits=2)

    def _define(self):
        # Decomposition into existing gates, used by transpilation.
        from qiskit.circuit.quantumcircuit import QuantumCircuit
        # ... build the QuantumCircuit decomposition
        qc = QuantumCircuit(2, name=self.name)
        # ... emit gates
        self.definition = qc

    def inverse(self, annotated: bool = False):
        return XYGate(-self.params[0])
```

Notes:

- `from __future__ import annotations` (§11.9.2).
- Modern union syntax (`str | None`).
- `r"""..."""` so `\theta`, `\begin{}` aren't escape-interpreted.
- LaTeX matrix and circuit symbol are part of the docstring — Sphinx + Napoleon Google style.
- `@with_gate_array` provides `.to_matrix()` from the constant `_XY_ARRAY` for non-parametric gates. For parametric gates, override `__array__` instead.

## Rust enum entry

`crates/circuit/src/operations/standard_gate*.rs` holds the `StandardGate` enum. Add a new variant:

```rust
#[pyclass(eq, eq_int, module = "qiskit._accelerate.circuit", frozen)]
#[derive(Clone, Debug, PartialEq, Eq, Hash, IntoPyObject, IntoPyObjectRef)]
pub enum StandardGate {
    // ... existing variants
    XY,
}
```

And the matching matrix/decomposition logic in the same crate. Read existing variants (search for `StandardGate::X` or `StandardGate::RZ`) for the exact place each piece goes.

If your gate is *not* hot enough to warrant a Rust matrix path, you can leave the Rust side as a thin enum entry and let Python compute the matrix. But the enum entry is required so QPY / serialization / pass-manager dispatch can recognize it.

## Test scaffold

`test/python/circuit/library/test_xy_gate.py`:

```python
import math
import unittest

import numpy as np

from qiskit.circuit import QuantumCircuit
from qiskit.circuit.library import XYGate
from qiskit.quantum_info import Operator
from test.utils.base import QiskitTestCase


class TestXYGate(QiskitTestCase):

    def test_matrix_is_unitary(self):
        for theta in [0.0, 0.5, math.pi, -1.7]:
            mat = Operator(XYGate(theta)).data
            self.assertTrue(np.allclose(mat @ mat.conj().T, np.eye(4)))

    def test_inverse(self):
        # Inverse must be the unitary inverse, including global phase.
        for theta in [0.3, math.pi / 2]:
            g = XYGate(theta)
            inv = g.inverse()
            both = Operator(g).compose(Operator(inv))
            self.assertTrue(np.allclose(both.data, np.eye(4)))

    def test_global_phase_preserved_in_definition(self):
        # The decomposition must reproduce the matrix exactly,
        # including any global phase. #15943 and #15944 fixed silent
        # global-phase drops in templates; this is the regression
        # test that catches it for new gates.
        for theta in [0.4, math.pi / 3]:
            g = XYGate(theta)
            defn = g.definition
            self.assertTrue(np.allclose(
                Operator(defn).data, Operator(g).data
            ))

    def test_singleton(self):
        # SingletonGate: identical-arg instances are the same object.
        # (Only meaningful if your gate has no params.)
        # For parametric gates, drop this test or assert equality only.

    def test_qasm_roundtrip(self):
        qc = QuantumCircuit(2)
        qc.append(XYGate(0.7), [0, 1])
        # If your gate has a registered OpenQASM 2/3 mapping, test it.
```

## Visualization snapshot

If the gate is drawn by the mpl drawer with custom symbol, the image-tests workflow (`test/ipynb/mpl/`) needs a snapshot. After implementing, regenerate the baseline locally and commit. #16074 (CPhase visualization) showed reviewers ask for the snapshot to be visually inspected, not just regenerated.

## Reno entry

```yaml
---
features_circuits:
  - |
    Added :class:`~qiskit.circuit.library.XYGate`, a 2-qubit XY rotation gate.
    The gate is parameterized by a rotation angle :math:`\theta`.
```

`Changelog: Added` label. See [[qiskit-release-notes]].

## Heuristics

- **Match an existing nearby gate's structure.** `RZGate`, `RXGate`, `XXMinusYYGate` are good templates — open one and follow its scaffolding line for line.
- **Test global phase explicitly.** Silent `global_phase` drops are a documented recurring bug class (§8.3, §8.12 obs 2; #15943, #15944, #15816).
- **Don't over-document the `__init__`.** Keep the constructor docstring minimal — the class-level docstring is where the math goes.
- **Singleton vs not.** If the gate has no params, `SingletonGate` + `stdlib_singleton_key` saves memory. If it's parametric, parametric gates aren't singletons by design.
- **OpenQASM mapping.** If the gate has a standard QASM 2 / QASM 3 name, register the mapping in the relevant exporter / importer; otherwise it round-trips via decomposition.

## Related skills

- [[qiskit-py-rust-bridge]] — adding the Rust enum variant requires no new submodule, but understand the pattern.
- [[qiskit-release-notes]] — `features_circuits` YAML.
- [[qiskit-good-pr-checklist]] — confirms the global-phase test, snapshot, and reno entry exist.
- [[qiskit-coding-conventions]] — black/ruff/D417.
