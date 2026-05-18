---
name: qiskit-coding-conventions
description: Apply Qiskit's formatting and linting rules — black 100-char, ruff 110-char (deferring to black), `from __future__ import annotations` universal, modern union syntax (`X | Y`), Google docstrings (D417 enforced), import ordering, no `print`/`println!`. Wraps `tox -elint`. Use whenever the user finishes editing Python or Rust in `qiskit/` or `crates/`, asks about code style, runs into lint errors, or asks "is this formatted right?".
---

# Qiskit coding conventions

The local lint loop is `tox -elint` (no pre-commit framework — §11.10.5). The pinned tooling is exact-pinned (§11.10.3, **Mandatory**) so contributors can't disagree with CI's verdict.

## Tools and pins

| Language | Tool | Config | Source |
|---|---|---|---|
| Python format | `black` | line-length 100, target `py310`–`py313` | `pyproject.toml:282-284` |
| Python lint | `ruff==0.15.2` | line-length 110 (lint only); rules: `E,F,PL,UP,S,RUF,G,EXE,C4,T10,RSE,PIE,INP,T20,D417` | `pyproject.toml:318-496` |
| Rust format | `rustfmt` | enforced via `cargo fmt` | `rustfmt.toml` |
| Rust lint | `clippy` | `deny(print_stdout, print_stderr, unsafe_op_in_unsafe_fn)`; runs `--all-targets` (covers tests, #16128) | `Cargo.toml:71-86`, `.clippy.toml` |
| C format | `clang-format` | LLVM-derived | `.clang-format` |

Pinned linter versions: `ruff==0.15.2`, `black[jowtter]~=25.1`, `setuptools-rust==1.12.0`, `Sphinx==9.1.0`, `docutils==0.22.4` — anything that controls CI behavior is exact-pinned.

## Line length

- **black: 100 chars** (Python).
- **ruff: 110 chars** but `E501` is in the ignore list — ruff defers to black.
- **Net effective limit: 100 chars** on Python.

## Import ordering

Conventional Python ordering (no enforced isort, but consistent across the codebase):

1. `from __future__ import annotations` (universal at module top).
2. Standard library.
3. Third-party (`numpy`, `scipy`, `rustworkx`, …).
4. Local relative imports from `qiskit.*`.
5. **Optional dependencies** imported **inside** functions to keep import time low and to allow graceful `MissingOptionalLibraryError` (§11.10.2; CONTRIBUTING.md:978-983). See [[qiskit-optional-dependencies]].

## Type hints (§11.9.2, **Mandatory**)

- `from __future__ import annotations` at module top.
- **Modern union syntax**: `int | float | None`. Don't use `Optional[X]` or `Union[X, Y]` — they're flagged by `UP` ruff rules and superseded.
- `if TYPE_CHECKING:` guards to break circular imports of `DAGCircuit`, etc.
- **No runtime validators** (no pydantic, no typeguard). Boundary checks are manual `isinstance(...)`.
- Don't widen / narrow types reflexively (Cryoris on #15832: *"Why change from `Iterable` to `set`? That seems more restrictive."*).

## Docstrings

- **Style: Google** (`napoleon_google_docstring=True`, `napoleon_numpy_docstring=False` in `docs/conf.py`).
- **`D417` is selected** in ruff — undocumented arguments fail lint (#15721 promoted this to CI-blocking).
- Use `` ``code`` `` (double-backtick RST), not `*code*` (which is italics).
- Don't strip whitespace lines from module docstrings (Cryoris in #15832).
- Don't write redundant `__init__` summaries on analysis passes — *"This is true for every analysis pass and doesn't need to be pointed out explicitly."*
- Deprecation decorators auto-insert `.. deprecated:: x.y` blocks; don't write them by hand.

Sphinx roles to use:

- `:class:`.QuantumCircuit`` — class.
- `:func:`.transpile`` — function.
- `:meth:`.QuantumCircuit.compose`` — method.
- `:attr:`.Gate.name`` — attribute.

## No-no list (Mandatory unless noted)

- **No `print` in Python library code** — `T20` ruff rule (`pyproject.toml:318-496`).
- **No `println!` / `eprintln!` in Rust** — workspace clippy `deny(print_stdout, print_stderr)`.
- **No `--no-verify`** on commits in CI flows.
- **No undocumented public args** (D417).
- **No undisclosed AI tool use** — CONTRIBUTING.md mandates AI/LLM disclosure in PR body.
- **No `Union[X, Y]` / `Optional[X]`** — modern union syntax.
- **No hand-rolled `warnings.warn(DeprecationWarning(...))`** — use `@deprecate_func` / `@deprecate_arg` (§11.6.3).
- **No module-top optional imports** — see [[qiskit-optional-dependencies]].

## Editor / whitespace

`.editorconfig`:

- LF line endings, UTF-8, final newline required.
- Python: 4-space indent.
- JS/JSON/YAML: 2-space indent.
- Makefile: tabs.

## Local lint loop

```bash
# Full lint (matches CI):
tox -elint

# Black + ruff only on touched files (faster):
black qiskit/ test/
ruff check qiskit/ test/

# Rust:
cargo fmt --all
cargo clippy --all-targets --workspace -- -D warnings
```

`Cargo.lock` must be current — #15839 added a Cargo.lock currency check to lint. After any `Cargo.toml` change, run `cargo build` and commit `Cargo.lock`.

## `.git-blame-ignore-revs`

Mass reformat commits get added here so `git blame` skips them. If you're running a code-style sweep across many files, append the resulting commit hash.

## `.local-spellings`

Sphinx spellcheck consumes 291 entries covering quantum-domain terms (`qubit`, `Pauli`, `Hadamard`, `Toffoli`) and contributor names. Append when adding new domain terms or author handles to docs.

## `.mailmap`

A 14 KB `.mailmap` normalizes author identities. New contributors with multiple email addresses get unified there.

## Recurring style nits in review

From inline comments cited in §3.10:

- Use `` ``dag`` ``, not `*dag*`.
- Don't over-narrow type hints (`Iterable` → `set` is too restrictive).
- Don't drop blank lines inside docstrings.
- Drop redundant `__init__` summaries on analysis passes.
- Fixed-size arrays over `SmallVec`/`Vec` when N is statically known.
- Replace `expect`/panics with compile-time checks where possible.

## Heuristics

- **Run `tox -elint` before push.** It's faster than waiting for CI feedback.
- **Touch only the files in your diff.** Mass reformatting unrelated code makes review hard.
- **For `from __future__ import annotations` vs `if TYPE_CHECKING:`** — Cryoris prefers `if TYPE_CHECKING:` for minimal diffs (§11.12.1; **Disputed**); either is accepted.
- **Don't suppress lint locally.** If a rule fires, fix the code, not the rule. Real exceptions live in `pyproject.toml:318-496` and are added with justification.

## Related skills

- [[qiskit-rust-performance-idioms]] — Rust-side patterns beyond formatting.
- [[qiskit-optional-dependencies]] — module-top import rule.
- [[qiskit-good-pr-checklist]] — verifies lint passes pre-PR.
