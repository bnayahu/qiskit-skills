# AGENTS.md

Guidance for AI coding agents working in this repository. Human contributors should read
[`CONTRIBUTING.md`](CONTRIBUTING.md) and [`MAINTAINING.md`](MAINTAINING.md) first — this file
is the agent-facing index that points into them.

Explicit user prompts override anything written here. Where this file disagrees with
`CONTRIBUTING.md` / `MAINTAINING.md` / `DEPRECATION.md`, those files win.

## Project overview

Qiskit is a hybrid Python + Rust SDK for quantum computing. The Python package lives in
[`qiskit/`](qiskit/); the Rust workspace lives in [`crates/`](crates/) and is exposed as a
single `cdylib` (`qiskit._accelerate`) registered manually in
[`qiskit/__init__.py`](qiskit/__init__.py). Crate dependencies flow one-way; Rust never
imports Python submodules at module init time.

For a deeper map of the layout (which crate holds what, where a feature should live), see the
[`qiskit-architecture-map`](.claude/skills/qiskit-architecture-map) skill or
[`playbook/01-architecture.md`](./docs/playbook/01-architecture.md).

## Authoritative references for agents

Two locations capture the project's accumulated conventions and recurring review feedback.
Consult them before writing non-trivial code.

### Playbook — `./docs/playbook/`

Long-form, evidence-cited inventory of the repository (file paths, line ranges, PR numbers).
Use it when you need the *why* behind a convention or want to see prior art.

| File | Topic |
|------|-------|
| [`00-index.md`](./docs/playbook/00-index.md) | Index, conventions, sample size |
| [`01-architecture.md`](./docs/playbook/01-architecture.md) | Subsystem boundaries, Py↔Rust FFI |
| [`02-build-and-test.md`](./docs/playbook/02-build-and-test.md) | Build system, test runners, env knobs |
| [`03-coding-conventions.md`](./docs/playbook/03-coding-conventions.md) | Lint, format, docstrings, imports |
| [`04-dependency-management.md`](./docs/playbook/04-dependency-management.md) | Python + Rust deps, lockfile, pinning |
| [`05-cicd-workflows.md`](./docs/playbook/05-cicd-workflows.md) | GitHub Actions, Mergify, qiskit-bot |
| [`06-release-engineering.md`](./docs/playbook/06-release-engineering.md) | Release ceremony, branches, deprecation, reno |
| [`07-implementation-patterns.md`](./docs/playbook/07-implementation-patterns.md) | Gates, transpiler passes, exceptions, type-hints |
| [`08-bug-categories.md`](./docs/playbook/08-bug-categories.md) | Recurring bug categories with PR citations |
| [`09-reviewer-expectations.md`](./docs/playbook/09-reviewer-expectations.md) | What reviewers consistently ask for |
| [`10-maintainer-preferences.md`](./docs/playbook/10-maintainer-preferences.md) | Maintainer roster, anti-LLM-spam policy |
| [`11-implicit-conventions.md`](./docs/playbook/11-implicit-conventions.md) | Cross-cutting implicit conventions, mandatory/preferred/disputed tiers |

### Skills — `.claude/skills/`

Action-oriented playbooks invoked via the Skill tool. Prefer a skill over re-deriving
conventions from scratch. Each skill encodes a recurring task and links to the relevant
playbook section and prior PRs.

**Orientation & review**
- [`qiskit-architecture-map`](.claude/skills/qiskit-architecture-map) — "where does X live?"
- [`qiskit-bug-triage`](.claude/skills/qiskit-bug-triage) — classify a reported bug into a recurring category
- [`qiskit-code-review`](.claude/skills/qiskit-code-review) — maintainer-style diff review
- [`qiskit-good-pr-checklist`](.claude/skills/qiskit-good-pr-checklist) — pre-`gh pr create` audit
- [`qiskit-anti-patterns`](.claude/skills/qiskit-anti-patterns) — patterns reviewers actively close PRs over

**Building & testing**
- [`qiskit-build-system`](.claude/skills/qiskit-build-system) — PEP 517, profile flags, Makefile targets
- [`qiskit-ci-workflows`](.claude/skills/qiskit-ci-workflows) — map CI checks to workflow files
- [`qiskit-testing`](.claude/skills/qiskit-testing) — pick the right runner (tox, cargo, make ctest)
- [`qiskit-debugging`](.claude/skills/qiskit-debugging) — logging idioms, miri, UBSan
- [`qiskit-performance-benchmarks`](.claude/skills/qiskit-performance-benchmarks) — ASV before/after numbers

**Code conventions**
- [`qiskit-coding-conventions`](.claude/skills/qiskit-coding-conventions) — black/ruff, modern unions, docstrings
- [`qiskit-error-handling`](.claude/skills/qiskit-error-handling) — choose the right exception class
- [`qiskit-py-rust-bridge`](.claude/skills/qiskit-py-rust-bridge) — `sys.modules` registration, PyO3 init rules
- [`qiskit-rust-performance-idioms`](.claude/skills/qiskit-rust-performance-idioms) — hot-path Rust idioms

**Adding things**
- [`qiskit-add-standard-gate`](.claude/skills/qiskit-add-standard-gate) — scaffold a new standard gate
- [`qiskit-add-transpiler-pass`](.claude/skills/qiskit-add-transpiler-pass) — scaffold an analysis/transformation pass
- [`qiskit-dependency-policy`](.claude/skills/qiskit-dependency-policy) — Python or Rust dep additions
- [`qiskit-optional-dependencies`](.claude/skills/qiskit-optional-dependencies) — wrap non-required deps via `qiskit.utils.optionals`

**API evolution & releases**
- [`qiskit-api-evolution`](.claude/skills/qiskit-api-evolution) — public surface, two-version window
- [`qiskit-deprecation`](.claude/skills/qiskit-deprecation) — `@deprecate_func`, paired tests
- [`qiskit-qpy-compatibility`](.claude/skills/qiskit-qpy-compatibility) — QPY format-version bumps
- [`qiskit-backport-process`](.claude/skills/qiskit-backport-process) — `stable backport potential` label
- [`qiskit-release-ceremony`](.claude/skills/qiskit-release-ceremony) — 6-step release cut
- [`qiskit-release-notes`](.claude/skills/qiskit-release-notes) — reno YAML, `Changelog:` axes
- [`qiskit-pr-preparation`](.claude/skills/qiskit-pr-preparation) — PR body, AI/LLM disclosure

**Correctness reviews**
- [`qiskit-determinism-audit`](.claude/skills/qiskit-determinism-audit) — review parallelism for ordering bugs
- [`qiskit-security-review`](.claude/skills/qiskit-security-review) — C API / FFI / `unsafe` checklist

## Build & test commands

Full details live in [`playbook/02-build-and-test.md`](./docs/playbook/02-build-and-test.md)
and the [`qiskit-build-system`](.claude/skills/qiskit-build-system) skill. Quick reference:

```bash
pip install -e .            # editable install — debug profile (slow Rust)
pip install .               # release profile build

tox -epy313                 # Python unit tests on 3.13 (pick your version)
tox -erust                  # Rust unit tests via cargo
tox -elint                  # black + ruff + pylint + cargo fmt/clippy
tox -eminoptional           # tests with optional deps absent

cargo test                  # raw cargo (no Python harness)
make ctest                  # C API tests + UBSan
make c                      # build the C library
```

`QiskitTestCase` treats `DeprecationWarning` and `QiskitWarning` as errors. Set
`QISKIT_PARALLEL=FALSE` to debug a flaky test; `QISKIT_TESTS=run_slow=True` to include
slow tests. See [`qiskit-testing`](.claude/skills/qiskit-testing).

## Code style — non-negotiables

- `from __future__ import annotations` at the top of every `.py` file.
- Modern union syntax (`X | Y`), not `Union[X, Y]` / `Optional[X]`.
- Google-style docstrings; D417 (missing argument descriptions) is enforced.
- Black at 100 cols; ruff at 110 (defers to black).
- Never `print` in Python or `println!` in Rust — use `logging.getLogger(__name__)` with
  `%s`/`%d`-style deferred formatting.
- No `.expect(...)` or panics on user-reachable Rust paths.
- Hand-rolled `warnings.warn(DeprecationWarning(...))` is rejected — use the
  `@deprecate_func` / `@deprecate_arg` decorators.

Run [`qiskit-coding-conventions`](.claude/skills/qiskit-coding-conventions) or `tox -elint`
before pushing.

## PR guidelines

Every user-visible change needs a reno entry on the right `Changelog:` axis. Backports
*do not* duplicate the reno — the original carries it.

Pre-PR checklist (full version in [`qiskit-good-pr-checklist`](.claude/skills/qiskit-good-pr-checklist)):

- [ ] Regression test that fails before the fix
- [ ] Reno YAML under `releasenotes/notes/` with the right axis (`features_*`, `fixes`,
      `performance`, `upgrade*`, `deprecations*`, `build`, `critical`, `security`, `other`)
- [ ] AI/LLM disclosure in the PR body if any AI assistance was used
- [ ] `Fixes #N` (exact phrasing) when closing an issue
- [ ] Benchmark data for heuristic / hot-path changes (ASV before/after table)
- [ ] Control-flow regression test for any transpiler pass that walks a DAG
- [ ] `stable backport potential` label for user-visible bug fixes
- [ ] Correct abstraction layer — fix at the source, not the symptom (#16062 lesson)

LLM-bloated PR descriptions are the single largest closure category in this repo. Write
the summary yourself, keep it concise, and disclose AI assistance.

## Things that get PRs closed

These show up over and over in [`playbook/10-maintainer-preferences.md`](./docs/playbook/10-maintainer-preferences.md)
and [`qiskit-anti-patterns`](.claude/skills/qiskit-anti-patterns):

- High-volume LLM-generated PRs without a human owner who can defend the change
- Wrong-abstraction-layer fixes (patching a symptom in a caller instead of fixing the root)
- Over-restrictive fixes that close legitimate code paths
- Narrow special-case PRs that calcify a single path
- Non-deterministic parallelism — determinism > raw speed (mandatory, see
  [`qiskit-determinism-audit`](.claude/skills/qiskit-determinism-audit))
- Module-top imports of optional dependencies (CONTRIBUTING.md:978-983)
- Missing the second deprecation test (the warning-free new path)
- Skipping benchmark data on a heuristic change

## Recurring bug categories

If you're triaging a reported bug, run [`qiskit-bug-triage`](.claude/skills/qiskit-bug-triage)
and consult [`playbook/08-bug-categories.md`](./docs/playbook/08-bug-categories.md).
The recurring categories — in rough frequency order — are:

1. Control-flow correctness (missing `ControlFlowOp.blocks` recursion in transpiler passes)
2. QPY round-trip
3. Synthesis correctness — silent `global_phase` drops (#15943, #15944)
4. Commutation / cancellation
5. Visualization (mpl/latex)
6. Parameter expressions
7. Panics / leaks (Rust)
8. C API / FFI
9. Threading non-determinism
10. Docs / typos

## Working on this repo

- Treat the playbook and skills as living documents. If you discover a new convention or a
  recurring review nit that isn't captured, propose an edit to the relevant playbook file or
  skill — don't paper over it locally.
- Prefer editing existing files over creating new ones; do not generate planning or summary
  docs unless asked.
- Confirm before destructive or remote-visible actions (force-push, branch deletion, PR
  creation) — local edits and `cargo`/`tox` runs are fine.
