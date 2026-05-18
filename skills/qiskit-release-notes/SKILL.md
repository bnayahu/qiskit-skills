---
name: qiskit-release-notes
description: Generate a Qiskit reno release-note YAML on the right axis (`features_*`, `fixes`, `performance`, `upgrade*`, `deprecations*`, `build`, `critical`, `security`, `other`) and recommend the matching `Changelog:` label. Use whenever the user is preparing a Qiskit PR with a user-visible change, says "add a release note", "write the reno entry", or asks which `Changelog:` label applies. Required by `qiskit_bot.yaml` for every user-visible PR; missing reno entries are the most common review round-trip in the repo.
---

# Qiskit release notes (reno)

Qiskit uses [reno](https://docs.openstack.org/reno/) for release notes. Every user-visible PR ships with a YAML file under `releasenotes/notes/` (or `releasenotes/notes/x.y/` once a stable branch has been cut). The `qiskit_bot.yaml` changelog mapping reads the PR's `Changelog: <X>` label and slots the rendered note into the right section of the GitHub Release.

## Decision: do you need a reno entry?

| Change | Reno entry? | `Changelog:` label |
|---|---|---|
| New public API (gate, pass, primitive, function) | Yes | `Added` |
| User-visible bug fix | Yes | `Fixed` |
| Behavior change without break (e.g. better default) | Yes | `Changed` |
| Performance improvement (speed or memory) | Yes | `Performance` |
| Deprecation (e.g. `@deprecate_func` added) | Yes | `Deprecated` |
| Removal (in major release) | Yes | `Removed` |
| Build-system change downstream packagers care about | Yes | `Build` |
| QPY format-version bump | Yes (`features_qpy` or `upgrade_qpy`) | `Added` / `Changed` |
| Critical correctness regression backported | Yes (`critical`) | `Fixed` |
| Security fix | Yes (`security`) | `Fixed` |
| Pure refactor (no observable change) | No | `None` |
| CI / lint / dep bump (Dependabot) | No | `None` |
| Doc typo / spelling | No | `None` |
| Backport PR | No (original carries it) | (inherited) |

If unsure, the principle is: *"would a downstream user notice this change?"* If yes, write the note.

## How to create the file

Use `reno` (already in the `lint` dependency group):

```bash
reno new <short-slug>
```

This creates `releasenotes/notes/<slug>-<deterministic-hash>.yaml`. **Never hand-name the file** — the hash suffix is what makes it deterministic across rebases (§11.1.4). After a stable branch is cut, the file is moved into `releasenotes/notes/x.y/` during release prep.

## Section keys

Pick exactly the section(s) the change touches. Common ones:

- `features` — broad new features.
- `features_circuits` — `qiskit/circuit/`, `crates/circuit/`.
- `features_transpiler` — `qiskit/transpiler/`, `crates/transpiler/`.
- `features_qpy` — `qiskit/qpy/`, `crates/qpy/`.
- `features_synthesis`, `features_quantum_info`, `features_primitives`, `features_visualization`, `features_misc`, `features_c`, `features_providers`, `features_qasm`.
- `fixes` — bug fixes.
- `performance` — speed/memory wins (added in #16065).
- `upgrade`, `upgrade_circuits`, `upgrade_transpiler`, `upgrade_qpy`, … — user-actionable behavior changes.
- `deprecations`, `deprecations_circuits`, … — deprecation notices.
- `build` — build-system changes.
- `critical` — release-blocker class fixes.
- `security` — security fixes.
- `other` — last resort.

Multiple sections are allowed when the change touches multiple axes (e.g. a perf-driven parallel pass: `features_transpiler` + `performance`).

## YAML body conventions

```yaml
---
fixes:
  - |
    Fixed a bug in :class:`.BasisTranslator` where nested
    :class:`.ControlFlowOp` blocks were not recursed into, causing
    basis translation to be skipped inside ``IfElseOp`` bodies.
    Fixed `#15870 <https://github.com/Qiskit/qiskit/issues/15870>`__.
```

Body conventions (inferred from across `releasenotes/notes/`):

- The `|` block scalar preserves linebreaks for the rendered RST.
- Reference public symbols with `:class:`, `:func:`, `:meth:`, `:attr:` Sphinx roles. Example: `:class:`.BasisTranslator``, `:func:`.transpile``, `:meth:`.QuantumCircuit.compose``.
- Use double-backticks for code spans (`` ``ControlFlowOp`` ``), not single (which is italics in RST).
- Issue references use the full URL form: `` `#15870 <https://github.com/Qiskit/qiskit/issues/15870>`__ ``.
- Write in the past tense for `fixes:`/`upgrade:` (the change has happened in this version) and present tense for `features:`.
- Wrap at ~80 chars per line for readability.

## Examples

### Fix entry

```yaml
---
fixes:
  - |
    Fixed :class:`.BasisTranslator` to correctly recurse into nested
    :class:`.ControlFlowOp` blocks. Previously, basis translation was
    skipped inside ``IfElseOp`` and ``WhileLoopOp`` bodies.
    Fixed `#15870 <https://github.com/Qiskit/qiskit/issues/15870>`__.
```

### Feature entry

```yaml
---
features_transpiler:
  - |
    Added :class:`~qiskit.transpiler.passes.MeasurementCount`, an
    :class:`.AnalysisPass` that records the number of measurements
    targeting each qubit in the property set under the
    ``"measurement_count"`` key.
```

### Performance entry

```yaml
---
features_transpiler:
  - |
    :class:`.CommutationAnalysis` now runs in parallel using rayon.
    On 27-qubit benchmark circuits the pass is roughly 4x faster on
    an 8-core machine.
performance:
  - |
    Improved the runtime of :class:`.CommutationAnalysis` on circuits
    with many independent commutation classes by parallelizing the
    scan; see ``Changelog: Performance``.
```

(For perf entries, also include ASV numbers in the PR body — see [[qiskit-performance-benchmarks]].)

### Deprecation entry

```yaml
---
deprecations_circuits:
  - |
    The ``foo`` argument of :meth:`.QuantumCircuit.bar` is deprecated
    as of qiskit 2.5 and will be removed no sooner than qiskit 3.0.
    Use the new ``new_foo`` argument instead, which accepts the same
    values.
```

(See [[qiskit-deprecation]] for the decorator wiring.)

## Heuristics

- **One section per axis, not per file.** A PR that touches `circuit/` and `transpiler/` for the same logical change uses `features_transpiler` (the user-visible payoff) — not both.
- **The note is for users, not reviewers.** State the user-observable change. "Refactored internal helper X" is not a release note.
- **Reference issue numbers when fixing them.** It cross-links the release notes back to the GitHub history.
- **For QPY format bumps, also state the format version.** Example: *"QPY format version is now 14, supporting <new-thing>."*

## Related skills

- [[qiskit-pr-preparation]] — pick the right `Changelog:` label.
- [[qiskit-good-pr-checklist]] — check the entry exists.
- [[qiskit-deprecation]] — for deprecation YAML.
- [[qiskit-qpy-compatibility]] — `features_qpy` / `upgrade_qpy`.
- [[qiskit-performance-benchmarks]] — what to put in the PR body for `Changelog: Performance`.
