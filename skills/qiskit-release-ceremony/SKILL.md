---
name: qiskit-release-ceremony
description: Drive Qiskit's 6-step release ceremony from `MAINTAINING.md` — audit milestone (feature freeze 2 weeks before RC1); audit `Changelog:` labels with the external `generate_changelog.py`; prepare release notes; open the "Prepare x.y.z release" PR (bump version in **four** locations); on first minor also retarget `.mergify.yml`; tag GPG-signed `x.y.z` (no `v` prefix); push to upstream; enforce wheels-deployment second-approver rule. Use whenever the user is preparing a Qiskit release, asks "how do I cut RC1", or needs to bump the version.
---

# Qiskit release ceremony

Qiskit follows the 6-step ceremony in `MAINTAINING.md:135-510`. This skill mechanizes the easy-to-miss parts (four-file version bump, mergify retarget) and lays out the second-approver rule for wheel deployment.

## Versioning

- **SemVer** since 1.0 (`DEPRECATION.md:1-4`). `MAJOR.MINOR.PATCH`.
- **Yearly major-release cadence**.
- **Removals / breaking changes:** only in major releases.
- **Deprecations:** only in minor releases.
- **Two-version compatibility window** for any deprecation.
- **Patch releases:** bug fixes only, no API changes.

| Channel | Python form | Rust/C form |
|---|---|---|
| stable | `2.4.0` | `2.4.0` |
| RC | `2.4.0rc1` | `2.4.0-rc1` |
| beta | `2.4.0b1` | `2.4.0-beta1` |
| dev | `2.5.0.dev0` | `2.5.0-dev` |

## The four version locations (must stay in sync)

1. `qiskit/VERSION.txt` — Python version.
2. `Cargo.toml` `[workspace.package].version` — Rust workspace version.
3. `crates/bindgen/include/qiskit/version.h` — C header.
4. `docs/release_notes.rst` `:earliest-version:` — Sphinx earliest-version directive.

A "Prepare x.y.z release" PR that misses any of these four ships an inconsistent release. Verify with:

```bash
grep -E "(\"|=|version)\s*[:=]?\s*\"?2\.4\.0" \
    qiskit/VERSION.txt \
    Cargo.toml \
    crates/bindgen/include/qiskit/version.h \
    docs/release_notes.rst
```

## Branch model

- `main` always carries the next dev version (`x.y.0.dev0`).
- `stable/x.y` is created during the first RC of a minor.
- Backport branches: `mergify/bp/stable/x.y/pr-<N>` (auto-created).

Active stable branches at snapshot: `stable/2.4`, `stable/2.3`, `stable/2.2`, `stable/2.1`, `stable/2.0`.

## The 6-step ceremony

### 1. Audit milestone (`MAINTAINING.md:155-167`)

Verify the GitHub milestone's due date. **Feature freeze is 2 weeks before RC1.** Move post-freeze items to the next milestone. If the milestone has no due date, set one.

### 2. Audit `Changelog:*` labels (`MAINTAINING.md:169-194`)

Use the external `generate_changelog.py` script from the `qiskit-bot` repo (not in `Qiskit/qiskit`). Iterate until every PR in the milestone carries exactly one `Changelog: <X>` label. PRs with `Changelog: None` need no further attention; everything else gets a release note.

```bash
# from a checkout of qiskit-bot
python generate_changelog.py --milestone "2.4.0" Qiskit/qiskit
```

### 3. Prepare release notes (`MAINTAINING.md:196-238`)

For **first releases of a minor**: move loose `releasenotes/notes/*.yaml` into `releasenotes/notes/x.y/`.

```bash
mkdir -p releasenotes/notes/2.4
git mv releasenotes/notes/*.yaml releasenotes/notes/2.4/
```

For **patch releases**: sweep loose notes for typos / dead links.

The reno tool assembles them at build time using `releasenotes/config.yaml` (`default_branch: main`, `collapse_pre_releases: true`).

### 4. Open the "Prepare x.y.z release" PR (`MAINTAINING.md:240-310`)

- Bump version in all **four** locations (see above).
- On **first release of a minor** (e.g. cutting `stable/2.5` for the first time), also retarget `.mergify.yml`:

  ```yaml
  pull_request_rules:
    - name: backport
      conditions:
        - label=stable backport potential
      actions:
        backport:
          branches:
            - stable/2.5   # was stable/2.4
  ```

- Apply `Changelog: None` label to the prep PR.
- Title: "Prepare x.y.z release".

### 5. Tag the merge commit (`MAINTAINING.md:312-410`)

Tag is `x.y.z` (**no `v` prefix**), GPG-signed, message `"Qiskit x.y.z"`:

```bash
git tag -s -m "Qiskit 2.4.0" 2.4.0 <merge-commit-sha>
git push upstream 2.4.0
```

The tag push triggers `wheels.yml` and the full release pipeline.

### 6. Post-release (`MAINTAINING.md:444-510`)

- Slack announce (#qiskit channel).
- For follow-up releases on the same minor (e.g. RC2 → RC3), no further action.
- For first GA after the last RC: bump `main` to the next dev version.
- Create the next milestone.
- Update the roadmap wiki.

## Wheels deployment (`MAINTAINING.md:420-441`, **Mandatory**)

The wheels pipeline has a **second-approver gate** between Tier 1 and Tier 2:

1. Tier 1 wheels build (Linux/macOS/Windows × all Pythons): ~1.5–2 hours.
2. **Approval gate.** Someone *other than* the release manager checks tag, commit, version, leaves a comment confirming the SHA. **Required.**
3. Tier 2 wheels.
4. Final approval, push to PyPI.

Don't approve your own deploy. The rule is operational: the release-manager role and the deploy-approver role must be different humans.

## Release-manager role (`MAINTAINING.md:108-127`)

The release manager:

- Tracks milestone completion and chases blockers.
- Coordinates the schedule (RC1, RC2, GA dates).
- Does **not** approve their own wheels deployment (see above).

## Pre-release regex (`releasenotes/config.yaml`)

```yaml
release_tag_re: '^(?P<release>(?:[\d.ab]|rc|pre)+\d*)$'
pre_release_tag_re: '(?P<pre_release>(?:[ab]|rc|pre)+\d*)$'
```

`collapse_pre_releases: true` means RC notes roll up into the final release in published docs.

## Heuristics

- **For RC1 of a new minor**, the four-file version bump and the mergify retarget are the easy-to-miss steps. Use a checklist.
- **GPG-sign the tag.** The release pipeline expects signed tags.
- **Don't push the tag until the prep PR is merged.** The tag must live on the actual release commit.
- **Pre-3.0 C API is explicitly unstable** (`DEPRECATION.md:258-304`). Don't treat C-API changes as semver-protected.
- **Patch releases ship from the stable branch**, not from main.

## Related skills

- [[qiskit-release-notes]] — assembling the YAML files reno consumes.
- [[qiskit-backport-process]] — Mergify backports for the patch stream.
- [[qiskit-ci-workflows]] — `wheels.yml` mechanics.
- [[qiskit-api-evolution]] — what's allowed in major vs minor vs patch.
