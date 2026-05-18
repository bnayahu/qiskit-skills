---
name: qiskit-code-review
description: Run a Qiskit maintainer-style review on a diff. Knows the recurring nits (use `` ``dag`` `` not `*dag*`, don't widen/narrow types reflexively, avoid `expect`/panic in Rust, drop redundant `__init__` summaries on analysis passes, request perf data for heuristic changes), and routes to the right specialist via `qiskit_bot.yaml` paths. Use whenever the user asks "review this PR", "review my diff", or wants a second-opinion pass before requesting human review.
---

# Qiskit code review

Apply the implicit review checklist that Cryoris, mtreinish, alexanderivrii, and jakelishman bring to PRs. The aim is to catch the items those reviewers consistently round-trip on, before requesting human review.

## How to run

1. Read the diff (`git diff main...HEAD` or the PR diff).
2. Categorize the change: bug fix / feature / refactor / Rust-port / perf / dep bump / typo.
3. Walk the relevant nit categories below.
4. Report findings as a list, each tagged with severity:
   - **Blocker** — Mandatory item missing (per playbook tiers).
   - **Nit** — Preferred item; reviewer would ask but won't block merge.
   - **Praise** — Item done well; mention briefly so the contributor knows.

## Routing — who would review this?

`qiskit_bot.yaml` and CODEOWNERS map paths to maintainers. Use this to anticipate the reviewer's concerns:

| Path you touched | Likely reviewer | Their concerns |
|---|---|---|
| `qpy/`, `crates/qpy/` | mtreinish (also jakelishman) | Round-trip, version bump, fixture, Rust ↔ Python parity |
| `circuit/library/`, feature maps | Cryoris, ajavadia | Docstrings, math, type hints, readability |
| `primitives/` | t-imamichi, ajavadia, levbishop | API stability, V2 abstractions |
| Synthesis / Clifford / fault-tolerance / PPR / PPM | alexanderivrii, ShellyGarion | Edge cases, global phase, benchmark data |
| Sabre / transpiler perf | mtreinish | Benchmarks, determinism, Rust idioms |
| Visualization (Rust drawer) | eliarbel | Snapshot quality |
| C API / FFI | mtreinish, jakelishman | Memory safety, miri, UB |
| Anything not above | @Qiskit/terra-core (jakelishman default) | Layering, AI disclosure, description quality |

## Nits per category

### Python source

- **`from __future__ import annotations`** at top? (§11.9.2, **Mandatory** for new code.)
- **Modern union syntax** (`X | Y`)? Flag any `Optional[X]` / `Union[X, Y]`.
- **`if TYPE_CHECKING:` for circular imports** (e.g. `DAGCircuit`).
- **Google docstrings** with `:class:` / `:func:` roles? Use `` ``code`` `` not `*code*` (Cryoris #15832).
- **D417** — every public arg documented? (#15721 made this CI-blocking.)
- **Don't widen / narrow types reflexively.** Cryoris #15832: *"Why change from `Iterable` to `set`?"*
- **No `print()`** — `T20` rule.
- **Optional deps imported inside functions, not at module top** — see [[qiskit-optional-dependencies]].
- **No bare `Exception` raises** — use `QiskitError` subclasses for domain errors. See [[qiskit-error-handling]].
- **Drop redundant `__init__` summaries** on analysis passes (Cryoris).

### Rust source

- **No `expect`/panic on user-reachable paths.** Replace with `?` propagation, compile-time checks, or `Result`. PRs #16010, #15635, #16054.
- **No `println!` / `eprintln!`** — clippy denies workspace-wide.
- **Fixed-size arrays over `SmallVec`/`Vec`** when N is statically known (mtreinish #16123).
- **Don't reimplement existing iterators** — extend a native iterator (jakelishman #15999).
- **Prefer `numpy`/`nalgebra`/`faer` over `scipy`** in hot paths. Recent migrations: #16016, #15960, #15874, #15881, #15928, #15871.
- **`import_exception!` macro** for surfacing `QiskitError` from Rust.
- **Determinism** preserved on parallel paths — see [[qiskit-determinism-audit]].
- **`unsafe_op_in_unsafe_fn`** — every unsafe op inside an `unsafe fn` must be in its own `unsafe { … }` block.

### Tests

- **Regression test that fails before the fix?** Mandatory for bug fixes (§11.5.1).
- **Control-flow test** if the diff touches a transpiler pass walking DAG nodes? Near-Mandatory (§11.5.3).
- **Both deprecation paths tested?** If `@deprecate_*` decorator added (§11.5.2).
- **QPY fixture** if format version bumped? (§11.5.4)
- **`QiskitTestCase`** as the base class, not bare `unittest.TestCase`?
- **`assertWarns(DeprecationWarning)`** for deprecated paths — `QiskitTestCase` treats them as errors otherwise.

### Reno entry

- Is one needed? See [[qiskit-release-notes]] and §6.6 for the matrix.
- If yes, on the right axis (`features_*`, `fixes`, `performance`, `upgrade*`, `deprecations*`)?
- Reference public symbols with `:class:` / `:func:` Sphinx roles, not raw names.
- One section per axis, not per file.

### PR description

- Concise and human-written? No "Validation" subsection (alexanderivrii #16116)?
- `Fixes #N` exact phrasing if closing an issue (CONTRIBUTING.md, **Mandatory**)?
- AI/LLM disclosure box filled in? Volume + missing disclosure → blacklist precedent.
- Suggested `Changelog:` label?
- For heuristic / hot-path changes, ASV table in the body (§11.7.2, **Mandatory**)?

### Architecture / layering

- **Right abstraction layer?** Wrong-layer fixes get closed (§11.11.8). For a bug, trace the bad value backwards. #16062 (a fix in QASM exporter that should have gone in the importer) is the canonical close.
- **One-way crate dependency direction.** `qiskit-circuit` does not depend on `qiskit-transpiler`. See [[qiskit-architecture-map]].

### Closure precedents

If the PR shape matches one of the historical close categories, flag it:

- **LLM-spam** (§10.3, 9 of 16 closed-unmerged PRs): high volume, missing disclosure, prolix prose. #16039, #16060, #16062, #16079, #16125, #16127, #15994.
- **Wrong-layer fix**: #16062 closed because the importer was the source.
- **Fix that worsens the symptom**: #16124 closed because the proposed fix made the reproducer worse.
- **Over-restrictive fix**: #16116 closed because it eliminated legitimate paths.
- **Narrow special case**: #16064 closed because the general form was wanted.

See [[qiskit-anti-patterns]] for the full list.

## Output template

```
## Review of <branch> @ <sha>

Summary: <one sentence>.

### Blockers
- <file>:<line> — <issue>. (§<playbook ref>)

### Nits
- <file>:<line> — <issue>.

### Praise
- <what was done well>

### Suggested next steps
- <ordered list>
```

## What to leave to the reviewer

Don't pre-judge:

- Whether the fix is *correct*. You can sanity-check the logic, but maintainer review still owns merge.
- Whether the design is *right*. Architectural pushback (#16064 LieTrotter narrow case) is a maintainer call.
- Whether the contribution is *welcome*. Don't hand out closures.

## Heuristics

- **Be specific.** "Add a control-flow test" is better than "improve test coverage."
- **Cite the playbook section** so the contributor can self-serve the rationale.
- **Prefer praise + nit pairs** to a wall of nits. Reviewers who only complain demoralize contributors.
- **For Rust diffs, start with the no-panic / no-allocation checks** — those are the most common nits.
- **For Python diffs, start with type hints, docstrings, and reno entries** — those are the most common nits.

## Related skills

- [[qiskit-good-pr-checklist]] — what the contributor should have audited first.
- [[qiskit-anti-patterns]] — full closure precedents.
- [[qiskit-rust-performance-idioms]] — Rust-side recurring nits.
- [[qiskit-coding-conventions]] — formatting and style.
- [[qiskit-bug-triage]] — what category a bug fix falls into.
