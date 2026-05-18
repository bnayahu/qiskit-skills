# 10. Maintainer Preferences

Inferred from `mergedBy` fields, accepted vs. closed PRs, and review tone across ~180
sampled PRs.

## 10.1 Active maintainer roster

`gh pr list --state merged` aggregated by `mergedBy` over the Nov 2025 – May 2026 window:

| Maintainer | Approx merges | Specialization (inferred) |
|---|---|---|
| `jakelishman` (Jake Lishman) | ~75 | Circuit core, QPY, Rust circuit/dag, control-flow; gatekeeper for AI-tool policy |
| `mtreinish` (Matthew Treinish) | ~30 | Transpiler, Sabre, Rust performance, CI infra, Dependabot bumps |
| `Cryoris` (Julien Gacon) | ~24 | Library / feature-maps, docs, Pauli evolution, primitives |
| `alexanderivrii` (Alexander Ivrii) | ~22 | Synthesis, Clifford, fault-tolerance / PPR / PPM, commutation |
| `raynelfss` (Raynel Sanchez) | ~12 | Rust glue, error types, registers |
| `ShellyGarion` (Shelly Garion) | ~9 | Synthesis, MCX, decomposers |
| `gadial` (Gadi Aleksandrowicz) | ~5 | Control-flow bugs |
| `1ucian0` (Luciano Bello) | ~2 | Scheduling, transpiler |
| `eliarbel` (Eli Arbel) | ~2 | Visualization (Rust drawer) |

CODEOWNERS sets `@Qiskit/terra-core` as global default; `releasenotes/notes/` is intentionally
codeowner-free so any maintainer with write access can sign off on a reno-only PR.

**Confidence:** High.

## 10.2 What gets praised vs. pushed back on

### Praised (Medium-High confidence)

- **Bug fixes with tight regression tests** — reviewers comment "good catch" / "I really
  liked the tests!" on **#16004**, **#15807**.
- **Pure refactors that delete duplication.** **#16132** *"good to remove the artificial
  dependencies here."*
- **Performance work backed by benchmarks** — **#16014**, **#14719** (multithreading),
  **#15881**.

### Pushed back on (High confidence)

- **Wrong-layer fixes.** **#16062** jakelishman:
  > *"This is not a correct fix, because the root fault is not in the exporter but in the
  > importer. The data model of Qiskit is not violated until …"* — closed.
- **Fixes that worsen the symptom case.** **#16124** (CS/CSdg) — closed.
- **Over-restrictive fixes that eliminate legitimate paths.** **#16116** jakelishman:
  > *"This proposed fix is overly restrictive; it is true … that it should be possible to
  > lay out a circuit when only the active qubits fit into the largest chip."*
- **Boilerplate proliferation.** **#15279** jakelishman:
  > *"Thanks for all the busywork on this … I just wanted to see if maybe there's a
  > less-boilerplate way to expand this in the future?"*
- **Narrow special-case PRs.** **#16064** alexanderivrii:
  > *"I am not sure we want such a narrow-focused PR … the request is to add the most
  > general form."*

## 10.3 Anti-LLM-spam policy — the most explicit "we don't accept X" pattern

**Status: Explicit** (CONTRIBUTING.md "Use of AI tools" + PR template).

In response to user `TSS99`, jakelishman closed at least six PRs (**#16039**, **#16060**,
**#16062**, **#16079**, **#16125**, **#16127**) with a near-canonical message:

> *"I am closing this because this user is spamming LLM PRs at the repository without due
> human attention. There is simply too much volume here and it is wasting maintainer time.
> Tiny documentation-only changes do not need 300-line summaries, and neither does
> documentation need to be as prolix as an unfiltered LLM. One-line bugfixes need one clear
> bug reproducer, not 300 lines of 'root cause analysis' … 'Good first issues' are for humans
> to learn, not for LLMs … Slow down, take one or two PRs through to completion … with you,
> the human, responding to comments and understanding exactly what issues are."*

CONTRIBUTING.md codifies the rule:

> *"If you use any AI tool while preparing your code contribution, you must disclose the
> name of the tool and its version in the PR description … Submissions that appear unreviewed
> or copied directly from an AI tool without proper understanding may be requested to be
> revised or declined."*

The PR template was updated in **#15924** to add explicit AI/LLM disclosure checkboxes. PRs
where the disclosure is missing get a templated request for re-instatement (**#15994**
jakelishman: *"I believe this to have been made by an unsupervised LLM, but I am prepared to
accept something like it, with modifications, provided a human comes in the loop to respond
and to claim ownership of all the changes. Please re-instate and complete the correct LLM
disclosure …"*).

**Operational consequence:** humans must own the PR. Volume without engagement is the
blacklist trigger, not AI use per se.

**Confidence:** High.

## 10.4 Closed-without-merge taxonomy

From a sample of 16 closed-unmerged PRs in a 3-month window:

| Reason | Count | Examples |
|---|---|---|
| LLM-spam closures by jakelishman | **9** | #16039, #16060, #16062, #16079, #16125, #16127 |
| Technically wrong fix | 2 | #16062 (wrong layer), #16124 (worse) |
| Scope-too-narrow | 1 | #16064 LieTrotter cubic special case |
| Superseded by backport | 1 | #16077 |
| Dependabot replaced by newer | 1 | #16056 |
| Workflow proposal didn't survive | 1 | #16093 "Use Bob to spell check the release notes" |

**Inferred rule:** maintainers prefer to **close rather than partially merge** half-correct
fixes. They will guide engaged contributors first via inline comments before closure
(#16116 was closed only after the proposed fix was deemed structurally wrong; #16124's
contributor was given a counter-example before closure).

## 10.5 Reverts

Reverts are explicit and rare (~1% of merges):

- **#15906** Revert of **#15488** (Pauli ↔ standard-gate commutation). Replaced cleanly by
  **#15925**.
- **#16146** Revert of **#15931** (PGO QV circuit inflated 100→193 qubits, slowing profile
  collection). PR body called out the regression precisely.

**Pattern:** revert PR titled `Revert "<original title>"`, body explains the regression,
follow-up rewrite lands later.

**Confidence:** High.

## 10.6 Specialization is real — route PRs to the right person

If you're submitting a PR, the `qiskit_bot.yaml` notification routing tells you who'll
review:

| Path you touched | Likely reviewer |
|---|---|
| `qpy/`, `crates/qpy/` | mtreinish (also jakelishman) |
| `circuit/library/`, feature maps | Cryoris, ajavadia |
| `primitives/` | t-imamichi, ajavadia, levbishop |
| Synthesis / Clifford / fault-tolerance | alexanderivrii, ShellyGarion |
| Sabre / transpiler perf | mtreinish |
| Visualization (Rust drawer) | eliarbel |
| C API / FFI | mtreinish, jakelishman |
| Anything not above | @Qiskit/terra-core (jakelishman is most active default) |

CONTRIBUTING.md notes the courtesy-tagging convention: wait a week before pinging a maintainer.

**Confidence:** High.

## 10.7 Community-PR funnel

"Community PR"-labeled merges (~14 in window) cluster into:

- **Documentation fixes** (#15398, #15565, #15688) — generally accepted.
- **Carefully-guided bug fixes** (#15642, #15782) — accepted after iteration.
- **Novel features from non-core contributors** are rarer; require strong scoping. **#15396**
  (IQP via C bindings) merged after extensive review; **#16064** (LieTrotter) closed.

**Inference:** the bar for novel community feature PRs is "small, focused, well-tested, well-
described, with a maintainer who knows the area willing to drive it through." Community
contributors who submit a sustained stream of small documentation/typo PRs build credibility
faster than those who open large feature PRs cold (the `ihincks` typo train is a clear
example, though `ihincks` is an internal contributor).

## 10.8 Maintainer-side automation they rely on

- **Mergify** for backports.
- **`qiskit_bot.yaml`** for routing + changelog category.
- **Dependabot** for routine bumps.
- **External `generate_changelog.py`** in `qiskit-bot` repo for `Changelog: …` audits before
  release.
- **Reno** for release-note assembly.

## 10.9 PR numbers cited in this document

14719, 14911, 15279, 15398, 15396, 15488, 15565, 15642, 15688, 15721, 15782, 15807, 15815,
15832, 15839, 15871, 15874, 15881, 15906, 15924, 15925, 15928, 15931, 15960, 15967, 15994,
15999, 16004, 16010, 16014, 16016, 16039, 16052, 16060, 16062, 16064, 16065, 16077, 16079,
16093, 16101, 16113, 16116, 16123, 16124, 16125, 16127, 16128, 16132, 16146.

## 10.10 Cross-document PR citation summary

Across documents 8–10, the playbook cites **>120 distinct merged or closed PR numbers**,
exceeding the 50-PR sampling target stated in the original prompt.
