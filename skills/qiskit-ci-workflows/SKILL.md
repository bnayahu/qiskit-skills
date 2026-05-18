---
name: qiskit-ci-workflows
description: Map Qiskit CI status checks to workflows — `branch-protection.yml` finalize job gates merge on `docs`, `lint`, six Python-matrix unit jobs, `test-rust`, `test-c × 4`, `test-images`, `miri`, `qpy`, `neko`. Use whenever the user is debugging a red CI run, asks "why is X failing", "which workflow runs Y", or "what do I need green to merge".
---

# Qiskit CI workflows

`.github/workflows/` contains 20 files. The structure is **modular** — most jobs are reusable `workflow_call` callables, orchestrated by `branch-protection.yml`.

## Required status checks (branch protection)

`branch-protection.yml:40-68` finalize job gates merge on:

- `docs` — Sphinx build.
- `lint` — rustfmt, cargo fmt, slots check, ruff/black, Cargo.lock currency.
- Python unit tests on Linux / macOS / Windows × {oldest, newest} Python = **6 jobs**.
- `test-rust` — `cargo test` with Python interpreter for PyO3.
- `test-c × 4` — C-API tests on all four platforms.
- `test-images` — mpl visual regression.
- `miri` — UB detection on Rust unsafe paths.
- `qpy` — QPY backward-compat.
- `neko` — external integration test runner.

Python matrix: oldest = 3.10, newest = 3.14 (`branch-protection.yml:30-31`).

## Workflow inventory

| File | Trigger | Role |
|---|---|---|
| `branch-protection.yml` | `pull_request` (main, stable/*), `merge_group` | Master gate |
| `test-linux.yml` | `workflow_call` | Linux unit tests; Python matrix, x86_64 + arm64 |
| `test-mac.yml` | `workflow_call` | macOS-15 unit tests |
| `test-windows.yml` | `workflow_call` | windows-latest unit tests |
| `rust-tests.yml` | `workflow_call` | `cargo test` with Python for PyO3 |
| `ctests.yml` | `workflow_call` | C-API tests on all 4 platforms |
| `lint.yml` | `workflow_call` | rustfmt, cargo fmt, slots check, ruff/black, Cargo.lock |
| `docs.yml` | `workflow_call` | Sphinx build |
| `qpy.yml` | `workflow_call` | QPY backward-compat |
| `image-tests.yml` | `workflow_call` | mpl visual regression |
| `miri.yml` | `workflow_call` | Miri UB detection on Rust unsafe paths |
| `coverage.yml` | `push` (all branches), `pull_request` (main) | LCOV via `make coverage` |
| `wheels.yml` | `push` on tags | PyPI release builds |
| `wheels-build.yml` | `workflow_call` | Tier-1 / Tier-2 wheel build matrix |
| `wheels-pr.yml` | `pull_request` (labeled, sync, opened) | On-demand wheel builds |
| `on-nightly.yml` | cron `20 6 * * *` | Full-matrix nightly tests |
| `slow.yml` | cron `42 3 * * *` | Slow-marked tests |
| `randomized_tests.yml` | cron `42 3 * * *` | Hypothesis randomized tests |
| `backport.yml` | `pull_request opened` on `stable/*` | Sync labels/milestones into Mergify backport PRs |
| `docs_deploy.yml` | `push` (main, tags), `workflow_dispatch` | Publish docs |

## Debugging red CI

| Failing check | Likely cause | Where to look |
|---|---|---|
| `lint` | black/ruff/clippy/Cargo.lock | Run `tox -elint` locally — see [[qiskit-coding-conventions]] |
| `docs` | Sphinx build, broken cross-reference, D417 | `tox -edocs`; check `:class:`/`:func:` roles |
| `test-py*` | Python unit test failure | Run the failing test locally with `tox -epy<version>` |
| `test-rust` | Rust unit test failure or pyo3 mismatch | `cargo test --workspace`; check pyo3 version pin |
| `miri` | Unsafe-code UB | Identify the unsafe block; FFI tests are excluded so check non-FFI unsafe paths. #15049 is the canonical example |
| `qpy` | QPY round-trip / format-version mismatch | See [[qiskit-qpy-compatibility]] |
| `test-images` | mpl snapshot mismatch | Regenerate baselines locally and **visually inspect** |
| `test-c × 4` | C-API test failure | `make ctest` locally |
| `neko` | External integration | Read the workflow log; usually a downstream regression |
| `coverage` | Coverage threshold drop | Add tests for the new code |

## Mergify

`.mergify.yml` defines a **single rule**: when a merged PR is labeled `stable backport potential`, Mergify opens a backport PR to the current stable branch (`stable/2.4` at snapshot time).

```yaml
pull_request_rules:
  - name: backport
    conditions:
      - label=stable backport potential
    actions:
      backport:
        branches:
          - stable/2.4
```

`backport.yml` then syncs labels/milestones into the Mergify-generated PR. Examples in the wild: #16155, #15431, #15728, #15884. See [[qiskit-backport-process]].

## CODEOWNERS

`.github/CODEOWNERS`:

- Global default: `* @Qiskit/terra-core`.
- `primitives/` co-owned with `@Qiskit/qiskit-primitives`.
- `/releasenotes/notes` is **deliberately codeowner-free** (line 29) so any maintainer with write access can sign off on a reno-only PR. This reduces release-time friction.

## qiskit-bot (`qiskit_bot.yaml`)

Two automations:

### 1. Notification routing

Pings module experts on PRs:

| Path | Pinged |
|---|---|
| default | `@Qiskit/terra-core` |
| `qpy` | `@mtreinish` |
| `circuit/library` | `@Cryoris`, `@ajavadia` |
| `primitives` | `@t-imamichi`, `@ajavadia`, `@levbishop` |

Backticks around handles suppress GitHub email notifications while preserving routing context.

### 2. Changelog category mapping

Maps `Changelog: <X>` labels to release-note sections in the GitHub Release: Added, Fixed, Changed, Deprecated, Removed, Build System, **Performance**, None. The `Performance` category was added in #16065.

## Wheels & release pipeline

- `wheels.yml` triggers on tag push (`push: tags: ['*']`).
- Two-stage deployment via `wheels-build.yml`:
  1. **Tier 1 wheels** (Linux/macOS/Windows × all Python versions): ~1.5–2 hours.
  2. **Approval gate.** Someone *other than* the release manager confirms tag/commit/version (`MAINTAINING.md:420-441`).
  3. **Tier 2 wheels.**
  4. Final approval, push to PyPI.
- Environment: GitHub Actions `environment: release` with `permissions: id-token: write` for **PyPI trusted publishing** (no secrets).
- `wheels-pr.yml` lets reviewers request a PR-time wheel build by adding a label.

## Recent CI / infra PRs

- **#16128** "Enable clippy on rust tests too" (`--all-targets`).
- **#15839** Cargo.lock currency check in lint.
- **#15924** simplified PR template (added AI/LLM disclosure boxes).
- **#15721** promoted "missing argument in docstring" to CI-blocking.
- **#16093** "Use Bob to spell check the release notes" — *closed without merge*; an example of a workflow proposal that didn't pass.

## Heuristics

- **Read the workflow log first.** GitHub Actions surfaces the failing step; don't guess from the summary.
- **Reproduce locally.** Most CI failures reproduce with `tox -e<env>` — the env name often matches the workflow.
- **For miri failures**, trace the unsafe block. The FFI-tests-excluded carve-out means a miri error is in pure Rust code, not in the C API.
- **For flaky test-images**, a snapshot mismatch is rarely flaky — usually a real difference. Inspect the diff image artifact.

## Related skills

- [[qiskit-coding-conventions]] — fix lint failures.
- [[qiskit-testing]] — reproduce test failures locally.
- [[qiskit-qpy-compatibility]] — fix qpy workflow failures.
- [[qiskit-security-review]] — miri / FFI / unsafe.
- [[qiskit-backport-process]] — Mergify mechanics.
- [[qiskit-release-ceremony]] — wheels deployment.
