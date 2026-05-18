# 9. Reviewer Expectations

Synthesized from inline `gh api repos/Qiskit/qiskit/pulls/<n>/comments` review threads and PR
descriptions across ~130 PRs in the Nov 2025 – May 2026 window.

## 9.1 Release notes — Mandatory for user-facing changes

**Status: Explicit** (CONTRIBUTING.md), enforced through review.

Reviewers consistently push back when a behavior change ships without a reno entry on the
right `Changelog: …` axis.

- **#15494** ("Fix `plot_state_qsphere` phase-anchor bias"), Cryoris:
  > *"Thanks for adding the test! Could you also add a release note describing the fix
  > (in the `fixes:` section)?"*
- **#16014** (parallelize `CommutationAnalysis`), alexanderivrii:
  > *"And you should probably add a performance release note to the PR (I have added the
  > `Changelog Performance` label)."*
  This PR drove the introduction of the `Performance` changelog category in **#16065**.
- **#14911** (Sabre lookahead heuristic), alexanderivrii:
  > *"Since this changes the behavior of the lookahead heuristic, would you like to add a
  > release note?"*

**Conversely**, `Changelog: None` PRs (QA, internal Rust refactors, dep bumps) need no reno.
Examples: **#15716**, **#15839**, **#16128**, **#16101**, **#16019**, **#15989**, **#15952**.

**Confidence:** High.

## 9.2 Tests must reproduce the bug — Mandatory

**Status: Explicit** (CONTRIBUTING.md "tests included or justified"), enforced strictly.

- **#16124** (CS/CSdg inverse cancellation), jakelishman — closed without merge:
  > *"I'm not saying there's no bug in `InverseCancellation`, but `cs(0,1)` does cancel with
  > `csdg(1, 0)`. For the reproducer given, this fix (even though it might be logically
  > correct given the code) actually makes the example worse."*
- **#15967** (C transpiler level 3), mtreinish:
  > *"the most important one is that your fix can potentially cause an infinite loop because
  > other parts of the struct were incorrect so we'll need to fix that before this merges.
  > Also we should add test coverage of this when the fix is added too."*
- **#15815**, Cryoris:
  > *"(a) add tests checking PPM commutation … and (b) scramble the indices of the existing
  > PPR tests … a bit more (right now there's only 1 index swap)."*
- **#15672 / #15673** (MCX with 0 controls), ShellyGarion:
  > *"Would you like to add a test that asserts that calling MCX with negative number of
  > qubits raises an error?"*

**Confidence:** High.

## 9.3 PR description quality — Strongly enforced

**Status: Explicit + Inferred.**

PR template (`.github/PULL_REQUEST_TEMPLATE.md`) was simplified in **#15924** to nudge
contributors toward terse, human-written summaries. Reviewers actively dislike:

- LLM-generated bloat (see `10-maintainer-preferences.md` § 10.3).
- "Validation" subsections that duplicate CI's job. **#16116**, alexanderivrii:
  > *"the summary section [is] somewhat cumbersome to read. In particular, the 'validation'
  > subsection feels unnecessary given that CI already covers this."*

CONTRIBUTING.md mandates `Fixes #N` syntax (exact phrasing) for issue auto-closure.

**Confidence:** High.

## 9.4 Docstring & type-hint nits (Cryoris)

**Status: Inferred** from inline review comments on **#15832** (PEP 484 type-hints PR):

- Use `` ``dag`` `` (double-backtick RST), not `*dag*` (italic).
- Prefer `if TYPE_CHECKING:` guard over `from __future__ import annotations` to keep diffs
  minimal.
- Don't widen restrictive types incorrectly:
  > *"Why change from `Iterable` to `set`? That seems more restrictive."*
- Don't strip whitespace-only docstring lines:
  > *"IMO it's much easier to see the module docstring with this whitespace, could you leave
  > these as they were?"*
- Drop redundant `__init__` summaries on analysis passes:
  > *"This is true for every analysis pass and doesn't need to be pointed out explicitly."*

The "missing argument in docstring" lint became CI-blocking in **#15721**.

**Confidence:** High.

## 9.5 Rust-side review (mtreinish, jakelishman)

**Status: Inferred.**

### Avoid spurious heap allocations

- **#16123** mtreinish:
  > *"Since this is always 4 matrices you don't need the smallvec … allocating a vec is
  > extra overhead we don't need yet."*
  Suggested `[Matrix2<Complex64>; 4]` and `try_inverse_mut()` for in-place inversion.

### Extend native iterators rather than duplicating logic

- **#15999** jakelishman:
  > *"In principle I think this is sound … but I would rather just make `nodes_on_wire` the
  > iterator natively than largely duplicating its logic."*

### Replace panics with compile-time checks

- **#16010** "Replace infallible `expect` with compile-time checks in VF2".
- **#15635** "Avoid panics in Quantum Shannon Decomposition Rust code".

### Keep tooling tight

- **#15839** Cargo.lock currency check now in lint.
- **#16128** clippy now runs `--all-targets` (covers tests).
- Rolling clippy-warning sweeps as toolchain advances: **#15280**, **#15107**, **#15716**,
  **#15804**, **#16052**.

### Move from `scipy` → `numpy` / `nalgebra` / `faer` in hot paths

- **#16016**, **#15960**, **#15874**, **#15881**, **#15928**, **#15871**.

**Confidence:** High.

## 9.6 Small focused PRs preferred — strongly

**Status: Explicit + Inferred.**

- **#16064** (LieTrotter narrow special case), alexanderivrii closed it:
  > *"I am not sure we want such a narrow-focused PR … the request is to add the most
  > general form."*
  (Inverse case: too narrow *and* would calcify a special-case path.)
- Big refactors land as long sequences of small reviewable PRs before the payoff:
  the two-qubit decomposer reorganisation is split across **#15833**, **#15880**, **#15909**,
  **#15910**, **#15912**, **#15913**, **#15914**, **#15915**, with the perf payoff in
  **#15960**.

Behavior-changing PRs need empirical justification, not just intuition:

- **#14911** alexanderivrii (repeatedly):
  > *"I would really love to see some experimental data. Even though I am on board with the
  > intuition behind the new heuristic, we don't want to risk making sabre accidentally
  > worse."*

**Confidence:** High.

## 9.7 Deprecation tests — Both paths required

**Status: Explicit** (CONTRIBUTING.md:928-953).

DeprecationWarning must be tested with `assertWarns`; tests must be split:

1. one for the deprecated code path (with `assertWarns`),
2. one for the new code path (no warning).

QiskitTestCase treats `DeprecationWarning` as an error by default — tests forgetting either
side will fail.

**Confidence:** High.

## 9.8 Implicit "good PR" checklist (reconstructed)

For non-trivial PRs:

1. **Correct fix at the right abstraction layer.** Wrong-layer fixes are closed (e.g.
   **#16062**: *"This is not a correct fix, because the root fault is not in the exporter
   but in the importer."*).
2. **Regression test that demonstrates the original failure.**
3. **Reno entry on the right `Changelog: …` axis** (or `Changelog: None` justified).
4. **Concise human-written description** with `Fixes #N`.
5. **AI/LLM disclosure** if any AI tool was used.
6. **Performance benchmarks** if you change a heuristic or a hot path.
7. **Control-flow test** if you touch a transpiler pass that could see `ControlFlowOp`.
8. **Backport label** (`stable backport potential`) for user-visible bug fixes.

**Confidence:** Medium-High. **Inferred.**
