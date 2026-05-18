---
name: qiskit-deprecation
description: Apply the canonical Qiskit deprecation decorators (`@deprecate_func`, `@deprecate_arg`, `@deprecate_arg_default`), enforce the two-version compatibility window, and generate paired tests — one with `assertWarns(DeprecationWarning)` for the old path, one warning-free for the new path. Use whenever the user wants to deprecate a Qiskit function/method/argument, rename a public API, or asks how to remove something. `QiskitTestCase` treats `DeprecationWarning` as an error so missing the second test fails CI; reviewers reject single-test deprecation PRs.
---

# Qiskit deprecation pattern

Qiskit's deprecation policy (`DEPRECATION.md`):

- **Two-version compatibility window.** Old + new code paths coexist for ≥2 consecutive minor releases with zero warnings on the new path.
- **One-minor visibility period.** After issuing `DeprecationWarning`, wait ≥1 minor before removal.
- **3-month minimum removal timeline** from the deprecation warning.
- **Removals only in major releases.** Deprecations only in minor releases.
- **Public API ≠ importable surface.** Only documented Sphinx-page symbols are protected. Private import paths can move without deprecation.

## Decorator catalog (`qiskit/utils/deprecation.py`)

### `@deprecate_func`

Deprecate an entire function, method, or property.

```python
from qiskit.utils.deprecation import deprecate_func

@deprecate_func(
    since="2.5",
    additional_msg="Use :meth:`.QuantumCircuit.foo_v2` instead.",
    removal_timeline="in qiskit 3.0",
    pending=False,
)
def foo(self, ...):
    ...
```

Auto-inserts a `.. deprecated:: 2.5` Sphinx directive into the docstring (`utils/deprecation.py:311-383`). Pass `pending=True` to issue `PendingDeprecationWarning` for early-stage deprecations (lower visibility).

### `@deprecate_arg`

Deprecate a single argument with optional alias to a new name.

```python
@deprecate_arg(
    "old_name",
    new_alias="new_name",
    since="2.5",
    removal_timeline="in qiskit 3.0",
    predicate=lambda v: isinstance(v, dict),  # optional filter
)
def my_func(*, new_name=None):
    ...
```

`new_alias` makes the decorator forward the old kwarg into the new one transparently for one cycle. `predicate` lets you deprecate only certain values (e.g. only when the argument is a dict, but not when it's a list).

### `@deprecate_arg_default`

Deprecate a default value (e.g. when changing `approximation_degree=None` to `approximation_degree=1.0` in #15807).

```python
@deprecate_arg_default(
    "approximation_degree",
    new_default=1.0,
    since="2.5",
)
def synthesize(...):
    ...
```

## Tests — both paths, Mandatory (§11.5.2)

`QiskitTestCase` (`test/utils/base.py:91`) treats `DeprecationWarning` as an **error** by default. Reviewers reject single-test PRs (CONTRIBUTING.md:928-953; Cryoris on #15994). Always write **both**:

```python
class TestFooDeprecation(QiskitTestCase):

    def test_old_path_warns(self):
        # The deprecated path must still work, but must emit the warning.
        with self.assertWarns(DeprecationWarning):
            result = my_func(old_name={"k": "v"})
        self.assertEqual(result, expected)

    def test_new_path_silent(self):
        # The new path must produce no warning. QiskitTestCase
        # treats DeprecationWarning as an error, so this test
        # implicitly asserts no warning is emitted.
        result = my_func(new_name={"k": "v"})
        self.assertEqual(result, expected)
```

For `pending=True` deprecations, use `PendingDeprecationWarning` in the assertion.

## Reno entry

Use [[qiskit-release-notes]] to write a YAML under `deprecations` (or `deprecations_circuits`, `deprecations_transpiler`, etc.). Apply the `Changelog: Deprecated` label on the PR.

```yaml
---
deprecations_circuits:
  - |
    The ``old_name`` argument of :meth:`.QuantumCircuit.bar` is
    deprecated as of qiskit 2.5 and will be removed no sooner than
    qiskit 3.0. Use the new ``new_name`` argument instead, which
    accepts the same values.
```

## Hand-rolled `warnings.warn` is obsolete

Don't write `warnings.warn(DeprecationWarning("..."))` by hand for new code (§11.6.3, §11.13). The decorators are the only sanctioned mechanism — they auto-insert Sphinx directives, standardize the warning class, and integrate with the predicate API.

## Heuristics

- **Pick `since=` carefully.** Use the *next minor* version (the one being prepared on `main`), not the current latest stable. Check `qiskit/VERSION.txt` for the current dev version.
- **Phrase `additional_msg` so it tells users what to do.** `"Use :meth:`.QuantumCircuit.foo_v2` instead."` is good; `"This is deprecated."` is useless.
- **For renames, alias the old name to the new for one cycle.** `new_alias=` does this for arguments. For functions, write a thin wrapper that calls the new function and decorate the wrapper.
- **C API deprecations** use `\qk_deprecated{version|reason}` Doxygen + `#[deprecated]` Rust attributes propagated via cbindgen (`DEPRECATION.md:258-304`). Pre-3.0, the C API is explicitly unstable so deprecations are best-effort.
- **Experimental APIs (`ExperimentalWarning`)** are exempt from semver — they may break at any minor without a deprecation cycle (§6.5).

## Related skills

- [[qiskit-release-notes]] — write the `deprecations*` YAML.
- [[qiskit-api-evolution]] — figure out the right `since=` and removal timeline.
- [[qiskit-good-pr-checklist]] — verifies both tests exist before review.
- [[qiskit-pr-preparation]] — `Changelog: Deprecated` label.
