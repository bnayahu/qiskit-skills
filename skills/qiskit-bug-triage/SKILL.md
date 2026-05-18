---
name: qiskit-bug-triage
description: Classify a reported Qiskit bug into one of the recurring categories — control-flow correctness, QPY round-trip, synthesis correctness (incl. silent `global_phase` drops), commutation/cancellation, visualization, parameter expressions, panics/leaks, C API/FFI, threading non-determinism, docs/typos — and pull the relevant past PRs as starting points. Use whenever the user reports a bug, asks "where do I start fixing this", or needs to triage a GitHub issue. Maps incoming reports to the right area + prior art.
---

# Qiskit bug triage

Distilled from ~70 bugfix PRs in the last 6 months. The recurring categories below cover ≥90% of bugs in the sample. For each category: the symptoms, the likely root cause, and prior PRs you can grep for shape.

## How to use

Read the issue or reproducer. Match it to a category. Pull the cited PR list. Read 2–3 of those PRs to understand the typical fix shape. Then trace the bad value backwards to the **right abstraction layer** (§11.11.8 — wrong-layer fixes get closed; #16062 is the canonical example).

## 8.1 Control-flow correctness (highest volume) — High confidence

**Symptoms.** Pass/transformation produces wrong output when the circuit contains `IfElseOp`, `ForLoopOp`, `WhileLoopOp`, `BreakLoopOp`, `ContinueLoopOp`, `SwitchCaseOp`. Silent miscount or skipped translation.

**Root cause.** The pass doesn't recurse into `ControlFlowOp.blocks`. Each block is a sub-`QuantumCircuit` that needs the same treatment.

**Prior PRs.** #15875 (BasisTranslator nested), #15581/#15626 (BreakLoopOp `.blocks`), #15413 (uncached control-flow in builders), #15083 (qubit mapping in ConsolidateBlocks), #15143 (BasisTranslator block qargs), #15155 (textdrawer with different regs), #15941 (ConvertToPauliRotations), #15147 (Schedule analysis on empty circuits), #15884 (auto-backport).

**Fix shape.** In the pass's `run(self, dag)`, when iterating `dag.op_nodes()`:

```python
for node in dag.op_nodes():
    if isinstance(node.op, ControlFlowOp):
        for block in node.op.blocks:
            block_dag = circuit_to_dag(block)
            self.run(block_dag)  # or whatever the recursive call is
        continue
    # ...
```

Always add a regression test using nested control flow. See [[qiskit-add-transpiler-pass]].

## 8.2 QPY (de)serialization round-trip — High confidence

**Symptoms.** `qpy.load` produces a different circuit than `qpy.dump` was given, or fails on a circuit that should round-trip. Often surfaces only at certain format versions.

**Root cause.** Format-version boundary, Rust ↔ Python parity gap, gzip-stream framing, or a new type added on one side but not the other.

**Prior PRs.** #15623 (user-defined `'ancilla'` register), #15649 (annotations in Rust QPY), #15847 (Rust/Python compat), #16076 (delay integer durations), #15663 (Rust QPY v13), #15158 (gzip write streams), #15934 (`ParameterExpression` Polish-form rewrite).

**Fix shape.** Add a fixture in `test/qpy_compat/`, increment the format version in *both* Python and Rust, verify round-trip on the corpus. See [[qiskit-qpy-compatibility]].

## 8.3 Synthesis / decomposition correctness — High confidence

**Symptoms.** Output unitary differs from the input gate's matrix, especially in global phase. Edge cases at boundary qubit counts.

**Root cause.** Silent `global_phase` drop is the recurring trap (§8.12 obs 2). Boundary cases for MCX (zero or negative controls) and large QFT (≥32 qubits).

**Prior PRs.** #15781 (Clifford depth-LNN single-qubit), #16004 (`synth_qft_line` ≥32 qubits), #15735 (QSD `extract_multiplex_blocks`), #15672/#15673 (MCX with 0 controls), #15816 (`PauliEvolutionGate` trace/dim), #15807 (UnitarySynthesis approximate-by-default), #15943 (`TemplateOptimization` dropping `global_phase`), #15944 (`clifford_6_4` template missing `global_phase`), #15401 (Clifford+T `generate_unroll_3q`).

**Fix shape.** Add a unitary-equivalence test that asserts equality including global phase (`Operator(synthesized) == Operator(target)` — `Operator.__eq__` includes phase).

## 8.4 Commutation / cancellation — High confidence

**Symptoms.** Two gates that should cancel/commute don't, or two that shouldn't do.

**Root cause.** Heuristic disagreement, missing matrix-size check, parameter expression handling.

**Prior PRs.** #16023 (PPM ↔ PPM), #15933 (matrix-size in `CommutationChecker`), #15925 (Pauli ↔ standard-gate; replaces reverted #15488; see #15906 for the revert), #16054 (panic in `RemoveIdentityEquivalent` with parametric global phase), #16124 (CS/CSdg — *closed without merge* because the proposed fix made the reproducer worse).

**Fix shape.** Test the *exact* reproducer first. #16124 was closed because the proposed fix actually broke the named reproducer. Run `cs(0,1).compose(csdg(1,0))` and verify cancellation, then verify the bug, then fix.

## 8.5 Visualization — High confidence

**Symptoms.** Snapshot mismatch, layout glitch, label truncation.

**Root cause.** Drawer corner case; sometimes a target/calibration mismatch.

**Prior PRs.** #15973 (barrier label truncation in mpl), #15494 (`plot_state_qsphere` phase-anchor noise), #15421 (timeline drawer for gates without unitary in target), #15262 (text drawer layering for classical wires), #16080 (`DraperQFTAdder` diagram ordering), #16074 (CPhase visualization update).

**Fix shape.** Regenerate `test/ipynb/mpl/` baselines locally and **visually inspect** (§11.5.5). Reviewers don't accept blind regeneration.

## 8.6 Parameter / ParameterExpression — Medium-High confidence

**Symptoms.** Parameter handling fails on a specific operation (`sympify`, `repeat`, `delay`, `PPR`, integer→float coercion).

**Prior PRs.** #15642 (`sympify` for `RPOW`), #15646 (`QuantumCircuit.repeat` with parameterized gates), #15436 (parameter extraction for single-element arrays), #15745 (parameter count for `delay`), #15763 (PPR), #15809 (integer→float coercion when appending PPR), #15934 (Polish-form rewrite — broad correctness clean-up).

## 8.7 Memory / file-handle / panics / leaks — Medium confidence

**Symptoms.** Test suite flakes, file handles not released, RSS growth, unexpected `RuntimeError` from the Rust side.

**Prior PRs.** #16156 (file leak from tests), #15332 (memory leak in `test_get_gate_counts`), #15049 (UB in `SparseObservable` C API test), #16054 (panic on parametric global phase), #15635 (panics in QSD Rust).

**Fix shape.** For panics, replace `expect`/`unwrap` with `?` propagation or compile-time invariants — see [[qiskit-rust-performance-idioms]]. For file handles, use `with` / context managers.

## 8.8 C API / FFI / build — Medium confidence

**Symptoms.** UBSan / miri error, infinite loop in optimization level 3, wrong `restype` on a void function.

**Prior PRs.** #16113 (`restype` for void-returning C functions), #15967 (C transpiler level-3 potential infinite loop), #15049 (SparseObservable UB), and rolling clippy-warning fixes from toolchain churn (#15280, #15107, #15716, #15804, #16052).

**Fix shape.** Run `make ctest` (UBSan) and `miri.yml`-equivalent (`cargo +nightly miri test`) on the path. See [[qiskit-security-review]].

## 8.9 Threading / non-determinism — Medium confidence

**Symptoms.** Output differs run-to-run with the same seed, even though no randomness is supposed to be involved.

**Prior PRs.** #15040 (DAG edge-order non-determinism), #15410 ("Stop using a parallel sort in disjoint utils" — reverted because the parallel sort introduced ordering non-determinism).

**Fix shape.** See [[qiskit-determinism-audit]]. Compute in parallel, commit serially.

## 8.10 Docs / typos — High volume, low severity

**Pattern.** A `codespell`-driven sweep happened in #15683; the `ihincks` series spread typo fixes across most packages: #15697, #15701, #15706, #15722, #15725, #15729, #15712, #15771, #15755, #15743.

Reviewers tolerate but increasingly prefer **single combined sweeps** over many tiny PRs (jakelishman in #15279: *"is there a less-boilerplate way to expand this?"*). For new typo fixes, batch them.

## 8.11 Reverts in the sample window

- **#15906** Revert of #15488 (Pauli ↔ standard-gate commutation); replaced by #15925.
- **#16146** Revert of #15931 which inflated PGO QV training circuit from 100→193 qubits, slowing profile collection.

Reverts are explicit, well-described, and followed by a corrected PR. Reverts are rare (~1% of merges).

## Cross-cutting observations

1. **Rust port of long-standing Python paths is the biggest single source of fresh bugs.** Always compare against the Python baseline.
2. **`global_phase` is a frequent silent-failure mode** in synthesis and template-optimization PRs.
3. **Empty / zero-size / negative-control corner cases** keep appearing in MCX and synthesis paths.
4. **Backports happen for fixes, not features.** §11.11.4.

## Heuristics

- **Read the cited PRs before writing the fix.** They show the fix shape and the test shape that maintainers accept.
- **Identify the right abstraction layer first** (§11.11.8). Trace the bad value backwards to where it first becomes wrong.
- **Add the regression test before the fix.** Verify it fails. Then fix. Verify it passes. See [[qiskit-testing]].

## Related skills

- [[qiskit-add-transpiler-pass]] — control-flow recursion scaffold.
- [[qiskit-qpy-compatibility]] — QPY round-trip fixes.
- [[qiskit-determinism-audit]] — non-determinism fixes.
- [[qiskit-security-review]] — C API / FFI / unsafe fixes.
- [[qiskit-good-pr-checklist]] — what the fix needs to ship with.
- [[qiskit-architecture-map]] — where each subsystem lives.
