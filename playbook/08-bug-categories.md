# 8. Recurring Bug Categories

Distilled from ~70 bugfix PRs in the Nov 2025 – May 2026 window plus targeted
`git log --grep="Fix"` scans. Categories are roughly ranked by volume.

## 8.1 Control-flow correctness (highest volume) — High confidence

Bugs in nested `ControlFlowOp` / `IfElseOp` / `BreakLoopOp` / loop builders. The control-flow
data model is rich and many transpiler passes still need to recurse through blocks.

- **#15875** "Fix `BasisTranslator` processing of nested `ControlFlowOp`"
- **#15581 / #15626** `BreakLoopOp` missing `.blocks` attribute (two takes — first didn't
  cover all paths)
- **#15413** Control-flow builders with uncached Python control-flow
- **#15083** Qubit mapping in `ConsolidateBlocks` control-flow blocks
- **#15143** Incorrect mapping of ControlFlow block qargs in `BasisTranslator`
- **#15155** Textdrawer for control-flow with different regs
- **#15941** ControlFlow support in `ConvertToPauliRotations`
- **#15147** Schedule analysis passes with empty circuits
- **#15884** auto-backport of #15875 to stable

**Pattern:** new transpiler passes routinely miss recursive descent into `ControlFlowOp.blocks`;
reviewers add control-flow-specific tests as a near-mandatory ask.

## 8.2 QPY (de)serialization round-trip — High confidence

Persistent surface area for round-trip and version-compat bugs:

- **#15623** user-defined register named `'ancilla'`
- **#15649** annotation handling in Rust-space QPY
- **#15847** Rust/Python compatibility fixes
- **#16076** loading delay-integer durations incorrectly
- **#15663** Rust QPY version 13 compatibility
- **#15158** `qpy.dump` failure with gzip write streams
- **#15934** rewrite of `ParameterExpression` handling in pure Polish form (a major
  correctness clean-up)

**Pattern:** QPY format-version bumps and Rust port of QPY are still settling; the
`test/qpy_compat/` suite catches most regressions.

## 8.3 Synthesis / decomposition correctness — High confidence

Numerical-edge / corner-case errors:

- **#15781** `synth_clifford_depth_lnn` for single-qubit Cliffords
- **#16004** `synth_qft_line` correctness with ≥32 qubits
- **#15735** bugfix in QSD's `extract_multiplex_blocks`
- **#15672 / #15673** MCX / multi-controlled gates with 0 control qubits
- **#15816** `PauliEvolutionGate` trace and dim calculation
- **#15807** approximate-by-default behaviour of `UnitarySynthesis`
- **#15943** `TemplateOptimization` dropping `global_phase`
- **#15944** `clifford_6_4` template missing `global_phase` causing silent rejection
- **#15401** Clifford+T transpilation: incorrect arg to `generate_unroll_3q`

**Pattern:** silently-dropped `global_phase` is a recurring trap; multiple synthesis bugs are
found by tests that check unitary equivalence including the global phase.

## 8.4 Commutation / cancellation — High confidence

- **#16023** commutation between two PPMs
- **#15933** matrix-size enforcement in `CommutationChecker`
- **#15925** Pauli ↔ standard-gate commutation (replaces reverted **#15488**, see
  **#15906** for the revert)
- **#16054** panic in `RemoveIdentityEquivalent` with `ParameterVector` global phase
- **#16124** CS/CSdg inverse cancellation — *closed without merge*; the proposed fix made the
  reproducer worse.

## 8.5 Visualization — High confidence

- **#15973** barrier label truncation in matplotlib drawer
- **#15494** `plot_state_qsphere` phase-anchor bias from solver noise
- **#15421** timeline drawer for gates without unitary in target
- **#15262** text drawer layering for classical wires
- **#16080** clarify `DraperQFTAdder` diagram ordering
- **#16074** update CPhase gate visualization

**Pattern:** snapshot tests in `test/ipynb/mpl/` catch most regressions; reviewers ask for the
snapshot baseline to be regenerated.

## 8.6 Parameter / ParameterExpression — Medium-High confidence

- **#15642** `ParameterExpression.sympify()` for `RPOW`
- **#15646** `QuantumCircuit.repeat` with parameterized gates
- **#15436** parameter extraction for arrays with single element
- **#15745** parameter count for `delay`
- **#15763** parameter handling in PPR
- **#15809** integer→float coercion when appending PPR
- **#15934** ParameterExpression pure-Polish rewrite (correctness clean-up)

## 8.7 Memory / file-handle / panics / leaks — Medium confidence

- **#16156** file leak from tests
- **#15332** memory leak in `test_get_gate_counts`
- **#15049** UB invocation in `SparseObservable` C API test
- **#16054** panic on parameterized global phase
- **#15635** avoid panics in Quantum Shannon Decomposition Rust code

## 8.8 C API / FFI / build — Medium confidence

- **#16113** `restype` for void-returning C functions
- **#15967** C transpiler level-3 optimisation loop (potential infinite loop flagged by mtreinish)
- **#15049** SparseObservable C API UB
- Rolling clippy-warning fixes from Rust toolchain churn: **#15280**, **#15107**, **#15716**,
  **#15804**, **#16052**

## 8.9 Threading / non-determinism — Medium confidence

- **#15040** edge-order non-determinism when adding DAG nodes
- **#15410** "Stop using a parallel sort in disjoint utils" — parallel sort introduced
  ordering non-determinism

**Pattern:** parallel implementations occasionally trade determinism for speed; reviewers
require comparison data for behavior-changing parallelism (#14911 Sabre lookahead).

## 8.10 Docs / typos — High volume, low severity

A `codespell`-driven sweep happened in **#15683**; the `ihincks` series spread typo fixes
across most packages: **#15697**, **#15701**, **#15706**, **#15722**, **#15725**, **#15729**,
**#15712**, **#15771**, **#15755**, **#15743**.

Reviewers tolerate but increasingly prefer **single combined sweeps** over many tiny PRs (see
maintainer feedback on #15279 — *"is there a less-boilerplate way to expand this?"*).

## 8.11 Reverts in the sample window

- **#15906** Revert of **#15488** Pauli ↔ standard-gate commutation; replaced by **#15925**.
- **#16146** Revert of **#15931** which inflated PGO QV circuit from 100→193 qubits, slowing
  profile collection.

**Pattern:** reverts are explicit, well-described, and followed by a corrected PR. Reverts are
rare (≈1% of merges in the sample).

## 8.12 Cross-cutting observations

1. **Rust port of long-standing Python paths is the biggest single source of fresh bugs.**
   New port + careful comparison against Python baseline is the dominant testing strategy.
2. **`global_phase` is a frequent silent-failure mode** in synthesis and template-optimization
   PRs.
3. **Empty / zero-size / negative-control corner cases** keep appearing in MCX and synthesis
   code paths (#15672/#15673, #15147).
4. **Backports happen for fixes, not features.** Most `stable backport potential`-labeled
   PRs in the sample are bug-class PRs from §8.1–§8.6.

## 8.13 PR numbers cited in this document

15040, 15049, 15083, 15107, 15143, 15147, 15155, 15158, 15262, 15279, 15280, 15332, 15401,
15410, 15413, 15421, 15436, 15488, 15494, 15581, 15623, 15626, 15635, 15642, 15646, 15649,
15663, 15672, 15673, 15683, 15697, 15701, 15706, 15712, 15716, 15722, 15725, 15729, 15735,
15743, 15745, 15755, 15763, 15771, 15781, 15804, 15807, 15809, 15816, 15847, 15875, 15884,
15906, 15925, 15931, 15933, 15934, 15941, 15943, 15944, 15967, 15973, 16004, 16023, 16052,
16054, 16074, 16076, 16080, 16113, 16124, 16146, 16156.
