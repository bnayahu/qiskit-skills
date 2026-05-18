# 5. CI/CD Workflows

## 5.1 Workflow inventory

`.github/workflows/` contains 20 files. The structure is **modular** — most jobs are reusable
`workflow_call` callables, orchestrated by `branch-protection.yml`.

| File | Trigger | Role |
|---|---|---|
| `branch-protection.yml` | `pull_request` (main, stable/*), `merge_group` | Master gate. Calls every reusable workflow and aggregates required-status-check results in a `finalize` job. |
| `test-linux.yml` | `workflow_call` | Linux unit tests; matrix across Python versions, x86_64 + arm64 |
| `test-mac.yml` | `workflow_call` | macOS-15 unit tests |
| `test-windows.yml` | `workflow_call` | windows-latest unit tests |
| `rust-tests.yml` | `workflow_call` | `cargo test` with Python interpreter for PyO3 |
| `ctests.yml` | `workflow_call` | C-API tests on all 4 platforms |
| `lint.yml` | `workflow_call` | rustfmt, cargo fmt, slots check, ruff/black, Cargo.lock currency |
| `docs.yml` | `workflow_call` | Sphinx build |
| `qpy.yml` | `workflow_call` | QPY backward-compat |
| `image-tests.yml` | `workflow_call` | mpl visual regression |
| `miri.yml` | `workflow_call` | Miri UB detection on Rust unsafe paths |
| `coverage.yml` | `push` (all branches), `pull_request` (main) | LCOV via `make coverage` |
| `wheels.yml` | `push` on tags | PyPI release builds |
| `wheels-build.yml` | `workflow_call` | Tier-1 / Tier-2 wheel build matrix |
| `wheels-pr.yml` | `pull_request` (labeled, sync, opened) | On-demand wheel builds for PRs |
| `on-nightly.yml` | cron `20 6 * * *` | Full-matrix nightly tests |
| `slow.yml` | cron `42 3 * * *` | Slow-marked tests |
| `randomized_tests.yml` | cron `42 3 * * *` | Hypothesis-driven randomized tests |
| `backport.yml` | `pull_request opened` on `stable/*` | Sync labels/milestones into Mergify-generated backport PRs |
| `docs_deploy.yml` | `push` (main, tags), `workflow_dispatch` | Publish docs |

**Confidence:** High. **Explicit.**

## 5.2 Required status checks (branch protection)

`branch-protection.yml` finalize job (`branch-protection.yml:40-68`) gates merge on:

- `docs`
- `lint`
- Python unit tests on Linux / macOS / Windows × {oldest, newest} Python = 6 jobs
- `test-rust`
- `test-c` × 4 platforms
- `test-images`
- `miri`
- `qpy`
- `neko` (external integration test runner)

**Python matrix:** oldest = 3.10, newest = 3.14 (`branch-protection.yml:30-31`).

**Confidence:** High. **Explicit.**

## 5.3 CODEOWNERS

`.github/CODEOWNERS`:

- Global default: `* @Qiskit/terra-core` (lines 22-23).
- `primitives/` co-owned with `@Qiskit/qiskit-primitives`.
- `/releasenotes/notes` is **deliberately codeowner-free** (line 29) so any maintainer with
  write access can approve a reno-only PR. This reduces release-time friction.

**Confidence:** High. **Explicit.**

## 5.4 Mergify

`.mergify.yml` defines a **single rule**: when a merged PR is labeled
`stable backport potential`, Mergify opens a backport PR to the current stable branch
(`stable/2.4` at the time of snapshot).

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

`backport.yml` then syncs labels/milestones into the Mergify-generated PR.

**Examples in the wild:** `#16155` (auto-backport of `#16154`), `#15431` (of `#15429`),
`#15728` (of `#15725`), `#15884` (of `#15875`).

**Confidence:** High. **Explicit.**

## 5.5 qiskit-bot

`qiskit_bot.yaml` (root of repo) drives two automations:

### Notification routing

The bot pings module experts on PRs:

| Path | Pinged |
|---|---|
| default | `@Qiskit/terra-core` |
| `qpy` | `@mtreinish` |
| `circuit/library` | `@Cryoris`, `@ajavadia` |
| `primitives` | `@t-imamichi`, `@ajavadia`, `@levbishop` |

Backticks around handles suppress GitHub email notifications while preserving routing context.

### Changelog category mapping

Maps `Changelog: <X>` labels to release-note sections in the GitHub Release (lines 24-32):

- Added, Fixed, Changed, Deprecated, Removed, Build System, **Performance**, None.

The `Performance` category was added in **#16065** (driven by **#16014**).

**Confidence:** High. **Explicit.**

## 5.6 Wheels & release pipeline

- `wheels.yml` triggers on tag push (`push: tags: ['*']`).
- Two-stage deployment via `wheels-build.yml`:
  1. **Tier 1 wheels** (Linux/macOS/Windows × all Python versions): ~1.5–2 hours.
  2. **Approval gate.** Someone *other than* the release manager checks tag/commit/version,
     leaves a comment confirming SHA. Required by `MAINTAINING.md:420-441`.
  3. **Tier 2 wheels.**
  4. Final approval, push to PyPI.
- Environment: GitHub Actions `environment: release` with
  `permissions: id-token: write` for PyPI **trusted publishing** (no secrets).
- `wheels-pr.yml` lets reviewers request a PR-time wheel build by adding a label.

**Confidence:** High. **Explicit.**

## 5.7 Recent CI/infra PRs (illustrative)

- **#16128** "Enable clippy on rust tests too" — clippy now runs `--all-targets`.
- **#15839** added Cargo.lock currency check to lint.
- **#15924** simplified PR template (added AI/LLM disclosure boxes).
- **#15721** promoted "missing argument in docstring" to CI-blocking.
- **#16093** "Use Bob to spell check the release notes" — *closed without merge*; an example
  of a workflow proposal that didn't pass.

**Confidence:** High.
