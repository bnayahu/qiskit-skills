---
name: qiskit-debugging
description: Apply Qiskit's debug-time conventions — `logger = logging.getLogger(__name__)` per module with `%s`/`%d`-style args (deferred formatting); `LOG_LEVEL` env knob; never `print` / `println!`. For Rust, miri on unsafe paths; for unsafe FFI paths (excluded from miri) fall back to UBSan via `make ctest`. Use whenever the user wants to add diagnostic logging, debug a Qiskit issue, or asks "how do I print/log something?".
---

# Qiskit debugging conventions

The rules:

- **Module-local logger** (§11.4.1, **Preferred**).
- **Deferred formatting** with `%s`/`%d`-style args, not f-strings.
- **No `print()` in library code** — `T20` ruff rule (**Mandatory**).
- **No `println!`/`eprintln!` in Rust** — clippy `deny(print_stdout, print_stderr)` workspace-wide.
- **`warnings.warn` for user-facing soft signals**; `logger` for runtime instrumentation.

## Adding logging to a module

```python
# qiskit/transpiler/passes/optimization/foo.py
import logging

from qiskit.transpiler.basepasses import TransformationPass

logger = logging.getLogger(__name__)


class FooPass(TransformationPass):

    def run(self, dag):
        logger.info("FooPass: %d nodes input", dag.size())
        # ... work ...
        logger.debug("FooPass: replaced %d gates with %d gates",
                     before, after)
        return dag
```

Notes:

- `logger = logging.getLogger(__name__)` at module top, after imports.
- `logger.info("text %s", value)` — *not* `logger.info(f"text {value}")`. Deferred formatting means the string is built only when the log level is enabled.
- Use `logger.debug` for high-volume / verbose info, `logger.info` for once-per-pass progress, `logger.warning` for fallback decisions.

## Reading logs

The user-facing knob is `LOG_LEVEL` (CONTRIBUTING.md:522, `tox.ini`):

```bash
LOG_LEVEL=DEBUG python my_script.py
LOG_LEVEL=INFO tox -epy311 -- test.python.transpiler.test_foo
```

For tests, `QISKIT_TEST_CAPTURE_STREAMS=1` (`tox.ini:12`) captures stdout/stderr/logs so tests can assert on log content.

## Why no f-strings in `logger`

```python
# Bad: string is built every call, even when DEBUG is disabled
logger.debug(f"reduced {before} to {after}")

# Good: string is built only when DEBUG is enabled
logger.debug("reduced %s to %s", before, after)
```

For hot loops the cost is real. Existing code follows the `%s` form uniformly (e.g. `qiskit/passmanager/base_tasks.py:108`, `qiskit/providers/providerutils.py:108`).

## `warnings.warn` vs `logger`

| Channel | Use for |
|---|---|
| `warnings.warn(msg, QiskitWarning)` | Deprecation, experimental feature usage, "user is doing something we'd prefer they didn't" |
| `logger.info` / `.warning` | Pass-manager timing, transpilation progress, fallback decisions, internal diagnostics |

The two channels carry different information by design (§11.4.3). Don't `print()` regardless.

## Rust-side debugging

`println!` and `eprintln!` are **denied workspace-wide** by clippy (`Cargo.toml:71-86`). The reason: leftover `println!` is a recurring source of clippy failures (#15280, #15107, #15716, #15804, #16052 are rolling cleanups).

For diagnostics in Rust:

- Use `tracing` or `log` crates if you really need runtime logs (rare in Qiskit's Rust paths).
- Use `dbg!` *during development* but **remove before commit** — it goes through `eprintln!`.
- For test-time inspection, write a `#[test]` with `assert!`s rather than printing.

## Miri (`miri.yml`)

Miri is the Rust UB detector that runs on unsafe paths. It's a required check. **FFI tests are excluded** from miri because miri can't model FFI. For unsafe code reachable only through FFI, fall back to:

- **UBSan** via `make ctest` — the C API test suite is built with UBSan.
- **Unit tests in pure Rust** that exercise the unsafe block without crossing the FFI boundary.

If miri reports UB, the fix is in pure Rust code (FFI is excluded). #15049 ("Fix UB invocation in `SparseObservable` C API test") is the canonical example — UB in a Rust path that surfaced via the C test.

## Build profiles for debugging

`pip install -e .` produces a debug build by default (`setup.py:113`). Debug builds:

- Have full debug symbols.
- Are slower at runtime (don't benchmark on them).
- Surface panics with full traces.

For perf debugging: `QISKIT_BUILD_PROFILE=release pip install -e .`.

## Fast iteration

- `python setup.py build_rust --inplace` — recompile only the Rust extension without re-running `pip install`.
- `tox -epy311 -- test.python.<module>.<TestClass>.<test>` — run a single test.
- `cargo test -p qiskit-circuit -- --nocapture` — Rust test with stdout (won't pass clippy if you commit the `println!`, but useful in dev).

## Python ↔ Rust trace

When a Python error originates in Rust:

1. The `import_exception!`-wired `PyErr` carries the Rust `?`-propagated context.
2. The Python traceback shows `qiskit._accelerate.<submodule>` frames as opaque.
3. To get the Rust line, build with debug symbols (`QISKIT_BUILD_PROFILE=debug`) and enable `RUST_BACKTRACE=1`.

```bash
RUST_BACKTRACE=1 python -c "import qiskit; ..."
```

## Heuristics

- **Don't log in hot loops.** Even with deferred formatting, the `if logger.isEnabledFor(...)` check has cost. Move logs out of innermost iterations.
- **Don't add a logger module-by-module without a real diagnostic need.** New `logger = ...` should accompany new log calls.
- **Don't `print()` even temporarily.** Lint will catch it; remove it before commit. Use `logger.debug` if you need runtime info.
- **Don't suppress `DeprecationWarning` in tests.** `QiskitTestCase` treats them as errors deliberately. Use `assertWarns`.

## Related skills

- [[qiskit-rust-performance-idioms]] — no-panic, no-`println!`.
- [[qiskit-testing]] — `LOG_LEVEL`, capture streams.
- [[qiskit-error-handling]] — `warnings.warn` vs raises vs logger.
- [[qiskit-coding-conventions]] — `T20` rule, clippy denies.
- [[qiskit-security-review]] — miri, UBSan, FFI carve-out.
