---
name: qiskit-pr-preparation
description: Draft a Qiskit pull request body that meets maintainer expectations — concise human-written summary, exact `Fixes #N` phrasing, AI/LLM disclosure box, the right `Changelog:` label, and a backport recommendation. Use whenever the user is about to open a Qiskit PR, is writing or revising a PR description, or asks for help phrasing a PR for the Qiskit/qiskit repository. Also use proactively before any `gh pr create` against Qiskit, since LLM-bloated descriptions are the single largest closure category in this repo.
---

# Qiskit PR preparation

Goal: produce a PR body the maintainers (jakelishman, mtreinish, Cryoris, alexanderivrii) will accept on the first read. The single biggest reason Qiskit PRs are closed without merge is **LLM-spam volume**: 9 of 16 closed-unmerged PRs in the last 6 months were closed by jakelishman with the same templated message about unsupervised LLM use. Keep the body short, human, and disclosed.

## What the body must contain

Use the structure of `.github/PULL_REQUEST_TEMPLATE.md` — it was deliberately tightened in #15924 to discourage bloat. The required pieces:

1. **Summary** — 1–4 sentences. State the problem and the fix. No "Validation" / "Testing" subsection (CI's job; alexanderivrii in #16116: *"the 'validation' subsection feels unnecessary given that CI already covers this"*).
2. **`Fixes #N`** — exact phrasing, on its own line. CONTRIBUTING.md notes GitHub only auto-closes with this exact form. If multiple issues, use `Fixes #N`, `Fixes #M` (one per issue, not `Fixes #N, #M`).
3. **AI/LLM disclosure box** — from the PR template. State the tool name and version (e.g. "Claude Sonnet 4.5 via Claude Code") OR check the "no AI tools used" box. Missing disclosure → templated request from jakelishman to re-instate (see #15994). Volume + missing disclosure → blacklist.
4. **Changelog label suggestion** — note the label you're going to apply (qiskit-bot reads it). Pick exactly one from §6.6:
   - `Changelog: Added` — new public API.
   - `Changelog: Fixed` — bug fix.
   - `Changelog: Changed` — semantics changed without break.
   - `Changelog: Deprecated` / `Changelog: Removed`.
   - `Changelog: Performance` — speed/memory improvement (added in #16065).
   - `Changelog: Build` — affects downstream packagers.
   - `Changelog: None` — pure refactor / CI / dep bump / typo (no reno required).
5. **Backport recommendation** — if this is a user-visible bug fix that applies cleanly to the active stable branch, suggest applying the `stable backport potential` label so Mergify opens the backport PR (.mergify.yml). Features and refactors are not backported.

## What to leave out

- **No bullet-point summary of every file changed.** The diff already shows that.
- **No "Root cause analysis" section.** One clear sentence about what was wrong is enough. jakelishman closed #16039/#16060/#16062/#16079/#16125/#16127 partly over this.
- **No CI/Validation subsection.** CI is the gate, not the description.
- **No emojis or marketing tone.** This is a maintenance project, not a product launch.
- **No "Co-authored by Claude"** unless the user explicitly asks; the AI disclosure box is the canonical place.

## Heuristics for the summary

- **Bug fix:** "Before this change, X. The root cause was Y in module Z. This fixes Y so X behaves correctly. Adds a regression test." (1–3 sentences total.)
- **Feature:** "Adds <feature>. Implemented as <one-line shape>. New public API: `<symbol>`."
- **Refactor:** State the win in one sentence (e.g. "removes the artificial dependency between A and B" — see #16132).
- **Performance:** State the before/after numbers from the benchmark. See [[qiskit-performance-benchmarks]].

## Example PR body

```
Fixes a bug where `BasisTranslator` did not recurse into nested `ControlFlowOp.blocks`,
so basis translation was skipped inside `IfElseOp`/`WhileLoopOp` bodies. Now the pass
descends through every block and translates uniformly. Adds a regression test using
nested `IfElseOp`.

Fixes #15870

### AI / LLM disclosure
- [x] No AI tools were used to author this PR.
- [ ] AI tools were used. Tool + version: ___

(Suggested label: `Changelog: Fixed`. Suggesting `stable backport potential` since
the bug is present on `stable/2.4`.)
```

## Hand-off checklist

Before suggesting `gh pr create`, walk the [[qiskit-good-pr-checklist]] — regression test, reno entry, control-flow test if a transpiler pass is touched, benchmarks if a heuristic moved. The PR body is half the package; the other half is what's in the diff.

## Related skills

- [[qiskit-good-pr-checklist]] — full pre-PR audit.
- [[qiskit-release-notes]] — generate the reno YAML if the label isn't `None`.
- [[qiskit-anti-patterns]] — the closure precedents this skill protects against.
- [[qiskit-backport-process]] — when to apply `stable backport potential`.
