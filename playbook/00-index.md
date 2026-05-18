# Qiskit Repository Playbook

A structured inventory of the Qiskit repository (https://github.com/Qiskit/qiskit), produced from
direct inspection of the working tree, configuration files, `git log`, and analysis of more than
180 merged/closed PRs (Nov 2025 – May 2026 window) via `gh`.

Each section cites concrete evidence (file paths with line ranges, PR numbers, commit hashes) and
distinguishes **explicit rules** (codified in repo files) from **inferred conventions**
(synthesized from observed patterns). Confidence is rated **High / Medium / Low**.

This is a description, not a recommendation set.

## Documents

| # | File | Topic |
|---|------|-------|
| 1 | [01-architecture.md](01-architecture.md) | Architecture & subsystem boundaries (Rust crates + Python packages, Py↔Rust FFI) |
| 2 | [02-build-and-test.md](02-build-and-test.md) | Build system, test system, environment knobs |
| 3 | [03-coding-conventions.md](03-coding-conventions.md) | Linting, formatting, style, docstrings, imports |
| 4 | [04-dependency-management.md](04-dependency-management.md) | Python + Rust dependency layout, lockfile policy, version pinning |
| 5 | [05-cicd-workflows.md](05-cicd-workflows.md) | GitHub Actions workflows, Mergify, CODEOWNERS, qiskit-bot |
| 6 | [06-release-engineering.md](06-release-engineering.md) | Release ceremony, branch model, deprecation policy, reno notes |
| 7 | [07-implementation-patterns.md](07-implementation-patterns.md) | Gates, transpiler passes, exceptions, deprecation decorators, type-hint style |
| 8 | [08-bug-categories.md](08-bug-categories.md) | Recurring bug categories with PR/commit citations |
| 9 | [09-reviewer-expectations.md](09-reviewer-expectations.md) | What reviewers consistently ask for, with PR evidence |
| 10 | [10-maintainer-preferences.md](10-maintainer-preferences.md) | Maintainer roster, accepted/rejected/reverted patterns, anti-LLM-spam policy |
| 11 | [11-implicit-conventions.md](11-implicit-conventions.md) | Cross-cutting implicit engineering conventions (naming, layering, errors, logging, testing, API discipline, perf, concurrency, abstraction, deps, review) with mandatory/preferred/historical/disputed tiers |

## Sample size

- **Crates inspected:** 16 (every member of the Cargo workspace)
- **Python packages inspected:** 18 top-level (`qiskit/circuit`, `qiskit/transpiler`, etc.)
- **Workflow files inspected:** all 20 files in `.github/workflows/`
- **PRs analyzed:** ≥130 merged + 16 closed-without-merge from a six-month window;
  ≥80 distinct PR numbers cited inline across the playbook (full citation list at end of
  documents 8–10).
- **Commits scanned:** `git log -200` plus targeted `git log --grep` queries.

## Conventions used in this playbook

- Evidence is cited as `path/to/file.ext:line-range` or as PR/commit numbers (`#16123`,
  `ff181dc84a`).
- A **bold "Explicit"** tag means the rule is codified in CONTRIBUTING.md, MAINTAINING.md,
  DEPRECATION.md, a YAML config, or a PR template.
- A **bold "Inferred"** tag means the convention was observed across multiple PRs/files but is
  not written down in a single canonical location.
