---
name: qiskit-optional-dependencies
description: Wrap any non-required Qiskit dependency through `qiskit.utils.optionals` lazy testers (`HAS_MATPLOTLIB`, `HAS_AER`, `HAS_QASM3_IMPORT`, ...) — import inside the function, raise `MissingOptionalLibraryError` if absent, register the extra in `pyproject.toml`. Use whenever the user wants to add a dependency that isn't core (matplotlib, aer, plotly, qasm3 importers), or asks how to make a dep optional. Module-top imports of optionals are banned (CONTRIBUTING.md:978-983); modules-of-this-shape are how Qiskit fails to import on minimal envs.
---

# Qiskit optional dependencies

Qiskit's runtime is intentionally minimal — `requirements.txt` lists only `rustworkx`, `numpy`, `scipy`, `dill`, `stevedore`, `typing-extensions`. Everything else (matplotlib, aer, qasm3 importers, plotly, …) is optional.

The rule (§11.10.2, **Mandatory**, codified in CONTRIBUTING.md:978-983):

- Module-top `import matplotlib` (or any optional) is banned.
- Imports happen **inside the function** that needs them.
- Use `qiskit.utils.optionals` lazy testers to probe presence without importing.
- Raise `MissingOptionalLibraryError` (which dual-inherits `ImportError`) if absent.
- Register the dep in `pyproject.toml` extras so `pip install qiskit[<extra>]` works.

## The pattern

```python
def plot_state_qsphere(state, ...):
    """Plot a state on a qsphere."""
    from qiskit.utils.optionals import HAS_MATPLOTLIB

    HAS_MATPLOTLIB.require_now("plot_state_qsphere")
    import matplotlib.pyplot as plt   # only after require_now passes
    ...
```

`HAS_MATPLOTLIB.require_now("plot_state_qsphere")` raises `MissingOptionalLibraryError(QiskitError, ImportError)` if matplotlib isn't installed, with a message that names the function and tells the user the install command.

For a probe (don't raise, just check):

```python
from qiskit.utils.optionals import HAS_AER

if HAS_AER:
    from qiskit_aer import AerSimulator
    backend = AerSimulator()
else:
    backend = BasicSimulator()
```

`HAS_AER` is truthy if the import would succeed.

## Adding a new optional

Suppose you're adding optional Plotly-based visualization:

### 1. Add a lazy tester

`qiskit/utils/optionals.py` lists the testers. Append:

```python
HAS_PLOTLY = _LazyImportTester(
    "plotly",
    name="Plotly",
    install="pip install plotly",
)
```

Read existing testers (`HAS_MATPLOTLIB`, `HAS_AER`, `HAS_QASM3_IMPORT`) for the exact form — some take `package` vs `name` arguments depending on whether the import name differs from the install name.

### 2. Register the extra in `pyproject.toml`

`pyproject.toml:56-81` lists `[project.optional-dependencies]`:

```toml
[project.optional-dependencies]
qasm3-import = ["qiskit-qasm3-import>=0.2.0"]
visualization = [
    "matplotlib>=3.3",
    "pillow>=4.2.1",
    "pylatexenc>=1.4",
    "seaborn>=0.9.0",
    "pydot>=4.0.0",
]
crosstalk-pass = ["z3-solver>=4.7"]
csp-layout-pass = ["python-constraint>=1.4"]
qpy-compat = ["qiskit-terra==0.46.3"]
plotly-viz = ["plotly>=5.0"]   # <-- new
```

If the dep belongs to an existing bundle (`visualization`), append there. Otherwise create a focused extra. `dev` should still pull everything in transitively (it's `[dev = [..., "qiskit[plotly-viz]"]]` style).

### 3. Use it inside the function

```python
def my_function(...):
    from qiskit.utils.optionals import HAS_PLOTLY
    HAS_PLOTLY.require_now("my_function")
    import plotly.graph_objects as go
    ...
```

### 4. Tests

Tests that exercise the optional path should be skipped without the extra:

```python
import unittest
from qiskit.utils.optionals import HAS_PLOTLY


@unittest.skipUnless(HAS_PLOTLY, "Plotly not installed")
class TestMyFunction(QiskitTestCase):
    def test_runs_with_plotly(self):
        ...
```

The `tox -eminoptional` env runs the suite without optionals to verify the absent-dep path raises cleanly.

### 5. Documentation

If the function appears in the public API docs, mention the install command in the docstring's `Raises:` section:

```python
def my_function(...):
    """...

    Raises:
        MissingOptionalLibraryError: if Plotly is not installed.
            Install with ``pip install qiskit[plotly-viz]``.
    """
```

## Why module-top imports are banned

If `qiskit/visualization/state_visualization.py` did `import matplotlib` at the top, then anyone running `from qiskit import QuantumCircuit` on a minimal environment would crash with a confusing `ModuleNotFoundError: No module named 'matplotlib'` even though they never asked to plot anything.

The lazy-testers + function-local imports give the user:

- A working `qiskit` import on a minimal environment.
- A clear `MissingOptionalLibraryError` only when they actually call the optional path.
- A discoverable install command in the error message.

## Reno entry

If this is a new optional path, add `Changelog: Added` and a `features_*` reno entry naming the new extra.

## Heuristics

- **Don't add deps reflexively.** Justify why `numpy` / `scipy` / `rustworkx` isn't enough (§11.10.1).
- **Loose lower bounds (`>=`), no upper bound** unless a known break exists. `numpy < 3` is the only forward upper bound currently.
- **`tqdm` for progress bars is the canonical "no, don't add it"** — Qiskit's logging channels are the established way to report progress. If a contributor proposes adding tqdm, push back.
- **Test the absent path.** Run `tox -eminoptional` locally. If your code paths import the optional unconditionally, that env will fail.

## Related skills

- [[qiskit-error-handling]] — `MissingOptionalLibraryError` dual-inherits `ImportError`.
- [[qiskit-dependency-policy]] — broader dep-addition checklist.
- [[qiskit-coding-conventions]] — import ordering rules.
