# Qiskit Skills — Design Plan

A proposed set of Claude skills covering the development and maintenance lifecycle of the
[Qiskit](https://github.com/Qiskit/qiskit) repository. Each skill is grounded in the
playbook (`playbook/00-index.md` — `playbook/11-implicit-conventions.md`) and cites at
least one merged or closed PR where the skill would have shortened review iteration,
prevented a revert, or replaced manual maintainer guidance.

The plan is organized by lifecycle phase. Skills are sized so each one corresponds to a
single, recognizable user intent (e.g. *"add a gate"*, *"prepare a release note"*, *"audit
my PR before requesting review"*) rather than generic mega-skills. Where two concerns are
tightly coupled (e.g. deprecation decorator usage + dual-path tests), they are bundled.

Tier annotations match the playbook's four-tier scale (Mandatory / Preferred /
Historical / Disputed) so the skill can hint why a check matters.

---

## Lifecycle phases

1. [Onboarding & architecture](#1-onboarding--architecture)
2. [Authoring code](#2-authoring-code)
3. [Building & testing](#3-building--testing)
4. [Performance & profiling](#4-performance--profiling)
5. [Dependency & API evolution](#5-dependency--api-evolution)
6. [Pre-PR self-review](#6-pre-pr-self-review)
7. [Code review (reviewer side)](#7-code-review-reviewer-side)
8. [CI/CD & release](#8-cicd--release)
9. [Backports & maintenance](#9-backports--maintenance)
10. [Debugging, security, anti-patterns](#10-debugging-security-anti-patterns)

---

## 1. Onboarding & architecture

### 1.1 `qiskit-architecture-map`

- **Description.** Explain the Qiskit hybrid Python + Rust layout, locate where a feature
  should live, and surface the one-way crate dependency direction.
- **Scope.** Read-only orientation. Answers "if I'm touching X, where is it and what
  else moves with it?" using the cheat-sheet in `playbook/01-architecture.md` § 1.7.
  Covers the 16-crate Cargo workspace, the 18 top-level Python packages, and the
  `qiskit-pyext` → `qiskit-transpiler` → `{circuit, synthesis, quantum-info}` →
  `qiskit-util` direction.
- **Tier.** Mandatory layering (§ 11.2.1).
- **Example use.** *"I want to add a new transpiler pass for Pauli simplification — what
  files do I touch?"* → returns the `qiskit/transpiler/passes/optimization/` location,
  the `crates/transpiler/src/` Rust counterpart if hot, and a reno-entry reminder.
- **Saved-effort PR.** **#16062** (closed): a contributor proposed a fix in the QASM
  exporter, but jakelishman closed it because *"the root fault is not in the exporter
  but in the importer."* A wrong-layer fix that the architecture map would have routed
  correctly upfront.

### 1.2 `qiskit-py-rust-bridge`

- **Description.** Walk through the single-`cdylib` build, the manual `sys.modules`
  registration in `qiskit/__init__.py:49-146`, and the PyO3 init-time rule that Rust
  extension code must not import Python submodules at module init.
- **Scope.** Used when adding/removing a Rust submodule, debugging import-time errors, or
  porting a Python algorithm to Rust. Includes the `import_exception!` macro pattern for
  surfacing `QiskitError` from Rust.
- **Tier.** Mandatory (§ 11.2.2, § 11.2.5).
- **Example use.** *"I added a new `crates/foo/` crate, why does `from qiskit._accelerate
  import foo` fail?"* → explains the missing line in `qiskit/__init__.py` and points at
  the existing pattern.
- **Saved-effort PR.** **#15993** ("Add DType, Tensor & friends to providers crate"):
  every new Rust submodule needs the matching `sys.modules[...]` line; the skill enforces
  this checklist mechanically.

---

## 2. Authoring code

### 2.1 `qiskit-coding-conventions`

- **Description.** Apply the project's formatting and linting rules: black 100-char,
  ruff 110-char (deferring to black), `from __future__ import annotations` universal,
  modern union syntax (`X | Y`), Google docstrings (D417 enforced), import ordering, no
  `print`/`println!`/`eprintln!`.
- **Scope.** Style-only auto-fixes and review hints before `tox -elint`. Wraps black,
  ruff, cargo fmt, clippy `--all-targets`, slots check.
- **Tier.** Mostly Mandatory (§ 11.4.2, § 11.9.2, § 3.1).
- **Example use.** *"Lint and format the file I just edited."* → black + ruff + cargo
  fmt + clippy on the touched files only.
- **Saved-effort PR.** **#15721** promoted "missing argument in docstring" (`D417`) to
  CI-blocking. Pre-existing PRs that wouldn't have linted then need fixes now; the skill
  surfaces this before push. Also **#16128** ("Enable clippy on rust tests too").

### 2.2 `qiskit-add-standard-gate`

- **Description.** Generate the canonical scaffolding for a new standard gate:
  `qiskit/circuit/library/standard_gates/<name>.py` (`SingletonGate` subclass with
  `@with_gate_array`, `_standard_gate = StandardGate.<NAME>` link), the corresponding
  Rust enum entry under `crates/circuit/src/operations/`, gate test, mpl visualization
  test, and a reno entry under `features_circuits`.
- **Scope.** End-to-end pattern from `playbook/07-implementation-patterns.md` § 7.1.
  Includes LaTeX-math docstring, circuit symbol, and global-phase handling.
- **Tier.** Preferred (§ 11.1.1, § 11.9.4).
- **Example use.** *"Add an XYGate that does a controlled XY rotation."*
- **Saved-effort PR.** **#16074** (CPhase visualization update): touching the gate
  visualization required snapshot regeneration plus a docstring nudge — the skill bakes
  in the snapshot-rebuild step. Also **#15943**, **#15944** (silent `global_phase` drops
  in templates) — the scaffold includes a global-phase invariant test.

### 2.3 `qiskit-add-transpiler-pass`

- **Description.** Scaffold an `AnalysisPass` or `TransformationPass`, with the
  obligatory `run(self, dag)` override, `MetaPass`-friendly constructor, control-flow
  recursion into `ControlFlowOp.blocks`, and a control-flow regression test.
- **Scope.** From `playbook/07-implementation-patterns.md` § 7.2 and
  `playbook/11-implicit-conventions.md` § 11.5.3. Includes a checklist for parallel
  passes (perf reno entry, deterministic ordering, benchmark numbers).
- **Tier.** Preferred (close to Mandatory for control-flow tests).
- **Example use.** *"Add an analysis pass that counts measurement targets per qubit."*
- **Saved-effort PR.** **#15875** ("Fix `BasisTranslator` processing of nested
  ControlFlowOp"), **#15581/#15626**, **#15413**, **#15083**, **#15143**, **#15155**,
  **#15941** — every one of these was a transpiler pass that missed control-flow
  recursion. The skill front-loads the test that would have caught them.

### 2.4 `qiskit-error-handling`

- **Description.** Choose the right exception class for a given raise site
  (`QiskitError` subclass for domain errors, `ValueError`/`TypeError` for boundary
  type/value problems, `MissingOptionalLibraryError` for absent extras). Show the Rust
  → Python `import_exception!` bridge.
- **Scope.** From § 7.3, § 11.3. Discourages `pydantic`/`typeguard`. Calls out the
  `MissingOptionalLibraryError(QiskitError, ImportError)` dual inheritance contract.
- **Tier.** Mostly Mandatory (§ 11.3.2, § 11.3.5).
- **Example use.** *"Raise a clear error when the input matrix is not unitary."* →
  recommends `CircuitError` over `ValueError`, with a precedent grep across the file.
- **Saved-effort PR.** **#16054** (panic on parameterized global phase), **#15635**
  (panics in QSD Rust). Both are panic-class bugs that the skill flags before merge by
  walking the no-`expect` rule.

### 2.5 `qiskit-optional-dependencies`

- **Description.** Wrap any non-required dependency through `qiskit.utils.optionals`
  lazy testers (`HAS_MATPLOTLIB`, `HAS_AER`, `HAS_QASM3_IMPORT`), import inside the
  function, raise `MissingOptionalLibraryError` if absent, register the extra in
  `pyproject.toml`.
- **Scope.** From § 7.7 and § 11.10.2. Includes the rule that module-top imports of
  optionals are banned.
- **Tier.** Mandatory.
- **Example use.** *"Add a Plotly-based interactive backend graph viewer."* → the skill
  blocks any module-top `import plotly`, generates the lazy tester wiring, and adds the
  `pyproject.toml` extras entry.
- **Saved-effort PR.** Pattern protects against the common form of *"qiskit fails to
  import on minimal envs"* bug class — none reverted in window because the rule is
  enforced at review, but it would have been enforced as code instead.

### 2.6 `qiskit-rust-performance-idioms`

- **Description.** Apply hot-path Rust idioms — avoid `expect`/panics, prefer
  fixed-size arrays over `SmallVec`/`Vec` when N is statically known, prefer
  `try_inverse_mut()` over allocate-and-invert, prefer `numpy`/`nalgebra`/`faer` over
  `scipy` in Rust.
- **Scope.** From § 7.8, § 9.5, § 11.7.3, § 11.7.5. Includes the no-`println!` workspace
  clippy deny.
- **Tier.** Preferred.
- **Example use.** *"Optimize this 4×4 matrix multiply chain in Rust."*
- **Saved-effort PR.** **#16123** (mtreinish: *"Since this is always 4 matrices you
  don't need the smallvec … allocating a vec is extra overhead we don't need yet."* —
  the skill catches this in static review). Also **#16010** and **#15635** (panic
  removal), **#16016/#15960/#15874/#15881/#15928/#15871** (scipy → nalgebra/faer migration).

### 2.7 `qiskit-deprecation`

- **Description.** Apply the canonical deprecation decorators
  (`@deprecate_func` / `@deprecate_arg` / `@deprecate_arg_default`), enforce the
  two-version compatibility window, and generate paired tests (one `assertWarns` for
  the old path, one warning-free for the new path).
- **Scope.** From § 6.4, § 7.4, § 9.7. Includes the
  `pending=True` → `PendingDeprecationWarning` distinction, the auto-injected
  `.. deprecated:: x.y` docstring directive, and the rule against hand-rolled
  `warnings.warn(DeprecationWarning(...))` (Historical/obsolete pattern).
- **Tier.** Mandatory.
- **Example use.** *"Deprecate `QuantumCircuit.foo` in favor of
  `QuantumCircuit.foo_v2`."*
- **Saved-effort PR.** Reviewers consistently ask for the missing second test
  (`QiskitTestCase` treats `DeprecationWarning` as error — see CONTRIBUTING.md:928-953).
  The skill bakes both tests in. Also addresses the maintainer pushback in **#15994**
  (Cryoris: missing tests on deprecation path).

---

## 3. Building & testing

### 3.1 `qiskit-build-system`

- **Description.** Cheat-sheet for the build pipeline: PEP 517 with
  `setuptools-rust==1.12.0`, the `pip install .` (release) vs. `pip install -e .`
  (debug) profile rule, the `QISKIT_BUILD_PROFILE` / `QISKIT_BUILD_WITH_MIMALLOC` /
  `QISKIT_NO_CACHE_GATES` env knobs, MSRV 1.87 mirrored across four files, and the
  `make c` / `make ctest` / `make coverage` Makefile targets.
- **Scope.** From § 2.1.
- **Tier.** Mandatory MSRV (§ 4.5), Preferred otherwise.
- **Example use.** *"Why is editable install slow at runtime?"* → explains the editable
  → debug-profile default and how to opt into release via `QISKIT_BUILD_PROFILE=release`.
- **Saved-effort PR.** Generic onboarding tax. The MSRV-keep-in-sync rule (`Cargo.toml`,
  `rust-toolchain.toml`, `tools/install_rust_msrv.sh`, `README.md`) catches drift —
  the reno entry `msrv-187-fe3d9818f5c4103d.yaml` exists because the bump was carefully
  coordinated.

### 3.2 `qiskit-testing`

- **Description.** Run the right tests, in the right runner, with the right env vars.
  Wraps `tox -epy*`, `tox -erust`, `cargo test`, `make ctest`, `tox -eminoptional`.
  Knows about `QiskitTestCase` (DeprecationWarning + QiskitWarning treated as errors),
  `QISKIT_PARALLEL=FALSE`, `QISKIT_TESTS=run_slow=True`, snapshot tests in
  `test/ipynb/mpl/`, and Hypothesis tests in `test/randomized/`.
- **Scope.** From § 2.2.
- **Tier.** Mandatory regression tests (§ 11.5.1), Mandatory deprecation tests
  (§ 11.5.2), Preferred control-flow tests (§ 11.5.3).
- **Example use.** *"Run the transpiler tests for the Sabre layout pass."* →
  `tox -epy311 -- test.python.transpiler.test_sabre_layout`.
- **Saved-effort PR.** **#16124** (CS/CSdg cancellation, closed) — the proposed fix
  didn't actually pass against the reproducer. The skill includes a "did the regression
  test fail before your fix?" gate. Also **#16156** ("Fix file leak from tests") and
  **#15332** (memory leak in `test_get_gate_counts`) — the skill knows about
  `QISKIT_TEST_CAPTURE_STREAMS`.

### 3.3 `qiskit-qpy-compatibility`

- **Description.** Walk through QPY format-version bumps: add a fixture under
  `test/qpy_compat/`, increment the format version in both Python and Rust, ensure
  round-trip on the corpus, add a reno entry under `features_qpy` or `upgrade_qpy`.
- **Scope.** From § 7.10, § 8.2, § 11.5.4, § 11.6.4. Includes the gzip-stream / Rust
  bytes vs. Python bytes traps that recur.
- **Tier.** Mandatory.
- **Example use.** *"Bump QPY to v14 to support the new annotation type."*
- **Saved-effort PR.** **#15623** (user-defined register named `'ancilla'`), **#15649**
  (annotation handling in Rust QPY), **#15847** (Rust/Python compatibility), **#16076**
  (delay integer durations), **#15663** (Rust QPY v13), **#15158** (gzip write streams),
  **#15934** (`ParameterExpression` Polish-form rewrite). Each was a missing-fixture or
  missing-format-version-guard bug. The skill is the checklist that prevents the next.

---

## 4. Performance & profiling

### 4.1 `qiskit-performance-benchmarks`

- **Description.** Use ASV (`test/benchmarks/`) to produce before/after numbers for any
  PR that touches a heuristic, hot path, or default. Generates the table format
  reviewers ask for and writes the matching `Changelog: Performance` reno entry.
- **Scope.** From § 9.6, § 11.7.2, § 11.7.4.
- **Tier.** Mandatory for heuristic/hot-path changes.
- **Example use.** *"I changed Sabre's lookahead heuristic — produce the benchmark
  table."*
- **Saved-effort PR.** **#14911** (Sabre lookahead) — alexanderivrii repeatedly:
  *"I would really love to see some experimental data."* The skill produces the data on
  the first review pass instead of the third. Also **#16014** (parallel
  `CommutationAnalysis`) — drove the introduction of the `Performance` changelog
  category in **#16065**. Plus **#16146** (revert of #15931 PGO QV inflation): the skill
  flags PGO training-circuit changes as a regression risk.

### 4.2 `qiskit-determinism-audit`

- **Description.** Check that any new parallel code path preserves output ordering;
  walk through rayon `par_iter` patterns; surface ordering-sensitive sites (DAG node
  insertion, sort outputs).
- **Scope.** From § 7.6, § 8.9, § 11.8.2.
- **Tier.** Mandatory (§ 11.8.2).
- **Example use.** *"I'm parallelizing a synthesis pass — does this preserve gate
  order?"*
- **Saved-effort PR.** **#15410** ("Stop using a parallel sort in disjoint utils") —
  reverted because parallel sort introduced ordering non-determinism. **#15040**
  (DAG edge-order non-determinism). The skill is the determinism gate that those merges
  bypassed.

---

## 5. Dependency & API evolution

### 5.1 `qiskit-dependency-policy`

- **Description.** Apply the project's dependency-addition checklist: justify the
  addition (why isn't `numpy`/`scipy`/`rustworkx` enough?), pick tightest reasonable
  lower bound, avoid upper bound unless a known break exists, register optional
  dependencies in `pyproject.toml` extras + `qiskit.utils.optionals`, add Rust crates to
  `[workspace.dependencies]` not the leaf, refresh `Cargo.lock`, and only add to
  `constraints.txt` when a specific upstream issue forces it.
- **Scope.** From § 4.1–§ 4.8, § 11.10.
- **Tier.** Preferred (§ 11.10.1).
- **Example use.** *"I want to add `tqdm` for progress bars in the transpiler."* →
  the skill challenges the addition (logging is the established channel) and steers
  toward `qiskit.utils.optionals` if it must land.
- **Saved-effort PR.** Dependabot bumps **#16019**, **#15989**, **#15952**, **#15942**,
  **#15888**, **#15889**, **#16101** all carry the right shape — the skill produces the
  same shape on hand-authored PRs. Also catches the **#15839** Cargo.lock-currency
  expectation.

### 5.2 `qiskit-api-evolution`

- **Description.** Map the public-API contract: documented surface only, two-version
  compatibility window, three-month minimum removal timeline, removals only in major
  releases, deprecations only in minors. Distinguish public from private import paths
  (e.g. `qiskit.circuit.measure` private vs. `qiskit.circuit.Measure` public).
- **Scope.** From DEPRECATION.md, § 6.4, § 11.6.1, § 11.6.2.
- **Tier.** Mandatory.
- **Example use.** *"Can I rename `QuantumCircuit.foo` in 2.5?"* → returns: deprecate
  in 2.5, leave both paths through 2.6, remove no earlier than 3.0.
- **Saved-effort PR.** Steers contributors away from the wrong-layer fix pattern
  (**#16062**) and the over-restrictive fix pattern (**#16116**) by anchoring "what is
  the public API contract here?" before code is written.

---

## 6. Pre-PR self-review

### 6.1 `qiskit-pr-preparation`

- **Description.** Produce a PR-ready package: concise human-written description (no
  LLM bloat, no "Validation" subsection — CI's job), `Fixes #N` exact phrasing, AI/LLM
  disclosure box, correct `Changelog: <X>` label suggestion, a backport-label
  recommendation if the change is a user-visible bug fix.
- **Scope.** From `.github/PULL_REQUEST_TEMPLATE.md` (post-#15924), § 9.3, § 10.3,
  § 11.11.2, § 11.11.3, § 11.11.7. Lists the changelog axes from `qiskit_bot.yaml`.
- **Tier.** Mandatory description style; Mandatory AI-disclosure; Mandatory `Fixes #N`.
- **Example use.** *"Draft the PR body for the changes I just committed."*
- **Saved-effort PR.** **#16039**, **#16060**, **#16062**, **#16079**, **#16125**,
  **#16127**, **#15994** — the LLM-spam closures by jakelishman. The skill makes the
  disclosure box a non-skippable step and forces concise summaries. Also **#16116**
  (alexanderivrii: *"the 'validation' subsection feels unnecessary given that CI already
  covers this"*).

### 6.2 `qiskit-good-pr-checklist`

- **Description.** Run the implicit "good PR" checklist before requesting review.
  Items: correct fix at the right abstraction layer; regression test that fails before
  the fix; reno entry on the right `Changelog:` axis (or `Changelog: None` justified);
  AI/LLM disclosure; benchmark data if heuristic/hot-path changed; control-flow test
  if a transpiler pass touches DAG; `stable backport potential` label if user-visible
  bug fix.
- **Scope.** From § 9.8 (the explicit reconstructed checklist).
- **Tier.** Mandatory items: regression test, changelog, deprecation tests; Preferred:
  the rest.
- **Example use.** *"Audit my branch before review."*
- **Saved-effort PR.** Combined effect of the checklist would have flagged **#16124**
  (fix that worsens the symptom), **#16064** (over-narrow LieTrotter), **#16062**
  (wrong-layer), **#15494** (missing reno; Cryoris asked) before the maintainer round
  trip.

---

## 7. Code review (reviewer side)

### 7.1 `qiskit-code-review`

- **Description.** Run a maintainer-style review on a diff. Knows the recurring nits
  (use `` ``dag`` `` not `*dag*`, don't widen/narrow types reflexively, avoid
  `expect`/panic in Rust, drop redundant `__init__` summaries on analysis passes,
  request perf data for heuristic changes), and routes to the right specialist via
  `qiskit_bot.yaml` paths.
- **Scope.** From all of `playbook/09-reviewer-expectations.md`, § 11.11.
- **Tier.** Preferred review style; Mandatory items called out as such.
- **Example use.** *"Review this diff as if you were Cryoris / mtreinish / jakelishman."*
- **Saved-effort PR.** Replaces the repeated review cycle on **#15832** (Cryoris:
  type-hint nits), **#16123** (mtreinish: smallvec → fixed-size array), **#15999**
  (jakelishman: extend native iterator), **#15279** (jakelishman: less-boilerplate
  request).

---

## 8. CI/CD & release

### 8.1 `qiskit-ci-workflows`

- **Description.** Map CI status checks to workflows: `branch-protection.yml` finalize
  job gates merge on `docs`, `lint`, six Python-matrix unit jobs, `test-rust`,
  `test-c × 4`, `test-images`, `miri`, `qpy`, `neko`. Helps debug a red CI by pointing
  at the right log.
- **Scope.** From § 5.1, § 5.2.
- **Tier.** Mandatory required-checks list.
- **Example use.** *"Why is `miri` red on my PR?"* → unsafe-code path; routes to the
  miri exclusions (FFI tests excluded) and `unsafe_op_in_unsafe_fn` clippy deny.
- **Saved-effort PR.** **#15049** ("Fix UB invocation in `SparseObservable` C API
  test") — the skill connects miri failures to UB origins faster.

### 8.2 `qiskit-release-notes`

- **Description.** Generate a reno entry: `reno new <slug>` to create the file, populate
  the right section (`features_circuits` / `features_transpiler` / `features_qpy` /
  `fixes` / `performance` / `upgrade*` / `deprecations*` / `build` / `critical` /
  `security` / `other`), add YAML body, decide on `Changelog: <X>` label.
- **Scope.** From § 5.5, § 6.6, § 11.6.5.
- **Tier.** Mandatory for user-visible changes.
- **Example use.** *"Create the reno entry for my parallel-CommutationAnalysis PR."* →
  `releasenotes/notes/parallel-commutation-analysis-<hash>.yaml` with
  `features_transpiler` + `performance` sections, plus `Changelog: Performance` label.
- **Saved-effort PR.** **#15494** (Cryoris asked for a `fixes:` reno entry post-hoc),
  **#16014** (alexanderivrii added `Changelog Performance` label by hand and asked for
  a perf reno), **#14911** (same pattern). All three would have shipped with the right
  shape on first push.

### 8.3 `qiskit-release-ceremony`

- **Description.** Drive the 6-step release ceremony from `MAINTAINING.md`: audit
  milestone (feature freeze 2 weeks before RC1); audit `Changelog:` labels with the
  external `generate_changelog.py`; prepare release notes (move loose notes into
  `releasenotes/notes/x.y/` on first release); open the *"Prepare x.y.z release"* PR
  (bump version in **four** locations: `qiskit/VERSION.txt`, `Cargo.toml`,
  `crates/bindgen/include/qiskit/version.h`, `docs/release_notes.rst`); on first minor
  also retarget `.mergify.yml`; tag GPG-signed `x.y.z` (no `v` prefix); push to upstream;
  enforce the wheels-deployment second-approver rule.
- **Scope.** From § 6.1–§ 6.3, § 5.6.
- **Tier.** Mandatory.
- **Example use.** *"Drive the 2.5.0rc1 release."*
- **Saved-effort PR.** Existing release-prep PRs (e.g. version-bump PRs across the
  2.x line) follow this script by hand. The skill mechanizes the four-file version
  bump and the mergify retarget — both easy to miss on first releases.

---

## 9. Backports & maintenance

### 9.1 `qiskit-backport-process`

- **Description.** Apply or remove the `stable backport potential` label correctly,
  understand which Mergify rule fires, and sync labels/milestones via `backport.yml`.
  Knows that backports do *not* duplicate reno entries (the original carries it).
- **Scope.** From § 5.4, § 6.8, § 11.11.4.
- **Tier.** Preferred.
- **Example use.** *"Should I backport this fix to stable/2.4?"* → checks: is it a
  user-visible bug fix? is the regression in the stable branch? if yes, label it; if no,
  features and refactors are not backported.
- **Saved-effort PR.** **#16155** (auto-backport of #16154), **#15431** (of #15429),
  **#15728** (of #15725), **#15884** (of #15875). The skill is the sanity-check on
  whether to label.

---

## 10. Debugging, security, anti-patterns

### 10.1 `qiskit-bug-triage`

- **Description.** Classify a reported bug into one of the recurring categories
  (control flow correctness, QPY round-trip, synthesis/decomposition correctness incl.
  silent `global_phase` drops, commutation/cancellation, visualization, parameter
  expressions, panics/leaks, C API/FFI, threading non-determinism, docs/typos), and
  pull the relevant past PRs as starting points.
- **Scope.** From all of `playbook/08-bug-categories.md`.
- **Tier.** N/A (informational).
- **Example use.** *"Issue: `BasisTranslator` mishandles a nested `IfElseOp`."* →
  category 8.1, prior PRs **#15875** / **#15581** / **#15626** / **#15413** as
  references; suggest `ControlFlowOp.blocks` recursion as the likely fix.
- **Saved-effort PR.** **#15673** (MCX with 0 controls — ShellyGarion asked for the
  negative-count test that the skill produces by default), **#15494** (`plot_state_qsphere`
  phase-anchor — categorically identifies as 8.5 visualization → snapshot regen).

### 10.2 `qiskit-debugging`

- **Description.** Apply the project's debug-time conventions: `logger =
  logging.getLogger(__name__)` per module with `%s`/`%d`-style args (deferred
  formatting); `LOG_LEVEL` env knob; never `print` / `println!`. For Rust, run miri on
  unsafe paths; for unsafe FFI paths, miri is excluded — fall back to UBSan via
  `make ctest`.
- **Scope.** From § 11.4.1, § 11.4.2, § 11.4.3, CONTRIBUTING.md:723-745.
- **Tier.** Mandatory `print` ban; Preferred logger style.
- **Example use.** *"Add diagnostic logging to the Sabre router."*
- **Saved-effort PR.** Eliminates a class of "leftover `println!` killed clippy"
  rolling fixes (**#15280**, **#15107**, **#15716**, **#15804**, **#16052**).

### 10.3 `qiskit-security-review`

- **Description.** Apply security checklist for C API / FFI / unsafe-Rust code: every
  `unsafe` block has a justification, no `expect`/panic on user-reachable paths, miri
  passes on the path where it can run, UBSan via `make ctest` covers FFI, public C API
  surface is gated by Doxygen `\qk_deprecated{}` for evolving paths (pre-3.0 C API is
  explicitly unstable per DEPRECATION.md:258-304).
- **Scope.** From § 7.8, § 8.7, § 8.8, § 11.3.4, DEPRECATION.md C-API section.
- **Tier.** Mandatory pre-merge for C API / unsafe; Preferred elsewhere.
- **Example use.** *"Audit the `crates/cext/` change in this PR for unsafe / panic
  hazards."*
- **Saved-effort PR.** **#15049** (UB invocation in `SparseObservable` C API test) —
  surfaced earlier by the skill. **#16113** (`restype` for void-returning C functions),
  **#15967** (C transpiler level-3 potential infinite loop). All FFI-class bugs
  catchable at review with this skill.

### 10.4 `qiskit-anti-patterns`

- **Description.** Catch the patterns maintainers actively close PRs over: LLM-spam
  volume without human ownership; wrong-abstraction-layer fixes; over-restrictive
  fixes that eliminate legitimate paths; narrow special-case PRs that calcify a path;
  boilerplate proliferation; non-deterministic parallelism; runtime type-validator
  dependencies; hand-rolled `warnings.warn(DeprecationWarning(...))`; `Union` /
  `Optional` instead of modern union syntax; `println!` / `print` for diagnostics.
- **Scope.** From § 10.2, § 10.3, § 11.12, § 11.13. Lists the closure precedents.
- **Tier.** Mandatory.
- **Example use.** *"Sanity-check this draft PR against the anti-patterns list."*
- **Saved-effort PR.** Aggregates the protection that the closures **#16039**,
  **#16060**, **#16062**, **#16064**, **#16079**, **#16116**, **#16124**, **#16125**,
  **#16127** demonstrate — every closure in the sample window maps to one of these
  anti-patterns.

---

## Cross-cutting notes

- **Skill granularity.** Each skill targets one user intent. Two skills routinely
  compose (e.g. `qiskit-add-transpiler-pass` calls into `qiskit-deprecation` if the
  pass replaces an older one; `qiskit-pr-preparation` calls into
  `qiskit-release-notes`). Composition is preferred over making any single skill
  monolithic.
- **Evidence linkage.** Every skill references a tier (Mandatory / Preferred /
  Disputed / Historical) so its output can flag which checks block merge vs. which
  trigger discussion.
- **What is intentionally not a skill.** Generic "explain Python concurrency" or
  "explain Rust trait dispatch" — Qiskit-specific conventions are the value here, not
  language tutorials. Likewise, content already in CLAUDE.md or the playbook itself
  is not duplicated; skills point into the playbook.
- **Coverage map vs. lifecycle.** The 10 phases above match the
  request: architecture (§1), coding style (§2.1) and best practices (§2.2–2.7),
  testing (§3.2), debugging (§10.2), performance analysis (§4), security (§10.3),
  dependency policy (§5.1), API evolution (§5.2), review process (§7), release process
  (§8.3), backport / maintenance (§9), contributor workflow (§6, §8.2), common
  patterns (§2.2, §2.3, §2.4) and anti-patterns (§10.4).
- **PR citations summary.** This plan cites **>60 distinct merged or closed PRs**
  across the playbook window — every cited PR maps to ≥1 skill that would have shaved
  one or more review cycles, prevented a revert, or replaced a maintainer's templated
  guidance message.

---
