---
name: qiskit-add-transpiler-pass
description: Scaffold a Qiskit transpiler pass — `AnalysisPass` or `TransformationPass` — with the obligatory `run(self, dag)` override, control-flow recursion into `ControlFlowOp.blocks`, a control-flow regression test, and (for parallel passes) a `Changelog: Performance` reno entry. Use whenever the user asks to add a transpiler pass, write a new optimization pass, count something across a DAG, transform a DAG, or modify the transpiler. Front-loads the control-flow test that maintainers consistently ask for — missing `ControlFlowOp.blocks` recursion is the #1 recurring bug category in Qiskit.
---

# Add a Qiskit transpiler pass

Transpiler passes live under `qiskit/transpiler/passes/<category>/`. Categories: `analysis/`, `optimization/`, `routing/`, `layout/`, `scheduling/`, `synthesis/`, `basis/`, `utils/`. Pick the directory that matches the pass's primary effect.

The single biggest recurring bug category in Qiskit (§8.1) is transpiler passes that don't recurse into `ControlFlowOp.blocks`. Eight separate PRs in a 6-month window fixed this for previously-merged passes (#15875, #15581/#15626, #15413, #15083, #15143, #15155, #15941, #15147). This skill bakes the fix into the scaffold.

## Decide: AnalysisPass or TransformationPass

- **`AnalysisPass`** — reads the DAG, writes only to `self.property_set`. Cannot mutate the circuit.
- **`TransformationPass`** — returns a new DAG (mutated copy). `run(self, dag)` must `return dag` (or a new DAG).

Both inherit from `BasePass` (`qiskit/transpiler/basepasses.py:29-100`), whose `MetaPass` metaclass auto-hashes constructor arguments so the pass manager can deduplicate identical passes (§11.9.5). Don't override `__hash__` or `__eq__`.

## Python scaffold

```python
# qiskit/transpiler/passes/analysis/measurement_count.py
from __future__ import annotations

from typing import TYPE_CHECKING

from qiskit.circuit.controlflow import ControlFlowOp
from qiskit.transpiler.basepasses import AnalysisPass

if TYPE_CHECKING:
    from qiskit.dagcircuit import DAGCircuit


class MeasurementCount(AnalysisPass):
    r"""Count measurements per qubit, including inside ``ControlFlowOp``.

    Stores a dict keyed by qubit in ``property_set["measurement_count"]``.
    """

    def run(self, dag: DAGCircuit) -> None:
        counts = self._count(dag)
        self.property_set["measurement_count"] = counts

    def _count(self, dag: DAGCircuit) -> dict:
        counts: dict = {}
        for node in dag.op_nodes():
            if isinstance(node.op, ControlFlowOp):
                # Recurse into every block. Missing this recursion is
                # the largest single bug category for transpiler passes.
                for block in node.op.blocks:
                    block_dag = circuit_to_dag(block)
                    for q, n in self._count(block_dag).items():
                        counts[q] = counts.get(q, 0) + n
                continue
            if node.op.name == "measure":
                q = node.qargs[0]
                counts[q] = counts.get(q, 0) + 1
        return counts
```

Notes:

- `from __future__ import annotations` (§11.9.2) and `if TYPE_CHECKING:` for the `DAGCircuit` import (avoid circular import).
- Don't write a `__init__` summary that just says "Initialize the pass" — Cryoris' nit, *"This is true for every analysis pass and doesn't need to be pointed out explicitly."*
- Use `:class:` Sphinx roles in docstrings (Google style; D417 enforces argument documentation).

## Test scaffold (Mandatory)

Test file mirrors source: `test/python/transpiler/test_measurement_count.py`. Both happy-path **and** control-flow tests are required.

```python
# test/python/transpiler/test_measurement_count.py
from qiskit.circuit import QuantumCircuit, QuantumRegister, ClassicalRegister
from qiskit.converters import circuit_to_dag
from qiskit.transpiler.passes import MeasurementCount
from test.utils.base import QiskitTestCase


class TestMeasurementCount(QiskitTestCase):

    def test_simple(self):
        qr = QuantumRegister(2)
        cr = ClassicalRegister(2)
        qc = QuantumCircuit(qr, cr)
        qc.measure(qr[0], cr[0])
        qc.measure(qr[0], cr[1])  # qr[0] measured twice
        qc.measure(qr[1], cr[0])

        pass_ = MeasurementCount()
        pass_.run(circuit_to_dag(qc))
        counts = pass_.property_set["measurement_count"]
        self.assertEqual(counts[qr[0]], 2)
        self.assertEqual(counts[qr[1]], 1)

    def test_control_flow_if(self):
        # The recurring bug: passes that ignore ControlFlowOp.blocks
        # silently undercount. This is the test reviewers add as a
        # near-Mandatory ask (§11.5.3).
        qr = QuantumRegister(1)
        cr = ClassicalRegister(1)
        qc = QuantumCircuit(qr, cr)
        with qc.if_test((cr, 0)):
            qc.measure(qr[0], cr[0])

        pass_ = MeasurementCount()
        pass_.run(circuit_to_dag(qc))
        counts = pass_.property_set["measurement_count"]
        self.assertEqual(counts[qr[0]], 1)

    def test_control_flow_nested(self):
        qr = QuantumRegister(1)
        cr = ClassicalRegister(1)
        qc = QuantumCircuit(qr, cr)
        with qc.while_loop((cr, 0)):
            with qc.if_test((cr, 0)):
                qc.measure(qr[0], cr[0])
        pass_ = MeasurementCount()
        pass_.run(circuit_to_dag(qc))
        self.assertEqual(pass_.property_set["measurement_count"][qr[0]], 1)
```

Cover at minimum:

- Empty circuit (#15147 fixed `Schedule` analysis on empty circuits — common edge case).
- Each `ControlFlowOp` flavor that's relevant (`IfElseOp`, `ForLoopOp`, `WhileLoopOp`, `BreakLoopOp`, `ContinueLoopOp`, `SwitchCaseOp`).
- Nested control flow.
- Property-set determinism if the pass is `AnalysisPass`; output ordering if `TransformationPass`.

## Wire it into `__init__.py`

If the pass is meant to be importable from `qiskit.transpiler.passes`, add it to `qiskit/transpiler/passes/__init__.py`. Otherwise it's available only via the full path.

## Reno entry

Use [[qiskit-release-notes]] to write `releasenotes/notes/<slug>-<hash>.yaml` under `features_transpiler`. If the pass is parallel or replaces a serial implementation, add `Changelog: Performance` and an ASV table (see [[qiskit-performance-benchmarks]]).

## Rust counterpart (optional)

If the pass is hot enough to warrant Rust:

1. Add the implementation under `crates/transpiler/src/`.
2. Expose via PyO3 in `crates/pyext/src/`.
3. Register the new submodule in `qiskit/__init__.py:49-146` (`sys.modules[...] = ...`) — see [[qiskit-py-rust-bridge]].
4. Use `import_exception!(qiskit.exceptions, TranspilerError)` for error returns (§11.3.5).
5. Avoid `expect`/panics on user-reachable paths (§11.3.4) — see [[qiskit-rust-performance-idioms]].
6. If the Rust path uses `par_iter`, gate ordering carefully — see [[qiskit-determinism-audit]].

## Heuristics

- **Always recurse into `ControlFlowOp.blocks`.** Even if the test suite happens to not include a control-flow case in the early reviews, the bug will surface later — eight previously-merged passes had to be patched for this in the last 6 months alone.
- **Don't over-narrow types.** Cryoris in #15832: *"Why change from `Iterable` to `set`? That seems more restrictive."*
- **Use `dag.op_nodes()` to iterate.** Don't rely on edge order (§11.8.2; #15040 fixed an edge-order non-determinism).
- **Skip `Barrier` and `Measure` deliberately** if your pass only cares about gates — be explicit about the filter.

## Related skills

- [[qiskit-good-pr-checklist]] — verify all gates pass before requesting review.
- [[qiskit-release-notes]] — write the YAML.
- [[qiskit-performance-benchmarks]] — required if the pass changes a heuristic or replaces a hot path.
- [[qiskit-determinism-audit]] — if the pass parallelizes anything.
- [[qiskit-py-rust-bridge]] — Rust counterpart wiring.
- [[qiskit-deprecation]] — if the new pass replaces an old one.
