---
name: qiskit-anti-patterns
description: Catch the patterns Qiskit maintainers actively close PRs over — LLM-spam volume without human ownership; wrong-abstraction-layer fixes; over-restrictive fixes that eliminate legitimate paths; narrow special-case PRs that calcify a path; boilerplate proliferation; non-deterministic parallelism; runtime type-validator dependencies; hand-rolled `warnings.warn(DeprecationWarning(...))`; `Union`/`Optional` instead of modern union syntax; `println!`/`print` for diagnostics. Use whenever the user says "sanity-check this PR", asks "would this pass review?", or as a final pass before `gh pr create`.
---

# Qiskit anti-patterns

Aggregated from PRs maintainers closed without merging. Each pattern below has at least one closure precedent. If your draft matches one of these, expect the same response.

## 1. LLM-spam volume without human ownership (§10.3, **Mandatory**)

**The single biggest closure category** — 9 of 16 closed-unmerged PRs in the last 6 months. jakelishman closed at least six PRs (#16039, #16060, #16062, #16079, #16125, #16127) from one user with a near-canonical message:

> *"I am closing this because this user is spamming LLM PRs at the repository without due human attention. There is simply too much volume here and it is wasting maintainer time. Tiny documentation-only changes do not need 300-line summaries, and neither does documentation need to be as prolix as an unfiltered LLM. One-line bugfixes need one clear bug reproducer, not 300 lines of 'root cause analysis'… Slow down, take one or two PRs through to completion … with you, the human, responding to comments and understanding exactly what issues are."*

CONTRIBUTING.md codifies the rule. The PR template was updated in #15924 to add explicit AI/LLM disclosure.

**Operational consequence:** humans must own the PR. **Volume without engagement** is the blacklist trigger, not AI use per se. AI use **with** disclosure and human ownership is fine.

**How to avoid:**

- Disclose AI tool use in the PR body's checkbox (Mandatory, §11.11.7).
- Keep the description concise (1–4 sentences). No "root cause analysis" walls of text.
- One PR at a time, finished, before opening the next.
- Respond to review comments yourself. Don't copy the maintainer's question into an LLM and paste the answer.

## 2. Wrong-abstraction-layer fix (§11.11.8, **Mandatory**)

A symptom in module A whose root cause is in module B gets fixed in B. jakelishman closed #16062:

> *"This is not a correct fix, because the root fault is not in the exporter but in the importer. The data model of Qiskit is not violated until …"*

**How to avoid:** trace the bad value backwards to where it first becomes wrong. Fix it there. See [[qiskit-architecture-map]] for layering.

## 3. Over-restrictive fix that eliminates legitimate paths

jakelishman on #16116:

> *"This proposed fix is overly restrictive; it is true … that it should be possible to lay out a circuit when only the active qubits fit into the largest chip."*

**How to avoid:** when fixing a too-permissive bug, enumerate the legitimate cases that should still pass. Add tests for them. Make sure the fix doesn't reject them.

## 4. Fix that worsens the symptom

jakelishman on #16124 (CS/CSdg cancellation):

> *"I'm not saying there's no bug in `InverseCancellation`, but `cs(0,1)` does cancel with `csdg(1, 0)`. For the reproducer given, this fix (even though it might be logically correct given the code) actually makes the example worse."*

**How to avoid:** run the *exact* reproducer in the issue. Verify it currently fails as described. Then fix it. Then verify it now passes.

## 5. Narrow special-case PR

alexanderivrii on #16064 (LieTrotter narrow special case):

> *"I am not sure we want such a narrow-focused PR … the request is to add the most general form."*

**How to avoid:** before opening a PR for one case, ask "is the general form just as easy?" If yes, do that. Narrow PRs calcify a special-case path that the next contributor has to dance around.

## 6. Boilerplate proliferation

jakelishman on #15279:

> *"Thanks for all the busywork on this … I just wanted to see if maybe there's a less-boilerplate way to expand this in the future?"*

**How to avoid:** if you find yourself writing the same 10-line block 8 times, extract it to a helper. The reviewer will ask. (For typo sweeps and similar, prefer one combined PR over many small ones — see #15279, also §11.12.2 which is **Disputed**.)

## 7. "Validation" subsection in the PR description

alexanderivrii on #16116:

> *"the summary section [is] somewhat cumbersome to read. In particular, the 'validation' subsection feels unnecessary given that CI already covers this."*

**How to avoid:** don't describe how you tested. CI is the test. State *what* changed and *why*, not *how you verified*.

## 8. Non-deterministic parallelism (§11.8.2, **Mandatory**)

#15410 ("Stop using a parallel sort in disjoint utils") was reverted because the parallel sort introduced ordering non-determinism. #15040 fixed an edge-order non-determinism in DAG node insertion.

**How to avoid:** see [[qiskit-determinism-audit]]. The pattern: compute in parallel, commit serially.

## 9. Runtime type validators (`pydantic`, `typeguard`)

§11.3.3, **Preferred**. Qiskit's boundary validation is manual `isinstance(...)` raising `QiskitError` subclasses. Type hints are documentation, not runtime enforcement.

**How to avoid:** don't add a runtime-validator dependency. Reviewer pushback would be immediate.

## 10. Hand-rolled `warnings.warn(DeprecationWarning(...))`

§11.6.3, §11.13. The `@deprecate_func` / `@deprecate_arg` / `@deprecate_arg_default` decorators are the only sanctioned mechanism. Hand-rolled warnings don't auto-insert Sphinx directives, don't standardize the warning class, don't integrate with the predicate API.

**How to avoid:** see [[qiskit-deprecation]].

## 11. `Union[X, Y]` / `Optional[X]` type hints

§11.9.2, **Mandatory**. Modern union syntax (`X | Y`, `X | None`) only.

**How to avoid:** use `from __future__ import annotations` + modern unions. Run `tox -elint` before push.

## 12. `print()` / `println!` for diagnostics

§11.4.2, **Mandatory**. `T20` ruff rule for Python; clippy `deny(print_stdout, print_stderr)` workspace-wide for Rust. Recurring rolling-fix PRs (#15280, #15107, #15716, #15804, #16052) are evidence the rule is enforced on every drift.

**How to avoid:** see [[qiskit-debugging]]. Use `logger` for instrumentation, `warnings.warn` for soft user-facing signals.

## 13. Module-top imports of optional deps

§11.10.2, **Mandatory**. Module-top `import matplotlib` would crash users on minimal environments.

**How to avoid:** see [[qiskit-optional-dependencies]]. Use `qiskit.utils.optionals` lazy testers; import inside the function.

## 14. Single-test deprecation PRs

§11.5.2, **Mandatory**. `QiskitTestCase` treats `DeprecationWarning` as an error. A test that only exercises the deprecated path will fail; a test that only exercises the new path doesn't prove the warning is emitted.

**How to avoid:** see [[qiskit-deprecation]]. Two tests: one with `assertWarns(DeprecationWarning)` for the old path, one warning-free for the new path.

## 15. Bug fix without a regression test

§11.5.1, **Mandatory**. Reviewers reject fixes whose reproducer "almost works" or where the fix doesn't address the cited issue.

**How to avoid:** see [[qiskit-testing]]. Stash the source change, confirm the new test fails, un-stash, confirm it passes.

## 16. Heuristic / hot-path change without benchmarks

§11.7.2, **Mandatory**. alexanderivrii on #14911 (Sabre lookahead):

> *"I would really love to see some experimental data. Even though I am on board with the intuition behind the new heuristic, we don't want to risk making sabre accidentally worse."*

**How to avoid:** see [[qiskit-performance-benchmarks]]. Run ASV, include the table in the PR body.

## 17. Behavior change without a reno entry

§11.6.5, **Mandatory**. Cryoris on #15494:

> *"Thanks for adding the test! Could you also add a release note describing the fix (in the `fixes:` section)?"*

**How to avoid:** see [[qiskit-release-notes]]. `Changelog: None` is acceptable for refactors / dep bumps / typos.

## 18. Inflated PGO training circuits

§11.7.6, **Preferred**. #16146 reverted #15931 which inflated a PGO QV training circuit from 100 → 193 qubits, slowing profile collection.

**How to avoid:** keep PGO training inputs small/representative. If you change them, treat as a separate (potentially regressing) change.

## 19. Repurposing private import paths into public API

§11.6.1, **Mandatory**. The public API is what's documented in Sphinx. Private import paths can move without deprecation.

**How to avoid:** see [[qiskit-api-evolution]]. Don't deprecate-then-remove `qiskit.circuit.measure` (private); the contract was never that this path was stable.

## 20. Missing `Fixes #N` exact phrasing

§11.11.3, **Mandatory**. CONTRIBUTING.md is explicit. GitHub only auto-closes with the exact form.

**How to avoid:** use `Fixes #N` (one per issue, on its own line). Not "Closes #N", not "Fix #N" within prose.

## How to use this skill

Walk the diff and the PR draft. For each anti-pattern, check whether the change exhibits it. Report findings as:

```
- [Pattern #N: <short name>] — <where it appears> → <what to do>.
```

Be concrete. Cite line numbers. Recommend the related skill that fixes the issue.

## Related skills

- [[qiskit-good-pr-checklist]] — the positive form of this list.
- [[qiskit-pr-preparation]] — the description that avoids LLM-bloat.
- [[qiskit-deprecation]] — fix #10, #14.
- [[qiskit-determinism-audit]] — fix #8.
- [[qiskit-performance-benchmarks]] — fix #16.
- [[qiskit-release-notes]] — fix #17.
- [[qiskit-architecture-map]] — fix #2, #3, #4.
- [[qiskit-bug-triage]] — fix #4 (run the actual reproducer).
- [[qiskit-coding-conventions]] — fix #11, #12.
- [[qiskit-optional-dependencies]] — fix #13.
- [[qiskit-api-evolution]] — fix #19.
