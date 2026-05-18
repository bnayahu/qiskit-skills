# 3. Coding Conventions

## 3.1 Formatters and linters

| Language | Tool | Configuration | Source |
|---|---|---|---|
| Python format | `black` | line-length 100, target `py310`-`py313` | `pyproject.toml:282-284` |
| Python lint | `ruff` (pinned `==0.15.2`) | line-length 110 (lint only); selected rule families `E,F,PL,UP,S,RUF,G,EXE,C4,T10,RSE,PIE,INP,T20,D417` | `pyproject.toml:318-496` |
| Rust format | `rustfmt` (`rustfmt.toml`) | enforced via `cargo fmt` | `rustfmt.toml`, CONTRIBUTING.md:827 |
| Rust lint | `clippy` | `deny(print_stdout, print_stderr, unsafe_op_in_unsafe_fn)`, `allow(comparison-chain)` | `Cargo.toml:71-86`, `.clippy.toml` |
| C format | `clang-format` | LLVM-derived | `.clang-format`, CONTRIBUTING.md:832-838 |

**Confidence:** High. **Explicit.**

### Tight linter pins

`pyproject.toml:189-269` pins linter versions exactly: `ruff==0.15.2`, `black[jupyter]~=25.1`,
`reno>=4.1.0`. Looser pins on libraries; tighter pins on tooling that controls CI behavior.

## 3.2 Editor/whitespace rules

`.editorconfig`:

- LF line endings, UTF-8, final newline required.
- Python: 4-space indent.
- JS/JSON/YAML: 2-space indent.
- Makefile: tabs.

**Confidence:** High. **Explicit.**

## 3.3 Line-length nuance

- `black` enforces **100** chars on Python.
- `ruff` allows **110** chars but `E501` is in the ignore list — i.e. ruff defers to black.
- Net effective limit on Python: **100**.

**Confidence:** High. **Explicit.**

## 3.4 Docstrings

- **Style: Google** (Napoleon `napoleon_google_docstring=True`,
  `napoleon_numpy_docstring=False`) — see `docs/conf.py`.
- Sphinx autodoc generates API pages from docstrings.
- **`D417` is in ruff's selected rules** → undocumented arguments fail lint (PR **#15721**
  promoted this to CI-blocking).
- Deprecation decorators auto-insert `.. deprecated:: <version>` blocks before the first
  Napoleon section (`qiskit/utils/deprecation.py:311-383`).

**Confidence:** High. **Explicit.**

## 3.5 Import ordering (inferred)

Conventional Python ordering, consistently applied:

1. `from __future__ import annotations` (universal at module top).
2. Standard library.
3. Third-party (`numpy`, `scipy`, `rustworkx`, …).
4. Local relative imports from `qiskit.*`.
5. Optional dependencies imported **inside** functions to keep import time low and to allow
   graceful `MissingOptionalLibraryError` (CONTRIBUTING.md:978-983).

**Confidence:** High. **Inferred** (consistent across the codebase; no isort/ruff-isort enforced
config seen).

## 3.6 Type hints

- `from __future__ import annotations` is universal → strings, lazy evaluation, no runtime cost.
- Modern `X | Y | None` union syntax preferred over `Union[X, Y]`.
- `if TYPE_CHECKING:` guards used to break circular imports.
- **No** runtime validators (no `pydantic`, no `typeguard`). Boundary validation is manual
  `isinstance()` checks raising `QiskitError` subclasses.

**Confidence:** High. **Inferred** from `qiskit/circuit/quantumcircuit.py:15-16,1053+` etc.;
called out by reviewer Cryoris in **#15832** review comments.

## 3.7 Local spellings

`.local-spellings` (291 entries) is consumed by Sphinx spell-check; covers quantum-domain
terms (`qubit`, `Pauli`, `Hadamard`, `Toffoli`, `transpiler`, …) and contributor names. New
authors and terms get appended here.

**Confidence:** High. **Explicit.**

## 3.8 `.git-blame-ignore-revs`

The repo maintains a list of commits to skip when running `git blame` (e.g. mass black/clippy
reformats). Re-runs of code-style sweeps should add their hash here.

**Confidence:** High. **Explicit.**

## 3.9 `.mailmap`

A non-trivial 14 KB `.mailmap` exists, normalizing author identities. New contributors with
multiple email addresses should expect their identities to be unified here.

**Confidence:** Medium. **Explicit** (file exists), **Inferred** (no policy doc, but file is
kept up to date).

## 3.10 Style nits that recur in PR reviews

From inline review comments (cited examples in `09-reviewer-expectations.md`):

- Use `` ``dag`` `` (double-backtick RST), not `*dag*` italic, in docstrings.
- Don't over-narrow type hints (`Iterable` → `set` is too restrictive).
- Don't drop blank lines inside docstrings (Cryoris in **#15832**).
- Drop redundant `__init__` summaries on analysis passes — *"This is true for every analysis
  pass and doesn't need to be pointed out explicitly."*
- Avoid unnecessary `smallvec`/`Vec` allocations in Rust hot paths; use fixed-size arrays
  when size is statically known (mtreinish in **#16123**).
- Replace `expect`/panics in Rust with compile-time checks where possible (**#16010**, **#15635**).

**Confidence:** High. **Inferred** (recurrent across reviews).

## 3.11 No-no list (explicit)

- **No `print` in Rust.** `println!` and `eprintln!` are denied workspace-wide via clippy.
- **No `--no-verify`** on commits in CI flows; format checks block merge.
- **No undocumented args** on public functions (D417 enforced).
- **No undisclosed AI-tool use.** CONTRIBUTING.md mandates AI/LLM disclosure in PR body
  (template updated in **#15924**); see `10-maintainer-preferences.md` for enforcement record.
