# Qiskit Skills

A set of 27 Claude Code skills and an 11-file playbook for AI-assisted development
on the [Qiskit](https://github.com/Qiskit/qiskit) repository. The skills encode
Qiskit's tacit conventions — distilled from 180+ merged PRs, maintainer review
patterns, and the codebase's git history — into reusable, invocable guidance that
fires at the right moment in a development workflow.

## Quick start

```bash
git clone https://github.com/bnayahu/qiskit-skills
cd qiskit-skills
./install.sh ~/path/to/your/qiskit-clone
```

The script copies the playbook into `<qiskit>/docs/playbook/`, the 27 skills into
`<qiskit>/.claude/skills/`, and `AGENTS.md` into `<qiskit>/AGENTS.md`. It warns
before overwriting anything that already exists. Use `-f` to skip confirmation prompts.

Open your Qiskit clone in Claude Code. The skills are immediately available via the
`Skill` tool — for example, `Skill("qiskit-bug-triage")` to classify a reported bug,
or `Skill("qiskit-good-pr-checklist")` to audit a branch before requesting review.

## What's in the box

### Playbook (`playbook/`)

An 11-file, evidence-cited inventory of the Qiskit repository — conventions distilled
from the codebase, configuration files, and 180+ PRs. Each file distinguishes explicit
rules (codified in CONTRIBUTING.md, MAINTAINING.md, etc.) from inferred conventions
(observed across PRs but not written down), and labels every convention as Mandatory /
Preferred / Historical / Disputed. The playbook is the reference layer; the skills are
the action layer built on top of it.

### Skills (`skills/`)

27 action-oriented playbooks, one per developer intent. Each skill targets a single
recognizable task ("add a gate", "prepare a release note", "audit my PR") and encodes
which checks block merge vs. which trigger discussion. Skills are designed to compose:
`qiskit-bug-triage` routes to domain skills; `qiskit-good-pr-checklist` aggregates
`qiskit-testing` + `qiskit-release-notes` + `qiskit-anti-patterns` into a single
pre-PR gate.

Three skills appear in virtually every development cycle:

| Skill | Issues hit (of 10 analyzed) | What it guards |
|---|---|---|
| `qiskit-pr-preparation` | **10 / 10** | AI/LLM disclosure, `Fixes #N` phrasing, concise summary |
| `qiskit-release-notes` | **9 / 10** | reno YAML on the correct `Changelog:` axis |
| `qiskit-testing` | **9 / 10** | Regression test that fails before the fix |

These address the two most-cited review-iteration hotspots: missing reno entries and
missing regression tests.

### `deploy/AGENTS.md`

The agent-facing entry point for the Qiskit repo — installed by `install.sh` as
`AGENTS.md` in the target clone. A single file a developer (human or AI) reads first.
It points to the playbook table, the skills index, the build and test quick-reference,
the pre-PR checklist, and the patterns that get PRs closed.

## Skills reference

27 skills across 10 lifecycle phases. Invoke any skill in Claude Code with the `Skill`
tool: `Skill("qiskit-<name>")`.

| Phase | Skill | What it does |
|---|---|---|
| **Onboarding** | `qiskit-architecture-map` | Locate where a feature lives; surface the one-way crate dependency direction |
| | `qiskit-py-rust-bridge` | `sys.modules` registration, PyO3 init rules, Rust→Python exception bridge |
| **Authoring** | `qiskit-coding-conventions` | black/ruff/clippy, modern union syntax, Google docstrings, import order |
| | `qiskit-add-standard-gate` | Scaffold a new standard gate end-to-end (Python + Rust enum + test + reno) |
| | `qiskit-add-transpiler-pass` | Scaffold an analysis/transformation pass with control-flow recursion |
| | `qiskit-error-handling` | Choose the right exception class; Rust→Python `import_exception!` bridge |
| | `qiskit-optional-dependencies` | Wrap non-required deps via `qiskit.utils.optionals`; block module-top imports |
| | `qiskit-rust-performance-idioms` | Hot-path Rust idioms: `saturating_sub`, fixed-size arrays, `try_inverse_mut` |
| | `qiskit-deprecation` | `@deprecate_func`/`@deprecate_arg`, two-version window, paired tests |
| **Building & testing** | `qiskit-build-system` | PEP 517, profile flags, MSRV sync across four files, Makefile targets |
| | `qiskit-testing` | Pick the right runner; regression test gate; deprecation test requirements |
| | `qiskit-qpy-compatibility` | QPY format-version bumps, fixture corpus, gzip/Rust-bytes traps |
| **Performance** | `qiskit-performance-benchmarks` | ASV before/after table for heuristic/hot-path changes |
| | `qiskit-determinism-audit` | Audit new parallelism for ordering non-determinism (Mandatory) |
| **Deps & API** | `qiskit-dependency-policy` | Justify new deps; pinning rules; `constraints.txt` policy |
| | `qiskit-api-evolution` | Two-version window; public vs. private surface; removal timeline |
| **Pre-PR** | `qiskit-pr-preparation` | PR body, `Fixes #N`, AI/LLM disclosure, `Changelog:` label |
| | `qiskit-good-pr-checklist` | Pre-`gh pr create` audit aggregating testing + reno + anti-patterns |
| **Code review** | `qiskit-code-review` | Maintainer-style diff review with recurring-nit knowledge |
| **CI/CD & release** | `qiskit-ci-workflows` | Map CI status checks to workflow files; debug a red build |
| | `qiskit-release-notes` | `reno new`, right section axis, `Changelog:` label |
| | `qiskit-release-ceremony` | 6-step release cut: milestone, version bump in 4 files, GPG tag |
| **Backports** | `qiskit-backport-process` | `stable backport potential` label; Mergify rule; no duplicate reno |
| **Debugging & security** | `qiskit-bug-triage` | Classify a bug into a recurring category; pull prior-art PRs |
| | `qiskit-debugging` | Logging idioms, miri, UBSan; never `print`/`println!` |
| | `qiskit-security-review` | C API / FFI / `unsafe` checklist; every `unsafe` block needs a justification |
| | `qiskit-anti-patterns` | Patterns maintainers actively close PRs over (9 closures mapped in analysis window) |

## Playbook reference

| # | File | Topic |
|---|---|---|
| 1 | `playbook/01-architecture.md` | Subsystem boundaries, Py↔Rust FFI, crate dependency direction |
| 2 | `playbook/02-build-and-test.md` | Build system, test runners, environment knobs |
| 3 | `playbook/03-coding-conventions.md` | Lint, format, docstrings, imports |
| 4 | `playbook/04-dependency-management.md` | Python + Rust deps, lockfile policy, version pinning |
| 5 | `playbook/05-cicd-workflows.md` | GitHub Actions, Mergify, CODEOWNERS, qiskit-bot |
| 6 | `playbook/06-release-engineering.md` | Release ceremony, branch model, deprecation policy, reno |
| 7 | `playbook/07-implementation-patterns.md` | Gates, transpiler passes, exceptions, type-hint style |
| 8 | `playbook/08-bug-categories.md` | Recurring bug categories with PR/commit citations |
| 9 | `playbook/09-reviewer-expectations.md` | What reviewers consistently ask for |
| 10 | `playbook/10-maintainer-preferences.md` | Maintainer roster, anti-LLM-spam policy |
| 11 | `playbook/11-implicit-conventions.md` | Cross-cutting implicit conventions, Mandatory/Preferred/Historical/Disputed tiers |

## How this was built

The playbook and skills were produced in a structured analysis process using Claude Code
against the Qiskit git history and codebase — no manual convention-documenting by
maintainers. The process started with a structured codebase inventory (130+ merged PRs,
16 Rust crates, 18 Python packages, all 20 CI workflow files), extracted implicit
conventions with mandatory/preferred/historical/disputed tier labels, designed 27 skills
grounded in specific PR citations, and implemented them end-to-end.

The full walkthrough — including the verbatim prompts, what each produced, and a
case study where three terse prompts fixed a multi-bug Rust regression from issue to
committed branch — is in
[`docs/qiskit-skills-walkthrough.md`](docs/qiskit-skills-walkthrough.md).
