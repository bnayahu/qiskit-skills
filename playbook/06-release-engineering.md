# 6. Release Engineering

All evidence in this section is **explicit** unless noted, anchored in `MAINTAINING.md`,
`DEPRECATION.md`, `releasenotes/config.yaml`, and observed git tag history.

## 6.1 Versioning policy

- **SemVer** since 1.0 (`DEPRECATION.md:1-4`). `MAJOR.MINOR.PATCH`.
- **Yearly major-release cadence** (`MAINTAINING.md:7-56`).
- **Removals / breaking changes:** only in major releases.
- **Deprecations:** only in minor releases (`DEPRECATION.md:29`).
- **Two-version compatibility window:** "At least two consecutive minor releases must have a
  valid code path with zero warnings" (`DEPRECATION.md:32`).
- **Patch releases:** bug fixes only; no API changes.

| Channel | Python form | Rust/C form |
|---|---|---|
| stable | `2.4.0` | `2.4.0` |
| RC | `2.4.0rc1` | `2.4.0-rc1` |
| beta | `2.4.0b1` | `2.4.0-beta1` |
| dev | `2.5.0.dev0` | `2.5.0-dev` |

Version is held in **four** places that must stay in sync:

1. `qiskit/VERSION.txt`
2. `Cargo.toml` `[workspace.package].version`
3. `crates/bindgen/include/qiskit/version.h`
4. `docs/release_notes.rst` `:earliest-version:`

**Confidence:** High.

## 6.2 Branch model

- `main` always carries the next dev version (`x.y.0.dev0`).
- `stable/x.y` is created during the first RC of a minor.
- Backport branches: `mergify/bp/stable/x.y/pr-<N>` (auto-created).

Active stable branches at snapshot time: `stable/2.4`, `stable/2.3`, `stable/2.2`,
`stable/2.1`, `stable/2.0`. Plus historical `stable/0.x` … `stable/1.4`.

**Confidence:** High.

## 6.3 Release ceremony (6 steps, `MAINTAINING.md:135-510`)

1. **Audit milestone** (lines 155-167). Verify due date; feature freeze 2 weeks before RC1.
2. **Audit `Changelog:*` labels** (lines 169-194). Use external `generate_changelog.py` from
   `qiskit-bot` repo. Iterate until every PR carries a label.
3. **Prepare release notes** (lines 196-238). For first releases, move loose `releasenotes/notes/`
   into `releasenotes/notes/x.y/`. For patch releases, sweep loose notes for typos / dead links.
4. **"Prepare x.y.z release" PR** (lines 240-310). Bump version in all four locations; on first
   release also retarget `.mergify.yml` to the new stable branch. Label `Changelog: None`.
5. **Tag the merge commit** (lines 312-410). Tag is `x.y.z` (no `v` prefix), GPG-signed,
   message `"Qiskit x.y.z"`. Push to `upstream` triggers the full release pipeline.
6. **Post-release** (lines 444-510). Slack announce. For follow-up releases, bump `main` to
   the next dev version. Create the next milestone. Update roadmap wiki.

The **release manager role** (lines 108-127) tracks milestone completion and coordinates
blockers; a separate person (not the release manager) approves the wheels deployment gate.

**Confidence:** High.

## 6.4 Deprecation policy (DEPRECATION.md)

Strict three-phase timeline:

1. **Alternative path must exist.** Before deprecating, ship at least one minor with both old
   and new paths available.
2. **Visibility period.** After issuing `DeprecationWarning`, wait at least one minor before
   removal.
3. **Minimum 3-month removal timeline** from the deprecation warning.

Removals happen in major releases only.

### Decorator API

`qiskit/utils/deprecation.py`:

- `@deprecate_func(since="x.y", additional_msg=…, pending=False, removal_timeline=…)`
- `@deprecate_arg("arg", new_alias="new", since="x.y", predicate=…)`
- `pending=True` issues `PendingDeprecationWarning` (lower visibility, pre-public stage).
- Decorators auto-insert `.. deprecated:: x.y` Sphinx directives into docstrings
  (`utils/deprecation.py:311-383`).

### Public-API definition (DEPRECATION.md:40-56)

The public API is what is **documented in the public API docs**, not what is reachable via
imports. Private import paths (e.g. `qiskit.circuit.measure` even though `Measure` exists
there) are **not** part of the API contract.

### C API

Pre-3.0, the C API is explicitly unstable. Deprecations are best-effort, marked with
`\qk_deprecated{version|reason}` Doxygen and `#[deprecated]` Rust attributes propagated to C
headers via `cbindgen` (DEPRECATION.md:258-304).

## 6.5 Experimental features

`qiskit/exceptions.py:65-72` defines `ExperimentalWarning` (subclass of `QiskitWarning`).
Experimental features may break at any minor release without semver protection
(`DEPRECATION.md:60`). Example: `qiskit.qasm3` on import.

Tests may suppress with `warnings.filterwarnings("ignore", category=ExperimentalWarning)`.

**Confidence:** High.

## 6.6 Release notes (reno)

- **Tool:** [reno](https://docs.openstack.org/reno/) — `reno>=4.1.0` in lint group.
- **Config:** `releasenotes/config.yaml`.
  - `default_branch: main`.
  - `collapse_pre_releases: true` (RCs roll into the final release in published docs).
  - Pre-release regex: `(?P<pre_release>(?:[ab]|rc|pre)+\d*)$`.

### Sections (≈50 categories, lines 8-50 of config.yaml)

Organized by component × change-type, e.g.:

- `features`, `features_circuits`, `features_primitives`, `features_qasm`, `features_qpy`,
  `features_quantum_info`, `features_synthesis`, `features_transpiler`,
  `features_visualization`, `features_misc`, `features_c`, `features_providers`.
- `upgrade*`, `deprecations*`, `fixes`, `performance`, `build`, `issues`, `critical`,
  `security`, `other`.

### File naming and location

- `releasenotes/notes/<slug>-<deterministic-hash>.yaml` (example:
  `mimalloc-403d3300aa698fae.yaml`, `use-foldhash-b63e18338950a9c8.yaml`,
  `msrv-187-fe3d9818f5c4103d.yaml`).
- Per-minor folder: `releasenotes/notes/x.y/` is created during first RC; loose notes are moved
  there.
- `/releasenotes/notes` is intentionally codeowner-free (see `05-cicd-workflows.md`).

### When a reno entry is required

**Required (Explicit, CONTRIBUTING.md:240):**

- Any user-visible behavior change.
- Bug fixes (`Changelog: Fixed`).
- New features / public API additions (`Changelog: Added`).
- Performance changes (`Changelog: Performance` — added in **#16065**).
- Deprecations (`Changelog: Deprecated`) and removals (`Changelog: Removed`).
- Build-system changes that affect downstream packagers (`Changelog: Build`).

**Not required (Inferred):**

- Internal refactors (`Changelog: None`): pure-Rust restructures, test-only changes,
  doc/typo PRs, Dependabot bumps.
- Backport PRs (the original carries the note).

**Confidence:** High.

## 6.7 Tag history (recent)

```
2.4.1  ←  latest stable at snapshot
2.4.0
2.4.0rc3, rc2, rc1
2.3.1
2.3.0
2.3.0rc1
2.2.3, 2.2.2, 2.2.1, 2.2.0, 2.2.0rc1, 2.2.0b1
1.4.5  ←  long-lived 1.x line still patched alongside 2.x
```

`main` carries `2.5.0.dev0` (Python) / `2.5.0-dev` (Rust).

## 6.8 Cross-PR linkage

- **`Fixes #N`** is required to auto-close issues on merge (`CONTRIBUTING.md`: *"you must use
  the exact phrasing in order for GitHub to automatically close the issue"*).
- Backports use Mergify-generated titles like `… (backport #ORIG)` and reference the
  original PR number; reno entries are **not** duplicated in backports.

**Confidence:** High.
