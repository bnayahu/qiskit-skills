---
name: qiskit-api-evolution
description: Map Qiskit's public-API contract — documented surface only, two-version compatibility window, three-month minimum removal timeline, removals only in major releases, deprecations only in minors. Distinguish public from private import paths (e.g. `qiskit.circuit.measure` private vs `qiskit.circuit.Measure` public). Use whenever the user asks "can I rename this?", "when can I remove this?", "is this part of the API?", or any question about Qiskit's stability guarantees.
---

# Qiskit API evolution

The contract (`DEPRECATION.md`):

- **SemVer** since 1.0. `MAJOR.MINOR.PATCH`.
- **Public API ≠ importable surface.** Public is what's documented in Sphinx pages.
- **Two-version compatibility window.** Old + new paths coexist for ≥2 consecutive minors with zero warnings on the new path.
- **One-minor visibility period.** After the deprecation warning fires, wait ≥1 minor before removal.
- **3-month minimum removal timeline.**
- **Removals only in major releases. Deprecations only in minor releases.**
- **Patch releases:** bug fixes only, no API changes.

## Public vs private (§11.6.1, **Mandatory**)

The rule (`DEPRECATION.md:40-56`): the public API is **what is documented in the public API docs**, not what is reachable via imports.

| Path | Public? |
|---|---|
| `qiskit.QuantumCircuit` | Yes (top-level documented class) |
| `qiskit.circuit.QuantumCircuit` | Yes (re-export) |
| `qiskit.circuit.Measure` | Yes (documented class) |
| `qiskit.circuit.measure` | **No** (private module path even though `Measure` exists there) |
| `qiskit._accelerate.*` | **No** (`_` prefix) |
| Any internal helper in `_<file>.py` | **No** |

Practical implication: **moving** `qiskit.circuit.measure` (the private path) **without a deprecation cycle is allowed**. Removing `qiskit.circuit.Measure` (the documented class) is **not** — that requires a deprecation in a minor release and removal no earlier than the next major.

When in doubt, check `docs/apidocs/` and the rendered Sphinx pages. If the symbol appears there, it's public.

## Timeline matrix

| Action | Allowed in | Notes |
|---|---|---|
| Add new public API | Any minor | Use `Changelog: Added` |
| Bug fix (no API change) | Patch, minor, major | `Changelog: Fixed` |
| Performance improvement (no behavior change) | Patch, minor, major | `Changelog: Performance` |
| Behavior change (no break) | Minor | `Changelog: Changed` |
| Add deprecation | Minor | `Changelog: Deprecated`; @deprecate_func |
| Remove deprecated symbol | Major | `Changelog: Removed` |
| Break a public API without deprecation | **Never** for SemVer-protected; only for `ExperimentalWarning`-marked | `Changelog: Removed` for the major; emergency `critical` for security |

## Deprecation timeline example

If `QuantumCircuit.foo()` should go:

| Version | Status | Action |
|---|---|---|
| 2.4 | `foo()` exists, no warning | (current) |
| **2.5** | `foo()` deprecated, both paths work | Add `@deprecate_func(since="2.5", removal_timeline="in qiskit 3.0")`. Warning fires when `foo()` is called. |
| 2.6 | both paths still work | No change. The user has at least one minor of deprecation. |
| ... | ... | wait ≥3 months from 2.5 |
| **3.0** | `foo()` removed | Major release; symbol can disappear. |

Removal timeline: **≥ 3 months from deprecation** AND **next major release** (whichever is later). For Qiskit's roughly-yearly major cadence, the minimum is essentially "next major after 3 months."

For renames, use `new_alias` so the old name forwards to the new for one cycle:

```python
@deprecate_arg("old_name", new_alias="new_name", since="2.5")
def my_func(*, new_name=None): ...
```

## Experimental APIs (§6.5)

`qiskit/exceptions.py:65-72` defines `ExperimentalWarning(QiskitWarning)`. Symbols that issue this warning on import or use are **exempt from semver** — they may break at any minor without a deprecation cycle.

Example: `qiskit.qasm3` on import emits `ExperimentalWarning`. The contract is: "we'll iterate on this; don't pin to a specific shape."

Tests that exercise experimental APIs typically suppress: `warnings.filterwarnings("ignore", category=ExperimentalWarning)`.

## C API (`DEPRECATION.md:258-304`)

**Pre-3.0, the C API is explicitly unstable.** Deprecations are best-effort:

- Doxygen `\qk_deprecated{version|reason}` markers.
- Rust `#[deprecated]` attributes propagate to C headers via cbindgen.

C-API breaking changes pre-3.0 are allowed in minor releases.

## Renaming a symbol

The pattern:

1. **Pick a `since` version** equal to the next minor (the dev branch; check `qiskit/VERSION.txt`).
2. **Decide if the new name should coexist with the old.** If yes, alias old → new for one cycle.
3. **Add the decorator** to the old symbol; emit `DeprecationWarning`.
4. **Update internal call sites** to use the new name (so the warning doesn't fire from inside Qiskit).
5. **Add tests for both paths** (§11.5.2). See [[qiskit-deprecation]].
6. **Add a `deprecations*` reno entry**. See [[qiskit-release-notes]].
7. **Document the removal timeline** in `additional_msg=` and the reno entry.

## Restricting types is a behavior change

Cryoris on #15832: *"Why change from `Iterable` to `set`? That seems more restrictive."*

Tightening a type annotation can break callers passing a previously-accepted type. Don't tighten unless the new type-set is a superset.

## When in doubt

Treat the symbol as **public** if:

- It's reachable from `qiskit.<package>.<name>` without underscores.
- It appears in the rendered Sphinx pages under `docs/apidocs/`.
- It's exported in a package `__init__.py`.

If at least one of those is true, deprecate first; remove only in the next major.

## Heuristics

- **`since=` is the next minor.** Check `qiskit/VERSION.txt` for the current dev version.
- **`removal_timeline="in qiskit X.0"`** with the next major version number.
- **Update internal call sites** before adding the decorator. Otherwise the test suite will fail because `QiskitTestCase` treats `DeprecationWarning` as an error.
- **For the C API pre-3.0**, you have more freedom but should still mark deprecation when reasonable.
- **For experimental APIs**, you have the most freedom but should still write a clear release-note entry on the change.

## Related skills

- [[qiskit-deprecation]] — decorator wiring and both-path tests.
- [[qiskit-release-notes]] — `deprecations*` YAML.
- [[qiskit-release-ceremony]] — when removals can ship.
- [[qiskit-pr-preparation]] — `Changelog:` label selection.
- [[qiskit-anti-patterns]] — #19 misuse of private paths.
