# Skill Application — Latest 10 Open `good first issue` Tickets

A walkthrough of the ten most recently opened (still-open) issues labeled
`good first issue` on `Qiskit/qiskit`, mapped against the skills proposed in
[`skills-design.md`](skills-design.md). For each issue: the category, the skills that would fire and at
which step, and the order in which they'd compose into a complete fix-and-PR cycle.

Issues were retrieved via
`gh issue list --repo Qiskit/qiskit --label "good first issue" --state open --limit 10`
on 2026-05-18.

## Coverage map

| # | Issue | Category | Primary skills |
|---|---|---|---|
| 1 | [#16168](https://github.com/Qiskit/qiskit/issues/16168) `MultiplierGate(1, 1).decompose()` fails | Circuit library bug | `qiskit-bug-triage`, `qiskit-architecture-map`, `qiskit-testing`, `qiskit-good-pr-checklist`, `qiskit-release-notes`, `qiskit-pr-preparation`, `qiskit-backport-process` |
| 2 | [#16166](https://github.com/Qiskit/qiskit/issues/16166) `dagdependency_to_circuit()` drops `global_phase` | Synthesis / `global_phase` silent drop | `qiskit-bug-triage`, `qiskit-architecture-map`, `qiskit-testing`, `qiskit-release-notes`, `qiskit-pr-preparation`, `qiskit-backport-process` |
| 3 | [#16138](https://github.com/Qiskit/qiskit/issues/16138) `random_clifford_circuit` non-deterministic | Threading / non-determinism | `qiskit-bug-triage`, `qiskit-determinism-audit`, `qiskit-testing`, `qiskit-release-notes`, `qiskit-pr-preparation`, `qiskit-backport-process` |
| 4 | [#16097](https://github.com/Qiskit/qiskit/issues/16097) `qasm3.dumps_experimental` wrong delay units | Rust QASM3 exporter bug | `qiskit-bug-triage`, `qiskit-py-rust-bridge`, `qiskit-coding-conventions`, `qiskit-testing`, `qiskit-anti-patterns` (LLM disclosure), `qiskit-release-notes`, `qiskit-pr-preparation`, `qiskit-backport-process` |
| 5 | [#15370](https://github.com/Qiskit/qiskit/issues/15370) Memory safety in C API uninitialized buffers | C API / unsafe Rust | `qiskit-architecture-map`, `qiskit-security-review`, `qiskit-rust-performance-idioms`, `qiskit-testing`, `qiskit-ci-workflows` (miri), `qiskit-release-notes`, `qiskit-pr-preparation` |
| 6 | [#15307](https://github.com/Qiskit/qiskit/issues/15307) Expose Target angle bounds + angle-wrapping to C API | C API feature | `qiskit-architecture-map`, `qiskit-py-rust-bridge`, `qiskit-api-evolution`, `qiskit-error-handling`, `qiskit-testing`, `qiskit-release-notes`, `qiskit-pr-preparation` |
| 7 | [#15097](https://github.com/Qiskit/qiskit/issues/15097) `printf` → `fprintf` in C tests | Doc-shape cleanup | `qiskit-coding-conventions`, `qiskit-anti-patterns` (boilerplate proliferation), `qiskit-pr-preparation` |
| 8 | [#15067](https://github.com/Qiskit/qiskit/issues/15067) Re-export `transpile` from `qiskit.transpiler` | API surface tidy | `qiskit-architecture-map`, `qiskit-api-evolution`, `qiskit-testing`, `qiskit-release-notes`, `qiskit-pr-preparation` |
| 9 | [#15066](https://github.com/Qiskit/qiskit/issues/15066) `transpile(qc, target_as_backend)` | API enhancement | `qiskit-api-evolution`, `qiskit-error-handling`, `qiskit-testing`, `qiskit-release-notes`, `qiskit-pr-preparation` |
| 10 | [#14115](https://github.com/Qiskit/qiskit/issues/14115) `approximation_degree` on `CommutativeCancellation` | Transpiler arg wire-through | `qiskit-add-transpiler-pass` (modify), `qiskit-architecture-map`, `qiskit-testing`, `qiskit-release-notes`, `qiskit-pr-preparation`, `qiskit-backport-process` |

Every issue funnels through the `qiskit-pr-preparation` + `qiskit-good-pr-checklist`
+ `qiskit-release-notes` triad at the end. Below is the per-issue walk-through.

---

## 1. #16168 — `MultiplierGate(1, 1).decompose()` fails

**Symptom.** `MultiplierGate._define()` calls `multiplier_qft_r17(self.num_state_qubits)`
without forwarding `self.num_result_qubits`, producing a 4-qubit definition for a 3-qubit
gate.

**Skill walkthrough.**

1. `qiskit-bug-triage` — categorizes as **§ 8.3 synthesis/decomposition correctness** /
   "argument forwarding" sub-class; pulls cousin PRs **#15735** (QSD
   `extract_multiplex_blocks`), **#15401** (`generate_unroll_3q` arg) for prior art.
2. `qiskit-architecture-map` — points at
   `qiskit/circuit/library/arithmetic/multiplier.py` (Python class) and
   `qiskit/synthesis/arithmetic/multipliers/qft_multiplier.py` (synthesis backend); flags
   that this is a circuit-library bug, *not* a synthesis-algorithm bug — fix in the
   library wrapper, not the algorithm.
3. `qiskit-testing` — generates the regression test the reporter's reproducer demands:
   `MultiplierGate(1, 1).decompose()` round-trip plus a parametric sweep over the
   documented `num_result_qubits ∈ [num_state_qubits, 2*num_state_qubits]` range. Adds a
   unitary-equivalence assertion (the reporter explicitly notes
   `gate.definition.num_qubits` mismatch — equivalence test catches the silent failure).
4. `qiskit-release-notes` — `releasenotes/notes/fix-multiplier-result-width-<hash>.yaml`
   under `fixes`; label `Changelog: Fixed`.
5. `qiskit-good-pr-checklist` — confirms regression test fails on `main`, passes after
   the one-line fix.
6. `qiskit-backport-process` — recommends `stable backport potential` (user-visible bug
   fix in arithmetic library).
7. `qiskit-pr-preparation` — `Fixes #16168`, AI-disclosure box, terse summary.

---

## 2. #16166 — `dagdependency_to_circuit()` drops `DAGDependency.global_phase`

**Symptom.** Phase preserved through `circuit_to_dag` → `dag_to_dagdependency`, lost on
the way back.

**Skill walkthrough.**

1. `qiskit-bug-triage` — recognizes the **silent `global_phase` drop** trap from
   `playbook/08-bug-categories.md` § 8.3 / § 8.12 item 2. Pulls **#15943**
   (`TemplateOptimization` global_phase), **#15944** (clifford_6_4 missing global_phase),
   **#15816** (`PauliEvolutionGate` trace/dim), **#14537** as the same-family fixes.
   Flag: every converter must carry global_phase.
2. `qiskit-architecture-map` — locates
   `qiskit/converters/dagdependency_to_circuit.py` and identifies the missing
   `circuit.global_phase = dagdependency.global_phase` line.
3. `qiskit-testing` — generates a converter round-trip test that asserts not just the
   gate counts but **`Operator(qc).equiv(Operator(out))`** (full unitary, including
   phase). Adds a parametric phase sweep so the test covers `global_phase = 0, π/4, π/2,
   ParameterExpression`.
4. `qiskit-good-pr-checklist` — verifies sister converters
   (`circuit_to_dagdependency`, `dag_to_dagdependency`, `dagdependency_to_dag`) for the
   same omission and bundles in if found, but does *not* widen to unrelated converters
   (avoids the "narrow special-case" anti-pattern).
5. `qiskit-release-notes` — under `fixes`; label `Changelog: Fixed`.
6. `qiskit-backport-process` — backport-eligible.
7. `qiskit-pr-preparation` — done.

---

## 3. #16138 — `random_clifford_circuit` non-deterministic with fixed seed

**Symptom.** `set(_BASIS_1Q.keys()) - {…}` then `list(...)` yields a non-deterministic
gate order, so even with a seeded RNG outputs vary.

**Skill walkthrough.**

1. `qiskit-bug-triage` — categorizes as **§ 8.9 threading / non-determinism**. Closely
   matches **#15040** (DAG edge-order non-determinism) and **#15410** (parallel sort
   reverted) — same category of bug, different mechanism (Python set ordering).
2. `qiskit-determinism-audit` — flags this as a § 11.8.2 Mandatory determinism
   violation; recommends the canonical fix `sorted(set(...) - {...})` so the iteration
   order is deterministic *across processes*, not just within one. Surfaces the
   broader rule: any "set converted to list and indexed by RNG" site is a determinism
   bug.
3. `qiskit-architecture-map` — locates `qiskit/circuit/random/utils.py`; inspects
   neighboring `random_*_circuit` helpers (`random_circuit`, `random_pauli_circuit`)
   for the same bug pattern. If they share it, bundles the fix; if not, scopes tightly.
4. `qiskit-testing` — generates the determinism regression test:
   `random_clifford_circuit(..., seed=0)` called twice → identical `count_ops()`
   *and* identical gate sequence. Cross-process determinism cannot be tested cheaply,
   but per-process plus sorted invariant is sufficient.
5. `qiskit-release-notes` — under `fixes`; label `Changelog: Fixed`.
6. `qiskit-backport-process` — backport-eligible (user-visible reproducibility bug).
7. `qiskit-pr-preparation` — done.

---

## 4. #16097 — `qasm3.dumps_experimental` wrong `ms`/`ps` delay units

**Symptom.** Two one-line bugs in Rust QASM3 exporter: `Millisecond → "us"` typo and
`ps → ns` multiplied instead of divided. The issue body discloses **"This issue was a
collaboration between me and Claude 4.6"** — AI-collab disclosure already present.

**Skill walkthrough.**

1. `qiskit-bug-triage` — categorizes as **§ 8.8 C API / FFI / build** adjacent — it's a
   Rust-side serialization bug. Pulls **#15649** (annotation handling in Rust QPY) and
   **#16076** (QPY delay integer durations) as nearest cousins.
2. `qiskit-py-rust-bridge` — confirms the fix is purely in `crates/qasm3/`; no
   `qiskit/__init__.py` `sys.modules` change needed (no new Rust submodule).
3. `qiskit-architecture-map` — points at `crates/qasm3/src/ast.rs:~141` and
   `crates/qasm3/src/exporter.rs:~1216`.
4. `qiskit-coding-conventions` — runs `cargo fmt`, clippy `--all-targets`, ruff/black
   on the matching Python tests.
5. `qiskit-testing` — generates a parametric test that emits a `Delay` for every
   supported unit (`s`, `ms`, `us`, `ns`, `ps`, `dt`) and parses it back; asserts the
   round-trip duration equals input. The reporter's reproducer is the spec — generalize
   it. Note that `dumps_experimental` emits `ExperimentalWarning`, so the test must
   `warnings.filterwarnings("ignore", category=ExperimentalWarning)` (§ 6.5).
6. `qiskit-anti-patterns` — confirms the issue's AI-collab line satisfies
   `qiskit-pr-preparation`'s AI-disclosure check; ensures the PR carries the same
   disclosure (the rule is human ownership, not no-AI).
7. `qiskit-release-notes` — under `fixes` (`features_qasm` is for new features only);
   label `Changelog: Fixed`. Mentions both unit fixes in the body.
8. `qiskit-backport-process` — backport-eligible (numerically wrong durations would
   silently corrupt user circuits).
9. `qiskit-pr-preparation` — `Fixes #16097`.

---

## 5. #15370 — Memory safety when writing to uninitialized buffers in C API

**Symptom.** Three `transpile_layout.rs` sites cited by jakelishman in
`#15297 (review)` need refactor to initialize before write (avoid UB on read of partially
written buffers).

**Skill walkthrough.**

1. `qiskit-architecture-map` — confirms locus is `crates/cext/src/transpiler/`. C API
   and `qiskit-cext-vtable` are the only crates that surface C ABI; pre-3.0 the C API
   is explicitly unstable per `DEPRECATION.md:258-304`, so refactor without
   deprecation cycle is allowed (§ 6.4).
2. `qiskit-security-review` — primary driver. Walks each `unsafe` block at the cited
   lines; suggests the canonical Rust idiom:
   `MaybeUninit::<T>::uninit_array()` → `assume_init` only after every slot is
   written, *or* a write-only-via-raw-pointer pattern that never reads the
   partially-initialized region.
3. `qiskit-rust-performance-idioms` — secondary: confirms no `expect`/panic remain on
   user-reachable paths after the refactor (§ 11.3.4); confirms no spurious heap
   allocations are introduced (§ 11.7.3); replaces any `expect` with `?` propagation
   into the C result code. Past precedents: **#16010** (VF2 panic removal),
   **#15635** (QSD panic avoidance), **#15049** (UB in `SparseObservable` C API test).
4. `qiskit-ci-workflows` — confirms `miri.yml` excludes FFI tests, so the C API
   refactor cannot be validated by miri; falls back to `make ctest` and UBSan flags
   per § 10.3 of `PLAN.md`. **Note:** miri red on the surrounding pure-Rust callsites
   would catch the regression.
5. `qiskit-testing` — `tox -erust` for unit tests, `make ctest` for C-integration,
   targeted `unsafe`-block tests asserting no read-before-write happens.
6. `qiskit-release-notes` — under `upgrade_c` or `fixes` (depending on whether
   user-visible behavior changes); label likely `Changelog: Build` or `Changelog: None`
   if pure refactor. Pre-3.0 C API churn often rides under `Changelog: None`.
7. `qiskit-pr-preparation` — link `#15297 (comment)` for context.

---

## 6. #15307 — Expose Target angle bounds + angle wrapping pass to the C API

**Symptom.** Feature already exists in Python (added in 2.2); needs a C API wrapper.
Internal callback design was anticipated but C surface was never written.

**Skill walkthrough.**

1. `qiskit-architecture-map` — establishes the layered locations:
   - `crates/transpiler/` for the Rust pass logic;
   - `qiskit/transpiler/passes/optimization/` for the Python pass;
   - `crates/cext/src/transpiler/` + `crates/cext-vtable/` + `crates/bindgen/include/qiskit/` for the C surface.
2. `qiskit-py-rust-bridge` — confirms the FFI plumbing pattern: any new C-exported
   function adds a vtable entry, a header signature via `cbindgen`, and a Rust impl
   that converts C structs to internal types. No `qiskit/__init__.py` changes needed
   (this is C API, not Python C-extension).
3. `qiskit-api-evolution` — pre-3.0 the C API is explicitly unstable
   (`DEPRECATION.md:258-304`), so the addition is purely additive and does not need
   a deprecation cycle. New header symbols get `\qk_deprecated{}` only when retired.
4. `qiskit-error-handling` — calls back into Python registry through the callback
   surface; Rust → Python errors must use `import_exception!(qiskit.exceptions,
   QiskitError)` so users see proper exceptions on misuse.
5. `qiskit-testing` — `test/c/` gets new test for angle-bound queries and
   angle-wrapping pass invocation; Python parity test confirms identical behavior.
6. `qiskit-release-notes` — under `features_c`; label `Changelog: Added`.
7. `qiskit-pr-preparation` — done.

---

## 7. #15097 — `fprintf(stderr, ...)` over `printf(...)` in C tests

**Symptom.** Trivial cleanup of `test/c/`. Per jakelishman comment quoted in the issue:
test reports use `stderr`, so logs would be aligned.

**Skill walkthrough.**

1. `qiskit-coding-conventions` — sweeps `test/c/` for `printf(`, replaces with
   `fprintf(stderr, ` while preserving the format strings; runs `make cformat` (which
   wraps `clang-format`).
2. `qiskit-anti-patterns` — flags the boilerplate-proliferation risk: do this as
   **one** sweep PR, not many small ones (§ 11.9.6, jakelishman's **#15279**
   feedback). Combined sweep is the explicitly preferred form.
3. `qiskit-pr-preparation` — `Changelog: None` (test-only refactor); concise
   description; `Fixes #15097`. No reno entry needed; no backport.

This is the lowest-touch issue in the set — three skills, no testing skill needed
beyond `make ctest` to confirm tests still execute.

---

## 8. #15067 — Re-export `transpile` from `qiskit.transpiler`

**Symptom.** Historical leak: `transpile` lives in `qiskit.compiler` but logically
belongs to `qiskit.transpiler`. Need to expose without breaking existing imports.

**Skill walkthrough.**

1. `qiskit-architecture-map` — confirms `qiskit/compiler/transpiler.py` is the canonical
   home; locates the existing public API entry in `qiskit/transpiler/__init__.py`.
2. `qiskit-api-evolution` — establishes the contract:
   - **Add** `from qiskit.compiler.transpiler import transpile` to
     `qiskit/transpiler/__init__.py`.
   - **Keep** `qiskit.compiler.transpile` working forever (it's documented public API);
     no deprecation needed and no deprecation **wanted** since the issue body says
     *"ensure that `qiskit.compiler` re-exports it for backwards compatibility"*.
   - Verify the docs source-of-truth: only one copy should generate Sphinx pages
     (the autodoc directive points at one canonical path).
3. `qiskit-testing` — adds a small test that `qiskit.transpiler.transpile is
   qiskit.compiler.transpile` (object identity), guarding both import paths against
   future refactors.
4. `qiskit-release-notes` — under `features_transpiler` (or `upgrade_transpiler` if
   we'd rather mark it informational); label `Changelog: Added`.
5. `qiskit-pr-preparation` — done; no backport (it's a feature, not a fix).

---

## 9. #15066 — `transpile` should accept a `Target` as positional `backend`

**Symptom.** Currently `transpile(qc, backend, target, ...)`; users frequently want
`transpile(qc, target)` without wrapping in a fake backend. `generate_preset_pass_manager`
already supports this — make consistent.

**Skill walkthrough.**

1. `qiskit-api-evolution` — additive, not a deprecation. Maps the rule:
   - If second positional is `Target`: route as `backend=None, target=arg`.
   - If second positional is `Target` *and* `target=` keyword is also passed: raise
     `TypeError` (issue spec).
2. `qiskit-error-handling` — the new error is a `TypeError` on argument-conflict
   (boundary type/value mismatch with no domain context — § 11.3.1 carve-out justifies
   `TypeError` over `QiskitError`).
3. `qiskit-testing` — three tests:
   - `transpile(qc, target)` works and is equivalent to
     `transpile(qc, backend=None, target=target)`.
   - `transpile(qc, target, target=target)` raises `TypeError`.
   - Existing `transpile(qc, backend)` calls still pass (no regression).
4. `qiskit-release-notes` — `features_transpiler`; label `Changelog: Added`. Note the
   parity with `generate_preset_pass_manager`.
5. `qiskit-pr-preparation` — done.

---

## 10. #14115 — `approximation_degree` on `CommutativeCancellation`

**Symptom.** Internal call to `CommutationAnalysis` exposes `approximation_degree`, but
the wrapper pass `CommutativeCancellation` doesn't. Wire it through, plumb to preset
pass managers.

**Skill walkthrough.**

1. `qiskit-architecture-map` — `qiskit/transpiler/passes/optimization/commutative_cancellation.py`
   for the wrapper, `commutation_analysis.py` for the analysis pass, and
   `qiskit/transpiler/preset_passmanagers/` for the level 1/2/3 plumbing. Rust
   counterpart in `crates/transpiler/`.
2. `qiskit-add-transpiler-pass` — applies in **modify mode**: adds the new constructor
   arg with default that matches current behavior; ensures `MetaPass` constructor-arg
   auto-hashing still works (so the pass manager dedups equivalent invocations —
   § 11.9.5 Mandatory).
3. `qiskit-testing` — three tests:
   - default `approximation_degree=None` reproduces current behavior;
   - `approximation_degree=0.99` produces approximate cancellation matching
     `CommutationAnalysis`;
   - preset pass manager passes the value through.
   **Control-flow test:** § 11.5.3 — `CommutativeCancellation` operates on the DAG, so
   add a control-flow regression test that wraps the cancellable pair inside an
   `IfElseOp` (the **#15875** / **#15581** / **#15413** category of bug).
4. `qiskit-performance-benchmarks` — § 11.7.2: the change can affect optimization
   results. Reviewers will ask for benchmark numbers (precedent: **#14911** Sabre
   lookahead, alexanderivrii's *"experimental data"* asks). Run ASV on representative
   circuits with `approximation_degree=None` vs. `0.99`.
5. `qiskit-release-notes` — under `features_transpiler`; label `Changelog: Added`.
   May warrant a second `performance` section if benchmarks show speed delta.
6. `qiskit-backport-process` — *no backport* (feature, not bug).
7. `qiskit-pr-preparation` — references mtreinish's PR-#14021 review thread for context.

---

## Skill-utilization summary

| Skill | Hits | Notes |
|---|---|---|
| `qiskit-pr-preparation` | 10/10 | Universal exit ramp |
| `qiskit-release-notes` | 9/10 | Skipped only on test-only refactor (#15097) |
| `qiskit-testing` | 9/10 | Skipped only on #15097 (cleanup) |
| `qiskit-architecture-map` | 8/10 | Skipped on the test-only refactor (#15097) and the API-tweak #15066 |
| `qiskit-bug-triage` | 4/10 | Bug-class issues only |
| `qiskit-backport-process` | 5/10 | User-visible bug fixes only |
| `qiskit-good-pr-checklist` | 2/10 | Used explicitly on multi-step bug fixes; implicit on others |
| `qiskit-api-evolution` | 4/10 | All API-shape issues |
| `qiskit-error-handling` | 2/10 | New raise sites only |
| `qiskit-py-rust-bridge` | 2/10 | Rust-touching issues |
| `qiskit-coding-conventions` | 2/10 | Sweep / format-touching |
| `qiskit-anti-patterns` | 2/10 | Combined-sweep reminder + AI disclosure |
| `qiskit-determinism-audit` | 1/10 | #16138 only |
| `qiskit-security-review` | 1/10 | #15370 only |
| `qiskit-rust-performance-idioms` | 1/10 | #15370 (panic-free + alloc-free refactor) |
| `qiskit-add-transpiler-pass` | 1/10 | #14115 (modify mode) |
| `qiskit-performance-benchmarks` | 1/10 | #14115 (heuristic-touching) |
| `qiskit-ci-workflows` | 1/10 | #15370 (miri/UBSan routing) |

**Skills not exercised by this batch.** `qiskit-add-standard-gate`,
`qiskit-optional-dependencies`, `qiskit-deprecation`, `qiskit-build-system`,
`qiskit-qpy-compatibility`, `qiskit-dependency-policy`, `qiskit-release-ceremony`,
`qiskit-debugging`, `qiskit-code-review`. These cover release-ceremony, deeper-cycle, or
infrastructure work that doesn't surface in a `good first issue` batch — which is the
expected shape: `good first issue` is curated for narrow, well-scoped fixes, so the
skills that fire are heavy on triage, testing, reno, and PR shaping; light on
release engineering and dependency policy.

## Per-issue fix complexity (ordered easiest → hardest)

1. **#15097** — `printf` → `fprintf` sweep. ~3 skills, ~30 min, no reno.
2. **#16097** — Two one-line Rust fixes plus parametric test. Reporter has already
   identified the lines. ~6 skills.
3. **#16166** — One-line converter fix plus phase-preserving round-trip test. ~5 skills.
4. **#16168** — One-line argument-forward fix plus parametric width test. ~6 skills.
5. **#16138** — `set` → `sorted` plus determinism test. Audit cousins for same pattern.
   ~5 skills.
6. **#15067** — Add a re-export, identity test. ~5 skills.
7. **#15066** — Argument-shape change plus three tests, no deprecation. ~5 skills.
8. **#14115** — Constructor-arg threading through three pass-manager levels, control-flow
   test, ASV benchmarks. ~6 skills, hardest of the API tweaks.
9. **#15307** — C API expansion: vtable + header + Rust impl + parity tests. ~6 skills.
10. **#15370** — `unsafe` refactor across three sites, no miri coverage available.
    Highest care needed despite small line count. ~7 skills.

The skill set's coverage is roughly proportional to issue complexity — the simplest
issues consume 3-5 skills, the hardest 7. The triad of `qiskit-pr-preparation`,
`qiskit-release-notes`, and `qiskit-testing` carries the bulk of the load, which
matches the playbook finding that **release notes** and **regression tests** are the two
recurring review-iteration hotspots.
