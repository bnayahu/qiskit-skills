---
name: qiskit-backport-process
description: Apply or remove the Qiskit `stable backport potential` label correctly, understand which Mergify rule fires, and sync labels/milestones via `backport.yml`. Knows that backports do *not* duplicate reno entries (the original carries it). Use whenever the user asks "should I backport this fix", "how do backports work", or is reviewing a Mergify-generated backport PR.
---

# Qiskit backport process

Qiskit uses Mergify to automate backports to the active stable branch. The trigger is a single label: `stable backport potential`.

## The Mergify rule (`.mergify.yml`)

```yaml
pull_request_rules:
  - name: backport
    conditions:
      - label=stable backport potential
    actions:
      backport:
        branches:
          - stable/2.4    # current at snapshot
```

Only **one** stable branch is targeted at a time — the most recent. When a new minor is cut, `.mergify.yml` is retargeted to the new branch as part of the release ceremony (see [[qiskit-release-ceremony]] step 4).

## When it fires

- A PR is merged to `main` with the `stable backport potential` label applied.
- Mergify creates a new PR titled `<original title> (backport #ORIG)` against `stable/x.y`.
- `backport.yml` syncs labels and milestones from the original PR into the Mergify-generated one.

Examples in the wild: #16155 (auto-backport of #16154), #15431 (of #15429), #15728 (of #15725), #15884 (of #15875).

## What gets backported

**Yes** (apply the label):

- User-visible bug fixes that still apply to the stable branch.
- Critical correctness regressions (`Changelog: Fixed`).
- Security fixes.

**No** (don't apply the label):

- Features (`Changelog: Added`) — even if they apply cleanly.
- Refactors (`Changelog: None`).
- Performance improvements (`Changelog: Performance`) — discretionary; usually no.
- Dependency bumps.
- Documentation typos.

The principle: **patch releases are bug-fix-only**. New behavior, even when "obviously safe," doesn't go into a stable branch because it would break the patch-release contract.

## What's *in* the backport PR

- The cherry-picked commits.
- The same `Changelog:` label as the original.
- The same milestone (synced by `backport.yml`).
- **No release-note YAML** — backports do **not** duplicate reno entries (§11.11.4). The original PR carries it; reno will pick it up via the version range.

If Mergify runs into a conflict, the backport PR opens in a draft state with conflict markers. Resolve them by hand, then push to the backport branch.

## Deciding whether to backport

Walk this checklist:

1. **Is this a user-visible bug fix?** If yes, continue. If no, don't backport.
2. **Does the bug exist on the stable branch?** Check with `git log stable/x.y -- <files>` or by reading the stable code. If the bug isn't on stable, no backport needed.
3. **Does the fix apply cleanly?** Run `git cherry-pick --no-commit <merge-sha>` against a fresh checkout of stable. If it conflicts deeply (different code shape), the backport may not be worth the risk; consider a stable-branch-specific fix instead.
4. **Is it user-impacting enough to ship in a patch?** Critical: yes. Edge case: usually yes. Cosmetic: probably not.

## Manual cherry-picks

When Mergify can't auto-backport (conflicts) or the label was applied late, do it manually:

```bash
git checkout stable/2.4
git pull upstream stable/2.4
git checkout -b backport/<topic>-stable-2.4
git cherry-pick -x <merge-sha>   # -x adds "(cherry picked from commit ...)"
# resolve any conflicts
git push origin backport/<topic>-stable-2.4
gh pr create --base stable/2.4 \
    --title "<original title> (backport #ORIG)" \
    --body "Backports #ORIG to stable/2.4."
```

Apply the same `Changelog:` label and milestone the original carried.

## Heuristics

- **Apply the label at merge time**, not after. Mergify watches the merge event; late-labeling means a manual cherry-pick.
- **Don't add a reno entry to the backport PR.** Reno picks up the original entry via version ranges.
- **Conflict resolution should preserve the fix's *intent*, not its diff.** If stable's code shape is different, write a fix that achieves the same effect rather than mechanically reproducing the diff.
- **When in doubt, ask in the PR.** Maintainers will tell you whether to backport — the label is a recommendation, not an authority.

## Related skills

- [[qiskit-pr-preparation]] — when to suggest the label.
- [[qiskit-good-pr-checklist]] — confirms the label was considered.
- [[qiskit-release-ceremony]] — the `.mergify.yml` retarget that happens at first RC.
- [[qiskit-ci-workflows]] — `backport.yml` mechanics.
