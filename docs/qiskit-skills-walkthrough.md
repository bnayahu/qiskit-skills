# Qiskit Skills: AI-Assisted Development at Scale

Walkthrough of the Qiskit Skills project — what it is, how it was built, and what it enables.

---

## Table of Contents

1. [How the Skills Were Built](#1-how-the-skills-were-built)
2. [The Skills: An Overview](#2-the-skills-an-overview)
3. [Case Study: Fixing Issue #16186](#3-case-study-fixing-issue-16186)
4. [Open Issues: How the Skills Come Into Play](#4-open-issues-how-the-skills-come-into-play)

---

## 1. How the Skills Were Built

### The Hypothesis

A mature codebase like Qiskit carries an enormous amount of tacit knowledge — in
CONTRIBUTING.md, in closed PRs, in maintainer review comments, in reverted commits. Most
of that knowledge is invisible to an AI coding agent working from the source alone. The
hypothesis behind this project: **that knowledge can be distilled into a reusable skill
set by systematically analyzing the codebase and its history**, rather than requiring
manual convention-documenting by maintainers.

The entire process — from raw codebase to 27 implemented skills — was completed in a
single day using seven prompts to Claude Code.

---

### The Seven-Prompt Sequence

What follows is the verbatim prompt at each step and what it produced.

---

#### Prompt 1 — Codebase inventory

```
Analyze this repository and produce a structured inventory of:

1. Architecture and subsystem boundaries
2. Build and test systems
3. Coding conventions
4. Dependency management patterns
5. CI/CD workflows
6. Release engineering workflows
7. Common implementation patterns
8. Recurring bug categories
9. Reviewer expectations inferred from PR discussions
10. Maintainer preferences inferred from accepted/rejected changes

Do not synthesize recommendations yet.

For every observation:
- provide evidence
- cite files, PRs, issues, commits, or docs
- estimate confidence level
- distinguish explicit rules from inferred conventions
```

**Output:** `playbook/01-architecture.md` through `playbook/10-maintainer-preferences.md` —
10 files covering the full inventory. Sample size: 130+ merged PRs analyzed across a
six-month window (Nov 2025–May 2026), 16 Rust crates, 18 top-level Python packages,
all 20 GitHub Actions workflow files, and targeted `git log --grep` queries.

---

#### Prompt 2 — Implicit conventions

```
Using the playbook information and project history, identify implicit engineering conventions.

Focus on:
- naming patterns
- layering boundaries
- error handling
- logging style
- testing expectations
- API compatibility discipline
- performance tradeoffs
- concurrency patterns
- abstraction preferences
- dependency avoidance
- code review expectations

For each convention:
- explain the rule
- provide repository evidence
- identify counterexamples
- estimate whether this is:
  - mandatory
  - preferred
  - historical/obsolete
  - disputed

Add the information to the playbook.
```

**Output:** `playbook/11-implicit-conventions.md` — 794 lines, the densest single file.
Covers 13 cross-cutting convention categories with mandatory / preferred / historical /
disputed tier labels and PR/commit citations for each. This tier system becomes the
backbone of every skill's priority guidance.

---

#### Prompt 3 — Skills design

```
use the playbook information to design a set of skills for the project. the skills
should cover all lifecycle aspects of the development and maintenance of the project.
For example, it should cover architecture, coding styles, testing, review process,
release process, dependency policy, api evolution, debugging, performance analysis,
security guidelines, contributor workflows, best practices, common patterns and
anti patterns, etc.
Create a skills folder, and create a detailed plan for the proposed skills. For each
proposed skill, include name, description, scope, example of how it would be used,
and preferrably a reference to a merged PR where the skill would have saved manual
effort and time. Do not implement the skills themselves yet.
```

**Output:** `skills-design.md` — a 523-line skill design plan. 27 skills across 10 lifecycle
phases, each with description, scope, a worked example, and at least one PR citation where
the skill would have shortened the review cycle, prevented a revert, or replaced a
maintainer's templated guidance message. Over 60 distinct PRs are cited.

---

#### Prompt 4 — Issue analysis

```
analyze the 10 latest open issues categorized "good first issue". If you were given
the task to fix them, how would you use these skills? Create an analysis document in
the skills folder with the results.
```

**Output:** `issue-analysis.md` — 378 lines. A per-issue walkthrough mapping each of
10 open issues to the exact sequence of skills that would fire, plus a coverage matrix
showing which skills appear most frequently across the issue set.

---

#### Prompt 5 — Skills implementation

```
proceed with implementing the skills defined in skills/PLAN.md. Use the playbook as reference.
```

**Output:** 27 `skills/<name>/SKILL.md` files — 3,654 lines total. Each skill is
action-oriented: trigger conditions, step-by-step procedure, playbook section references,
and PR citations for the patterns it enforces.

---

#### Prompt 6 — Review and validation

```
review the implemented skills in skills/, then review the ISSUE_ANALYSIS.md document.
Confirm the analysis and the expected triggering of skills.
```

**Output:** Validation pass confirming skills matched the design plan and the issue
analysis correctly predicted skill activation order.

---

#### Prompt 7 — AGENTS.md

```
create an AGENTS.md file for the project. Reference the playbook
(../qiskit-skills/playbook) and the existing skills (.claude/skills).
Use https://pages.github.ibm.com/Markus-Eisele/bob-book/poster/how-to-agents-md.html
as additional best practices
```

**Output:** `AGENTS.md` — 190 lines. The agent-facing entry point for the Qiskit repo.
It serves as a single source of truth that points to:
- The playbook table (11 files, with topic summaries)
- The skills index (27 skills, grouped by category, with links)
- Build and test command quick reference
- Code-style non-negotiables
- Pre-PR checklist
- Patterns that get PRs closed
- Recurring bug category taxonomy

`AGENTS.md` is the integration artifact that makes the playbook and skills actionable
in a single file a developer — human or AI — reads first.

---

### What Was Produced

| Artifact | Files | Lines | Key content |
|----------|-------|-------|-------------|
| Playbook | 11 | ~2,330 | Evidence-cited inventory of conventions, tier-labelled |
| Skills | 27 | ~3,650 | Action-oriented playbooks, one per developer intent |
| AGENTS.md | 1 | 190 | Agent entry point, links playbook + skills |
| Issue analysis | 1 | 378 | Skill activation map for 10 open issues |
| Skills plan | 1 | 523 | Design rationale, PR citations, lifecycle coverage |

Total: ~7,070 lines of structured, evidence-backed developer guidance — produced from a
single day of prompting against the git history and codebase, with no manual
convention-documenting.

---

## 2. The Skills: An Overview

### Lifecycle Coverage

The 27 skills are organized into 10 phases that map the complete development and
maintenance lifecycle. Every skill targets a single, recognizable developer intent rather
than a generic mega-skill — "add a gate", "prepare a release note", "audit my PR before
requesting review."

| Phase | Skills |
|-------|--------|
| **1. Onboarding & architecture** | `qiskit-architecture-map` · `qiskit-py-rust-bridge` |
| **2. Authoring code** | `qiskit-coding-conventions` · `qiskit-add-standard-gate` · `qiskit-add-transpiler-pass` · `qiskit-error-handling` · `qiskit-optional-dependencies` · `qiskit-rust-performance-idioms` · `qiskit-deprecation` |
| **3. Building & testing** | `qiskit-build-system` · `qiskit-testing` · `qiskit-qpy-compatibility` |
| **4. Performance & profiling** | `qiskit-performance-benchmarks` · `qiskit-determinism-audit` |
| **5. Dependency & API evolution** | `qiskit-dependency-policy` · `qiskit-api-evolution` |
| **6. Pre-PR self-review** | `qiskit-pr-preparation` · `qiskit-good-pr-checklist` |
| **7. Code review** | `qiskit-code-review` |
| **8. CI/CD & release** | `qiskit-ci-workflows` · `qiskit-release-notes` · `qiskit-release-ceremony` |
| **9. Backports & maintenance** | `qiskit-backport-process` |
| **10. Debugging, security, anti-patterns** | `qiskit-bug-triage` · `qiskit-debugging` · `qiskit-security-review` · `qiskit-anti-patterns` |

---

### The Universal Triad

Three skills appear in virtually every development cycle, regardless of the type of
change being made:

| Skill | Issues hit (of 10) | What it guards |
|-------|--------------------|----------------|
| `qiskit-pr-preparation` | **10 / 10** | AI/LLM disclosure, `Fixes #N` exact phrasing, concise human-written summary |
| `qiskit-release-notes` | **9 / 10** | reno YAML on the right `Changelog:` axis — the most common post-review correction |
| `qiskit-testing` | **9 / 10** | Regression test that fails before the fix; deprecation paired-test; control-flow test |

These three address the two most-cited review-iteration hotspots across the playbook:
**missing or wrong reno entries** (reviewers asked for reno fixes in PRs #15494, #16014,
#14911, among others) and **missing regression tests** (PRs #16124, #15673, #15994, among
others). Front-loading them is the single highest-leverage thing the skills do.

---

### Skill Composition

Skills are designed to compose. Common compositions:

- `qiskit-bug-triage` → routes to the right domain skill (e.g. `qiskit-py-rust-bridge`
  for Rust-layer bugs, `qiskit-determinism-audit` for ordering bugs)
- `qiskit-add-transpiler-pass` → calls into `qiskit-deprecation` when the new pass
  replaces an older one
- `qiskit-pr-preparation` → calls into `qiskit-release-notes` for the reno entry
- `qiskit-good-pr-checklist` — the pre-`gh pr create` meta-skill that aggregates
  `qiskit-testing` + `qiskit-release-notes` + `qiskit-anti-patterns` + `qiskit-backport-process`
  into a single gate

This composition model keeps individual skills focused on one intent while allowing
them to be assembled into complete workflows for complex changes.

---

### The Tier System

Every skill inherits the mandatory / preferred / historical / disputed tier labels from
`playbook/11-implicit-conventions.md`. This gives the skill's output actionable priority
guidance:

- **Mandatory** — blocks merge if absent (e.g. regression test, reno entry, AI disclosure)
- **Preferred** — reviewer will ask; should be present but not strictly blocking
- **Historical / obsolete** — don't do this (e.g. hand-rolled `warnings.warn(DeprecationWarning(...))`)
- **Disputed** — acknowledged tradeoff; skill surfaces both sides

Skills explicitly annotate which of their checks are mandatory vs. preferred, so a
developer knows which omissions are review-blockers.

---

### PR-Closure Coverage

The `qiskit-anti-patterns` skill alone maps to 9 closed-without-merge PRs from the
analysis window: #16039, #16060, #16062, #16064, #16079, #16116, #16124, #16125,
#16127. Every closure maps to one of these recurring patterns:

- High-volume LLM-generated PRs without a human owner who can defend the change
- Wrong-abstraction-layer fixes (patching a symptom in a caller instead of the root)
- Over-restrictive fixes that close legitimate code paths
- Narrow special-case PRs that calcify a single path
- Non-deterministic parallelism (determinism is Mandatory in Qiskit — see #15410 revert)
- Module-top imports of optional dependencies
- Missing the second deprecation test (the warning-free new path)
- Skipping benchmark data on a heuristic change

The skill surfaces these *before* PR creation, not during review.

---

## 3. Case Study: Fixing Issue #16186

### The Issue

[Issue #16186](https://github.com/Qiskit/qiskit/issues/16186) was opened against Qiskit
2.4: `ConstrainedReschedule` was giving different `node_start_time` values for the same
input circuit after being ported from Python to Rust in PR #14883. The reporter's
reproducer — X gate → 100-dt Delay → Measure, passed through a `Target` with alignment
constraints — should produce `measure` start time = 272 dt (as in 2.3.1). Instead it
produced 160 dt.

---

### The Three Prompts

The entire fix, from raw issue to committed branch with tests and release note, required
three prompts:

```
triage issue 16186
```

```
implement the fix
```

```
commit ths fix to a new branch in the fork.
```

---

### What Triage Found

The first prompt invoked `qiskit-bug-triage`. The skill classified the issue as
**§ 8.1 transpiler pass correctness — Rust port regression** and immediately routed to
the Rust layer: `crates/transpiler/src/passes/constrained_reschedule.rs`. This is not
obvious from the issue title alone — a developer unfamiliar with the Rust port history
might have started by looking at the Python `ConstrainedReschedule` wrapper class.

`qiskit-py-rust-bridge` confirmed the fix was entirely in `crates/transpiler/`, with no
`qiskit/__init__.py` `sys.modules` registration needed (no new Rust submodule).

---

### The Fix: Three Bugs

Code review of `constrained_reschedule.rs` found not one bug but three, each independent.

#### Bug 1 — Delay duration read from the wrong source

`push_node_back` computed the gate end-time `new_t1q` by first checking if a `Target`
was present and, if so, calling `target.get_duration("delay", qargs)`. But `Delay` is
not in the target gate table — `get_duration` returns `None`, which falls back to `0`.
So the Delay end-time was `this_t0 + 0 = 160 dt` instead of `160 + 100 = 260 dt`.

The corrupted end-time then fed into the successor overlap calculation as an unsigned
integer subtraction: `new_t1q - next_t0q` where `new_t1q < next_t0q`, wrapping to a
value near 2^64 and silently pushing the `measure` start back to 160 dt.

**Fix:** Check for `Delay` first and always read its duration from the instruction
parameter, bypassing the target lookup entirely.

#### Bug 2 — `pulse_align` and `acquire_align` arguments swapped

In `run_constrained_reschedule`, the call to `push_node_back` passed the two alignment
arguments in the wrong order. `acquire_align` inside `push_node_back` received the pulse
alignment value (1 in the reproducer), and `pulse_align` received the acquire alignment.
As a result, `Measure` and `Reset` operations were never shifted to the correct
acquire-alignment boundary — the entire alignment correction for measurements was silently
a no-op.

**Fix:** Swap the argument order at the `run_constrained_reschedule` call site.

```rust
// Before (wrong order):
push_node_back(node_index, node_start_time, clbit_write_latency, acquire_align, pulse_align, target)?;

// After (correct order):
push_node_back(node_index, node_start_time, clbit_write_latency, pulse_align, acquire_align, target)?;
```

This bug was invisible at the Python call site and would not have been found by reading
the issue reproducer alone — it required reading the Rust function signature.

#### Bug 3 — Unsigned integer underflow in overlap arithmetic

Two subtraction expressions used plain `-` on `u64` values:

```rust
let qreg_overlap = new_t1q - next_t0q;  // wraps if current ends before next starts
let creg_overlap = t1c - t0c;           // same
```

When the current gate ends *before* the successor starts (no real overlap), the result
wraps to a value near 2^64, incorrectly forcing the successor back by ~18 exabytes of
dt. `qiskit-rust-performance-idioms` surfaces `saturating_sub` as the idiomatic Rust fix:

```rust
let qreg_overlap = new_t1q.saturating_sub(next_t0q);
let creg_overlap = t1c.saturating_sub(t0c);
```

This bug would not have been found without knowing the Rust idiom; Python integer
arithmetic does not overflow and the same logic would have been silent.

---

### What Each Skill Contributed

| Skill | Contribution |
|-------|-------------|
| `qiskit-bug-triage` | Routed immediately to `crates/transpiler/` (Rust layer), avoiding the Python wrapper |
| `qiskit-py-rust-bridge` | Confirmed no `sys.modules` change needed; located `constrained_reschedule.rs` |
| `qiskit-rust-performance-idioms` | Surfaced `saturating_sub` — bug 3 would not have been found otherwise |
| `qiskit-testing` | Produced two regression tests: misaligned case (measure → 272) and already-aligned case (measure → 256, unchanged) |
| `qiskit-release-notes` | Generated `releasenotes/notes/constrained-reschedule-fix-*.yaml` under `fixes`; `Changelog: Fixed` |
| `qiskit-pr-preparation` | PR body with `Fixes #16186`, three-bug description, AI/LLM disclosure checked |

---

### PR Status

[Draft PR #16210](https://github.com/Qiskit/qiskit/pull/16210) was opened 2026-05-19 in
Qiskit/qiskit. A related PR (#16246) addressing a different issue in the same pass was
merged 2026-05-22. PR #16210 remains open as a draft, covering the three distinct bugs
described above.

---

### Key Takeaway

Three terse prompts — `triage`, `implement the fix`, `commit` — turned a multi-bug
regression in unsafe Rust scheduling code into a fully tested, documented, and
PR-ready fix. The skills added concrete value at three specific points:

1. **Routing** (`qiskit-bug-triage`): found the Rust layer immediately without reading the Python pass history
2. **Idiom** (`qiskit-rust-performance-idioms`): found bug 3 (u64 overflow) — the kind of issue that only surfaces when you know Rust integer semantics
3. **Completeness** (`qiskit-testing`, `qiskit-release-notes`): both regression tests and the reno entry were present in the first commit, eliminating the most common review round-trips

---

## 4. Open Issues: How the Skills Come Into Play

This section walks through four currently open issues and shows exactly which skills fire
at each step. The analysis was generated from the 10 most-recently-opened `good first issue`
tickets as of 2026-05-18 (see `ISSUE_ANALYSIS.md`). Issue #16138 has since been closed;
the three below remain open.

For each issue the format is: symptom → skill sequence → complexity estimate.

---

### Issue A: [#16168](https://github.com/Qiskit/qiskit/issues/16168) — `MultiplierGate(1, 1).decompose()` fails

**Symptom.** `MultiplierGate._define()` calls `multiplier_qft_r17(self.num_state_qubits)`
without forwarding `self.num_result_qubits`, producing a 4-qubit definition for a 3-qubit
gate. One missing argument causes a silent dimension mismatch.

**Skill sequence:**

1. `qiskit-bug-triage` — categorizes as **synthesis/decomposition correctness**, argument-forwarding sub-class. Pulls PR #15735 (`QSD extract_multiplex_blocks`) and #15401 (`generate_unroll_3q` arg) as prior art for the same pattern.
2. `qiskit-architecture-map` — locates `qiskit/circuit/library/arithmetic/multiplier.py` (the library wrapper) vs. `qiskit/synthesis/arithmetic/multipliers/qft_multiplier.py` (the algorithm). Flags this as a **library bug, not a synthesis bug** — fix the wrapper, not the algorithm. This is the "fix at the right layer" lesson from the #16062 closure.
3. `qiskit-testing` — generates a parametric sweep over the documented `num_result_qubits ∈ [num_state_qubits, 2×num_state_qubits]` range, plus a unitary-equivalence assertion so silent width mismatches are caught.
4. `qiskit-release-notes` — `fixes:` section; `Changelog: Fixed`.
5. `qiskit-good-pr-checklist` — confirms the regression test fails on `main` before the fix.
6. `qiskit-backport-process` — `stable backport potential` recommended (user-visible arithmetic library regression).
7. `qiskit-pr-preparation` — `Fixes #16168`, AI disclosure, terse summary.

**Complexity:** One-line fix, parametric test. ~7 skills, ~30 min implementation.

---

### Issue B: [#16166](https://github.com/Qiskit/qiskit/issues/16166) — `dagdependency_to_circuit()` drops `global_phase`

**Symptom.** `global_phase` is preserved through `circuit_to_dag` → `dag_to_dagdependency`
but silently lost on the way back through `dagdependency_to_circuit`. A phase-preserving
round-trip fails without any error.

**Skill sequence:**

1. `qiskit-bug-triage` — immediately recognizes the **silent `global_phase` drop** pattern from `playbook/08-bug-categories.md` § 8.3. Pulls PRs #15943, #15944, #15816, #14537 as the same-family fixes. Flags: every converter function must carry `global_phase`.
2. `qiskit-architecture-map` — locates `qiskit/converters/dagdependency_to_circuit.py`, identifies the missing `circuit.global_phase = dagdependency.global_phase` line.
3. `qiskit-testing` — generates a converter round-trip test asserting not just gate counts but `Operator(qc).equiv(Operator(out))` (full unitary including phase), with a parametric phase sweep: `global_phase = 0, π/4, π/2, ParameterExpression`.
4. `qiskit-good-pr-checklist` — checks sister converters (`circuit_to_dagdependency`, `dag_to_dagdependency`, `dagdependency_to_dag`) for the same omission. Bundles if found; does not widen to unrelated converters (avoiding the narrow-special-case anti-pattern).
5. `qiskit-release-notes` — `fixes:`; `Changelog: Fixed`.
6. `qiskit-backport-process` — backport-eligible (silent phase error in quantum computations).
7. `qiskit-pr-preparation` — done.

**Complexity:** One-line fix, parametric phase test. ~7 skills, ~25 min implementation.

---

### Issue C: [#16097](https://github.com/Qiskit/qiskit/issues/16097) — `qasm3.dumps_experimental` wrong delay units

**Symptom.** Two one-line bugs in the Rust QASM3 exporter: `Millisecond` maps to `"us"`
(typo) and `ps` duration is multiplied instead of divided by 1000, producing silently
incorrect circuit files. The issue body itself discloses: *"This issue was a collaboration
between me and Claude 4.6"* — AI collab already present.

**Skill sequence:**

1. `qiskit-bug-triage` — Rust-side serialization bug, adjacent to § 8.8 (C API / FFI / build). Pulls PR #15649 (annotation handling in Rust QPY) and #16076 (QPY delay integer durations) as nearest cousins.
2. `qiskit-py-rust-bridge` — confirms fix is purely in `crates/qasm3/`; no `sys.modules` change needed.
3. `qiskit-architecture-map` — points at `crates/qasm3/src/ast.rs` (unit string mapping) and `crates/qasm3/src/exporter.rs` (ps conversion arithmetic).
4. `qiskit-coding-conventions` — runs `cargo fmt`, clippy `--all-targets`, ruff/black on the Python test changes.
5. `qiskit-testing` — generates a parametric test over all 6 supported units (`s`, `ms`, `us`, `ns`, `ps`, `dt`), round-tripping each `Delay` and asserting duration equality. Notes the `warnings.filterwarnings("ignore", category=ExperimentalWarning)` requirement for `dumps_experimental`.
6. `qiskit-anti-patterns` — confirms the issue's AI-collab line satisfies the `qiskit-pr-preparation` AI-disclosure check. The rule is human ownership, not no-AI — the disclosure is already present.
7. `qiskit-release-notes` — `fixes:` (not `features_qasm` — that's for new features); `Changelog: Fixed`. Both unit bugs cited.
8. `qiskit-backport-process` — backport-eligible (silently wrong durations would corrupt circuits).
9. `qiskit-pr-preparation` — `Fixes #16097`.

**Complexity:** Two one-line Rust fixes, parametric 6-unit test. ~9 skills, ~45 min.

---

### Issue D: [#14115](https://github.com/Qiskit/qiskit/issues/14115) — Wire `approximation_degree` through `CommutativeCancellation`

**Symptom.** `CommutativeCancellation` internally delegates to `CommutationAnalysis` which
already supports `approximation_degree`, but the outer pass doesn't expose the argument.
Users cannot configure approximate cancellation without bypassing the preset pass managers.

**Skill sequence:**

1. `qiskit-architecture-map` — identifies three locations: `qiskit/transpiler/passes/optimization/commutative_cancellation.py`, `commutation_analysis.py`, and `qiskit/transpiler/preset_passmanagers/` (levels 1/2/3 wiring). Rust counterpart in `crates/transpiler/`.
2. `qiskit-add-transpiler-pass` — **modify mode**: adds the new constructor arg with a default matching current behavior; verifies `MetaPass` constructor-arg auto-hashing is preserved (Mandatory — pass manager deduplication depends on it, § 11.9.5).
3. `qiskit-testing` — three tests: (a) `approximation_degree=None` reproduces current behavior; (b) `approximation_degree=0.99` produces approximate cancellation matching `CommutationAnalysis`; (c) preset pass manager passes the value through end-to-end. **Plus** a control-flow regression test wrapping the cancellable gate pair inside an `IfElseOp` (the #15875 / #15581 / #15413 category of missed recursion).
4. `qiskit-performance-benchmarks` — heuristic-touching change, so ASV before/after numbers are required (precedent: alexanderivrii's *"I would really love to see some experimental data"* on #14911). Run ASV on representative circuits with `approximation_degree=None` vs. `0.99`.
5. `qiskit-release-notes` — `features_transpiler:`; `Changelog: Added`. Potentially a second `performance:` section if benchmarks show a speed delta.
6. `qiskit-backport-process` — no backport (feature, not bug).
7. `qiskit-pr-preparation` — reference #14021 review thread for context.

**Complexity:** Constructor-arg threading through 3 pass-manager levels, control-flow test, ASV benchmarks. Hardest of the four — ~7 skills, 2-4 hours.

---

### Skills Utilization Summary

Across all 10 issues analyzed in `ISSUE_ANALYSIS.md`:

| Skill | Hits (/ 10) | Notes |
|-------|-------------|-------|
| `qiskit-pr-preparation` | **10** | Universal exit ramp — fires on every issue |
| `qiskit-release-notes` | **9** | Skipped only on test-only cleanup (#15097) |
| `qiskit-testing` | **9** | Skipped only on test-only cleanup (#15097) |
| `qiskit-architecture-map` | **8** | Skipped on test-only and small API tweaks |
| `qiskit-backport-process` | **5** | User-visible bug fixes only |
| `qiskit-bug-triage` | **4** | Bug-class issues only |
| `qiskit-api-evolution` | **4** | All API-shape issues |
| `qiskit-good-pr-checklist` | **2** | Used explicitly on multi-step fixes |
| `qiskit-error-handling` | **2** | New raise sites only |
| `qiskit-py-rust-bridge` | **2** | Rust-touching issues |
| `qiskit-coding-conventions` | **2** | Sweep / format-touching issues |
| `qiskit-anti-patterns` | **2** | Combined-sweep reminder + AI disclosure |
| Specialized skills | **1 each** | `qiskit-determinism-audit` (#16138), `qiskit-security-review` (#15370), `qiskit-rust-performance-idioms` (#15370), `qiskit-add-transpiler-pass` (#14115), `qiskit-performance-benchmarks` (#14115), `qiskit-ci-workflows` (#15370) |

The simplest `good first issue` tickets consume 3–5 skills; the most complex consume 7+.
The triad of `qiskit-pr-preparation` + `qiskit-release-notes` + `qiskit-testing` carries
the majority of the load in every case — which precisely matches the playbook finding that
release notes and regression tests are the two highest-frequency review-iteration sources.

**Skills not exercised by a `good first issue` batch** (by design): `qiskit-add-standard-gate`,
`qiskit-optional-dependencies`, `qiskit-deprecation`, `qiskit-build-system`,
`qiskit-qpy-compatibility`, `qiskit-dependency-policy`, `qiskit-release-ceremony`,
`qiskit-debugging`, `qiskit-code-review`. These cover release-ceremony, deeper-cycle, and
infrastructure work — the kind of task that doesn't surface in a curated beginner batch
but will fire in maintainer workflows.

---

*End of document.*

