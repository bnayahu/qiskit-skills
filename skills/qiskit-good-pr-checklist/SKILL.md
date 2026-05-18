---
name: qiskit-good-pr-checklist
description: Audit a Qiskit PR branch against the implicit "good PR" checklist before review is requested — regression test, correct abstraction layer, reno entry on the right `Changelog:` axis, AI/LLM disclosure, benchmark data for heuristic/hot-path changes, control-flow test for transpiler passes, backport label for user-visible bug fixes. Use whenever the user says "audit my branch", "is this PR ready", "what's missing before I push", or before any `gh pr create` for Qiskit. Catches the items that maintainers consistently round-trip on.
---

# Qiskit good-PR checklist

This skill walks the reconstructed checklist from playbook §9.8. The goal is to surface every item a reviewer would otherwise ask for — saving one full review cycle. Run it on the user's current branch (`git diff main...HEAD`).

## How to run

1. **Identify what changed.** `git diff --name-only main...HEAD`. Group the files into Python source / Rust source / tests / `releasenotes/` / docs / build.
2. **Walk each item below in order.** Surface the result as a short table: ✓ done, ⚠ missing, n/a.
3. **Stop and tell the user before they push** if any Mandatory item is missing.

## The items

### 1. Right abstraction layer (Mandatory, §11.11.8)

Before anything else: is the fix in the right place? Wrong-layer fixes get closed (#16062: jakelishman closed an exporter fix because the importer was the actual source). For a bug, ask: "if I trace the bad value backwards, where is it first wrong?" Fix it there.

### 2. Regression test that fails before the fix (Mandatory, §11.5.1)

Every bug fix must include a test that reproduces the original failure. Reviewers reject "fix that worsens the symptom" PRs (jakelishman closed #16124 because `cs(0,1)` actually does cancel with `csdg(1,0)` and the proposed fix made the example worse). To verify: stash the source change, run the new test, confirm it fails; un-stash, confirm it passes.

For features, the regression test is replaced by adequate test coverage — a happy-path test plus the obvious edge cases (negative input, zero qubits, empty circuit, etc.). Reviewer ShellyGarion explicitly asks for negative-input tests (#15673: *"Would you like to add a test that asserts that calling MCX with negative number of qubits raises an error?"*).

### 3. Reno entry on the right `Changelog:` axis (Mandatory for user-visible, §11.6.5)

If the change is user-visible, there must be a YAML file in `releasenotes/notes/` (named by `reno new`, never hand-named) on one of these axes:

- `features_*` (circuits, transpiler, qpy, synthesis, primitives, …) for new public API.
- `fixes` for bug fixes (Cryoris in #15494: *"Could you also add a release note describing the fix"*).
- `performance` for speed/memory wins (#16065 added the category, driven by #16014).
- `upgrade*` / `deprecations*` / `build` / `critical` / `security` / `other`.

`Changelog: None` is acceptable for refactors, dep bumps, CI changes, typos — no reno required. Backports do **not** duplicate the entry (the original carries it).

If the user doesn't have one, hand off to [[qiskit-release-notes]].

### 4. AI/LLM disclosure (Mandatory, §11.11.7)

The PR template's disclosure box must be filled in. CONTRIBUTING.md and the template (updated #15924) require the tool name and version. Volume + missing disclosure → templated closure (jakelishman closed at least 6 PRs from one user this way).

### 5. `Fixes #N` exact phrasing (Mandatory, §11.11.3)

If a referenced issue should auto-close, the body must contain `Fixes #N` with that exact wording. CONTRIBUTING.md is explicit.

### 6. Benchmark data for heuristic/hot-path changes (Mandatory, §11.7.2)

If the change affects a transpiler heuristic (Sabre, BasisTranslator priority, layout cost), or a Rust hot path, run ASV benchmarks before/after and include the table. alexanderivrii pushed back on #14911 (Sabre lookahead) repeatedly: *"I would really love to see some experimental data."* Hand off to [[qiskit-performance-benchmarks]] for the format.

### 7. Control-flow test for transpiler passes touching DAG nodes (Preferred → near-Mandatory, §11.5.3)

If the change touches a transpiler pass and the pass walks DAG nodes, add a test using nested `IfElseOp`/`ForLoopOp`/`WhileLoopOp`/`BreakLoopOp`. Missing this is the **single largest recurring bug category** (§8.1, eight separate PRs in the sample window). The pass must descend into `ControlFlowOp.blocks`. Hand off to [[qiskit-add-transpiler-pass]] for the test scaffold.

### 8. Deprecation tests cover both paths (Mandatory if deprecating, §11.5.2)

If the diff adds a `@deprecate_func` / `@deprecate_arg`, there must be two tests: one with `assertWarns(DeprecationWarning)` for the old path, one warning-free for the new path. `QiskitTestCase` treats `DeprecationWarning` as an error. Hand off to [[qiskit-deprecation]].

### 9. QPY round-trip fixture for format changes (Mandatory, §11.5.4)

If `crates/qpy/` or `qiskit/qpy/` changed format-version logic, there must be a fixture under `test/qpy_compat/` and the format version must be incremented in both Python and Rust. Hand off to [[qiskit-qpy-compatibility]].

### 10. Determinism preserved on parallel paths (Mandatory, §11.8.2)

If the change adds `par_iter` or any parallelism, output ordering must be deterministic. #15410 was reverted because a parallel sort introduced ordering non-determinism. Hand off to [[qiskit-determinism-audit]] if the diff has `par_iter`, `par_sort`, or `concurrent.futures`.

### 11. Backport label for user-visible bug fixes (Preferred, §11.11.4)

If this is a user-visible bug fix that still applies to the active stable branch, suggest applying `stable backport potential`. Mergify will then open the backport PR (`.mergify.yml`). Features and refactors are not backported. Hand off to [[qiskit-backport-process]].

### 12. PR body is concise and human-written (Mandatory, §11.11.2)

No "Validation" subsection, no 300-line root-cause walkthrough, no LLM prose. Hand off to [[qiskit-pr-preparation]] for the body itself.

## Output format

Report the audit as a table:

```
| #  | Item                          | Tier        | Status | Note                          |
|----|-------------------------------|-------------|--------|-------------------------------|
| 1  | Right abstraction layer       | Mandatory   | ✓      | Fix in transpiler/, root cause confirmed |
| 2  | Regression test               | Mandatory   | ⚠      | No test added for the new path |
| 3  | Reno entry                    | Mandatory   | ⚠      | No file under releasenotes/notes/ |
...
```

End with the missing items and a single sentence: "Address {1-2 highest-priority gaps} before requesting review."

## Related skills

- [[qiskit-pr-preparation]] — the body itself.
- [[qiskit-release-notes]] — write the reno YAML.
- [[qiskit-anti-patterns]] — what closures look like.
- [[qiskit-add-transpiler-pass]] — control-flow test scaffold.
- [[qiskit-deprecation]] — both-path tests.
- [[qiskit-qpy-compatibility]] — fixture + format version.
- [[qiskit-performance-benchmarks]] — ASV before/after.
