# 11. Implicit Engineering Conventions

A cross-cutting synthesis of conventions that are **not** stated in any single
`CONTRIBUTING.md`/`MAINTAINING.md`/`DEPRECATION.md` paragraph but are uniformly applied across
the codebase, observable in PR review, and load-bearing for "does this PR feel like Qiskit
code?" judgements.

Each convention is rated on a four-tier scale:

- **Mandatory** — CI gates the rule, or reviewers consistently reject PRs that violate it.
- **Preferred** — reviewers ask for it; deviations get changed or justified, but won't block
  merge if the deviation is principled.
- **Historical/obsolete** — visible in older code but no longer the way new code is written;
  do not propagate.
- **Disputed** — different maintainers prefer different things; expect review-time discussion.

For convenience, conventions cite their primary section in earlier playbook documents rather
than re-stating evidence already collected there.

---

## 11.1 Naming patterns

### 11.1.1 Single-letter / domain-shorthand gate filenames — **Preferred**

**Rule.** Standard-gate modules under `qiskit/circuit/library/standard_gates/` use the gate's
canonical short name as the filename (`x.py`, `h.py`, `rz.py`, `rxx.py`, `xx_minus_yy.py`),
and the class name is the capitalized form with `Gate` suffix (`XGate`, `HGate`, `RZGate`,
`XXMinusYYGate`).

**Evidence.** `qiskit/circuit/library/standard_gates/` directory listing (every file follows
the pattern); also `_standard_gate = StandardGate.X` attribute on each class linking to the
Rust enum (see § 7.1).

**Counterexamples.** None in `standard_gates/`. Outside of standard gates, generated /
parametric circuit families use longer descriptive names (`QFT`, `MCXGate`, `TwoLocal`).

### 11.1.2 Rust crate names use `qiskit-` prefix; Python packages do not — **Mandatory**

**Rule.** Every Cargo workspace member is named `qiskit-<role>` (`qiskit-circuit`,
`qiskit-transpiler`, `qiskit-pyext`, …); the in-repo Python package is `qiskit/` with
sub-packages named without prefix.

**Evidence.** `crates/README.md:20-63`, `Cargo.toml:1-70` (see § 1.2).

**Counterexamples.** None.

### 11.1.3 Test files mirror source layout under `test/python/<package>/test_<module>.py` — **Preferred**

**Rule.** Module under test → `test/python/<package>/test_<module>.py`. Class is `Test*`,
methods are `test_*` (`unittest` convention). Many decorated with `@enforce_subclasses_call`.

**Evidence.** § 2.2 *Naming conventions*; consistent across `test/python/`.

**Counterexamples.** Cross-cutting suites (`test/python/compiler/`, `test/qpy_compat/`,
`test/randomized/`, `test/ipynb/mpl/`) are organized by concern, not by source mirror.

### 11.1.4 Reno filename `<slug>-<deterministic-hash>.yaml` — **Mandatory**

**Rule.** Release-note filenames are reno-generated: `<short-slug>-<hash>.yaml` (e.g.
`mimalloc-403d3300aa698fae.yaml`, `msrv-187-fe3d9818f5c4103d.yaml`). After a release branch
is cut, files move under `releasenotes/notes/x.y/`.

**Evidence.** § 6.6.

**Counterexamples.** None — `reno new` generates the hash; hand-naming is not done.

### 11.1.5 Private/dunder convention — **Preferred**

**Rule.** Single-underscore (`_field`) for module-internal; double-underscore name-mangling
(`__x`) is rare and reserved for true subclassing hazards. `_accelerate` (the Rust extension)
is the canonical example: leading underscore signals "import path is private even though it's
reachable" — see DEPRECATION.md:40-56 *public API is what is documented* (§ 6.4).

**Evidence.** Uniform across `qiskit/`; reinforced by DEPRECATION.md's import-path carve-out.

**Counterexamples.** None significant.

---

## 11.2 Layering boundaries

### 11.2.1 `qiskit-circuit` is the data-model floor; nothing above it imports a transpiler/synthesis crate — **Mandatory**

**Rule.** Dependency direction is one-way: `qiskit-pyext` → `qiskit-transpiler` →
{`qiskit-circuit`, `qiskit-synthesis`, `qiskit-quantum-info`} → `qiskit-util`. `qiskit-circuit`
does not import `qiskit-transpiler` or `qiskit-synthesis`. `qiskit-accelerate` is intentionally
the catch-all leaf (`crates/README.md:28-29`: *"end of dependency tree"*).

**Evidence.** § 1.5 dependency graph; transitive `[dependencies]` in each `crates/*/Cargo.toml`.

**Counterexamples.** None observed. Reviewer pushback on "wrong-layer fix" PRs (#16062,
#16116 — see § 9.5 / § 10.2) shows the rule is enforced socially as well as structurally.

### 11.2.2 Rust extension code must not import Python submodules at init time — **Mandatory**

**Rule.** During `_accelerate` load, Rust code may not call into Python submodules (avoids
circular imports). The `import_exception!` macro is the documented exception
(`crates/accelerate/src/lib.rs:13-24`).

**Evidence.** `crates/README.md:56-63` (§ 1.3).

**Counterexamples.** None — the rule is structural; violations surface as import-time errors.

### 11.2.3 Modules organized by domain, not abstraction layer — **Preferred**

**Rule.** `circuit/` mixes IR + gate definitions + parameter system; `transpiler/` owns *all*
transformation logic; `synthesis/` owns *all* algorithms. Users `from qiskit.<domain>` rather
than `from qiskit.<layer>`.

**Evidence.** § 1.6.

**Counterexamples.** `qiskit/utils/` and `qiskit/exceptions.py` are layer-shaped, not
domain-shaped — small intentional exceptions.

### 11.2.4 `QuantumCircuit` is the universal exchange format — **Preferred**

**Rule.** Every subsystem either consumes, produces, or transforms `QuantumCircuit`.
Synthesis returns `QuantumCircuit`, transpiler I/O is `QuantumCircuit`, primitives accept it.

**Evidence.** § 1.6.

**Counterexamples.** Internal Rust code may handle `CircuitData` directly; `DAGCircuit` is the
internal exchange format inside the transpiler. Both are intentional internal substitutions.

### 11.2.5 The single-`cdylib` rule (one `.so`, manual `sys.modules` registration) — **Mandatory**

**Rule.** `qiskit/__init__.py:49-146` registers each Rust submodule into `sys.modules`. New
Rust submodules added to `pyext` need a matching line here.

**Evidence.** § 7.9 (and § 1.3).

**Counterexamples.** None — adding a submodule without the registration line breaks imports.

---

## 11.3 Error handling

### 11.3.1 Domain-specific subclasses of `QiskitError`, not bare `Exception` / `ValueError` — **Preferred**

**Rule.** Raise `QiskitError` (or a domain subclass — `TranspilerError`, `CouplingError`,
`CircuitError`, `QASMError`) rather than `ValueError` / `RuntimeError` / bare `Exception`.

**Evidence.** § 7.3; `qiskit/exceptions.py:90-100`. Quantitative check:
`raise QiskitError|TranspilerError|CircuitError ≈ 764` occurrences vs.
`raise ValueError|TypeError ≈ 374` — Qiskit-specific raises dominate but Python builtins are
used at boundaries (~33% of raise sites).

**Counterexamples.** `ValueError` / `TypeError` are still used at user-facing argument
boundaries when the error is a pure type/value mismatch with no domain context. This is not
flagged in review — i.e. the rule is "domain errors get domain types", not "all errors must
be QiskitError".

### 11.3.2 `MissingOptionalLibraryError` extends both `QiskitError` and `ImportError` — **Mandatory**

**Rule.** Multiple inheritance is deliberate so `except ImportError:` blocks still catch the
optional-dependency case.

**Evidence.** `qiskit/exceptions.py:109-134` (§ 7.3).

**Counterexamples.** None — changing the MRO would silently break user code.

### 11.3.3 No `pydantic` / `typeguard` runtime validators — **Preferred**

**Rule.** Boundary validation is manual `isinstance()` checks raising `QiskitError`
subclasses. Type hints exist for documentation/tooling, not enforcement.

**Evidence.** § 3.6, § 7.5; reviewer Cryoris in #15832.

**Counterexamples.** None — adding a runtime validator dependency would face strong
review pushback (see also § 11.10).

### 11.3.4 No `expect`/panics in Rust on user-reachable paths — **Preferred** (heading toward Mandatory)

**Rule.** Replace `expect`/panics with compile-time checks, `?` propagation, or `Result`s.
Rust errors cross to Python via `import_exception!` so users see `QiskitError`, not a panic.

**Evidence.** § 7.8, § 9.5; PRs **#16010** (VF2), **#15635** (Quantum Shannon), **#16054**
(panic on parameterized global phase). § 8.7 lists panic-class bugs as a recurring category.

**Counterexamples.** Panics still exist in older Rust paths; cleanup is incremental.
Considered "Preferred" today, "Mandatory" for new code.

### 11.3.5 Rust → Python exception bridging via `import_exception!` — **Mandatory**

**Rule.** Each Rust crate that surfaces errors to Python uses
`import_exception!(qiskit.exceptions, QiskitError)` so PyErr returns produce the right Python
class.

**Evidence.** `crates/accelerate/src/lib.rs:13-24` (§ 1.3, § 7.3).

**Counterexamples.** None observed.

---

## 11.4 Logging style

### 11.4.1 Module-local `logger = logging.getLogger(__name__)` — **Preferred**

**Rule.** Each module that logs declares `logger = logging.getLogger(__name__)` at top of
file (after imports). Use `%s`/`%d`-style format strings passed as args, not f-strings — so
formatting is deferred until the level is enabled.

**Evidence.**
- `qiskit/passmanager/base_tasks.py:24`
- `qiskit/passmanager/flow_controllers.py:24`
- `qiskit/compiler/transpiler.py:32`
- `qiskit/passmanager/passmanager.py:30`
- `qiskit/visualization/circuit/circuit_visualization.py:53`
- `qiskit/transpiler/passes/optimization/elide_permutations.py:22`

Format-string style:
- `qiskit/passmanager/base_tasks.py:108` —
  `logger.info("Pass: %s - %.5f (ms)", self.name(), running_time * 1000)`
- `qiskit/providers/providerutils.py:108` —
  `logger.warning("Backend '%s' is deprecated. Use '%s'.", name, resolved_name)`

**Counterexamples.** `qiskit/utils/optionals.py:247` aliases `import logging as _logging`
inside the optional-deps module to avoid a public `logging` re-export — the only file that
deviates from the bare `import logging` form.

### 11.4.2 No `print` / `println!` / `eprintln!` for user-visible output — **Mandatory**

**Rule.** Workspace-wide clippy `deny(print_stdout, print_stderr)` for Rust;
`T20` ruff rule selected (`pyproject.toml:318-496`) bans `print` in Python library code.
User-visible diagnostic output goes through `logging` or `warnings.warn`.

**Evidence.** § 3.1, § 3.11, § 7.8.

**Counterexamples.** None in library code. Test code may print for diagnostics if not
captured by `QISKIT_TEST_CAPTURE_STREAMS`.

### 11.4.3 `warnings.warn` for user-facing soft signals; `logger` for runtime instrumentation — **Preferred**

**Rule.** Deprecation, experimental-feature, and "user is doing something we'd prefer they
didn't" notices go through `warnings.warn` with a `QiskitWarning` subclass. Pass-manager
timing, transpilation progress, fallback decisions go through `logger.info`/`logger.warning`.

**Evidence.** ~44 `warnings.warn` sites across `qiskit/`; logger sites tend to cluster in
`compiler/`, `passmanager/`, `providers/`, `visualization/`, `transpiler/`. § 7.4 deprecation
decorators always go through `warnings.warn`.

**Counterexamples.** None significant — the two channels carry different information by
design.

---

## 11.5 Testing expectations

### 11.5.1 Bug fix without a regression test → reviewer asks for one — **Mandatory**

**Rule.** Every bug fix PR must include a test that fails before the fix and passes after.
Reviewers reject PRs where the reproducer "almost works" or where the fix doesn't address
the cited reproducer (#16124 closed).

**Evidence.** § 9.2, including #16124, #15967, #15815, #15672/#15673, #15494.

**Counterexamples.** Pure refactor / rename / dependency bump PRs have no reproducer
requirement (they carry `Changelog: None`).

### 11.5.2 Deprecation tests must cover both paths — **Mandatory**

**Rule.** One test asserts the old code path emits the warning (`assertWarns`); a second
asserts the new path is warning-free. `QiskitTestCase` treats `DeprecationWarning` as an
error by default, so missing the second test fails CI.

**Evidence.** § 7.4, § 9.7; CONTRIBUTING.md:928-953; `test/utils/base.py:91`.

**Counterexamples.** None — single-path PRs are rejected in review.

### 11.5.3 Control-flow test for any pass that could see `ControlFlowOp` — **Preferred** (close to Mandatory)

**Rule.** New transpiler passes must descend into `ControlFlowOp.blocks`; reviewers ask for
a test using nested `IfElseOp`/`ForLoopOp`/`WhileLoopOp`/`BreakLoopOp` if the pass touches
DAG nodes.

**Evidence.** § 8.1 (recurring bug category), § 9.8 (item 7); PRs #15875, #15581/#15626,
#15413, #15083, #15143, #15155, #15941, #15147.

**Counterexamples.** Passes that operate purely on the property-set (analysis-only on
metadata) often skip this; reviewers accept it without a control-flow test.

### 11.5.4 QPY round-trip test on a corpus — **Mandatory**

**Rule.** Any QPY format change must add a fixture in `test/qpy_compat/` and pass the
`qpy.yml` workflow.

**Evidence.** § 7.10, § 8.2.

**Counterexamples.** None.

### 11.5.5 Visual snapshot regen must be visually justified — **Preferred**

**Rule.** mpl drawer changes are checked against `test/ipynb/mpl/` baselines. Reviewers ask
for the new baselines to be inspected, not just regenerated.

**Evidence.** § 8.5 (#15973, #16074, #16080); image-tests workflow gates merge.

**Counterexamples.** None observed.

### 11.5.6 No mocks for cross-language behavior — **Preferred**

**Rule.** Tests that exercise Rust↔Python behavior call into the real extension; mocking the
Rust side is not a pattern that appears.

**Evidence.** Inferred — there is no `unittest.mock`-of-Rust pattern in `test/python/`.
CONTRIBUTING.md:699-711 documents that Rust tests can call Python via `Python::with_gil`,
reinforcing "use the real boundary".

**Counterexamples.** None significant.

---

## 11.6 API compatibility discipline

### 11.6.1 Public API ≠ importable surface — **Mandatory**

**Rule.** *Public API* is what is documented in the Sphinx pages. Reachable-by-import paths
that are not in the docs are not part of the contract and may move. Removing
`qiskit.circuit.measure` (private) without a deprecation cycle is allowed; removing
`qiskit.circuit.Measure` (documented) is not.

**Evidence.** DEPRECATION.md:40-56 (§ 6.4).

**Counterexamples.** None — the rule is invoked when contributors object to "private path"
moves.

### 11.6.2 Two-version compatibility window for any deprecation — **Mandatory**

**Rule.** Old + new code paths must coexist for at least two consecutive minors with zero
warnings on the new path; deprecation warning runs at least one minor before removal;
minimum 3-month removal timeline; removals only in major releases.

**Evidence.** § 6.4; DEPRECATION.md:29,32.

**Counterexamples.** Experimental APIs (those raising `ExperimentalWarning`) are exempt and
may break at any minor — see § 6.5.

### 11.6.3 Use deprecation decorators, never hand-rolled `warnings.warn` for deprecation — **Preferred**

**Rule.** `@deprecate_func` / `@deprecate_arg` / `@deprecate_arg_default` from
`qiskit/utils/deprecation.py` are the only sanctioned mechanism. They auto-insert
`.. deprecated:: x.y` Sphinx blocks and standardize the warning class.

**Evidence.** § 7.4, § 7.11.

**Counterexamples.** A few historical sites still call `warnings.warn(DeprecationWarning(...))`
directly — these are progressively migrated. Treat hand-rolled deprecation as
**Historical/obsolete** for new code.

### 11.6.4 QPY format-version bumps are gated by version numbers and `test/qpy_compat/` — **Mandatory**

**Rule.** New QPY format versions add fixture data and a `features_qpy` / `upgrade_qpy`
reno entry.

**Evidence.** § 7.10.

**Counterexamples.** None.

### 11.6.5 Changelog label is mandatory at merge — **Mandatory**

**Rule.** Every PR carries exactly one `Changelog: <X>` label; `qiskit_bot.yaml` maps it to
the release-note section. `Changelog: None` is acceptable for refactors/CI/dep bumps.

**Evidence.** § 5.5, § 9.1, § 6.6. Examples of `Changelog: None`: #15716, #15839, #16128,
#16101, #16019, #15989, #15952.

**Counterexamples.** None — release tooling depends on it.

---

## 11.7 Performance tradeoffs

### 11.7.1 Rust for hot paths; Python for orchestration — **Preferred**

**Rule.** When something is profile-hot, port it to Rust. The reverse migration (Rust →
Python) is unheard of. The rate of Python→Rust ports has been steady through the sample
window.

**Evidence.** § 1.1; recent ports / improvements: #15960, #15881, #15874, #15928, #15871,
#15910–#15915 (two-qubit decomposer).

**Counterexamples.** Some new code lands Python-first when correctness is the immediate
concern; Rust port is a follow-up. Maintainers explicitly accept this sequencing.

### 11.7.2 Empirical justification required for heuristic / hot-path changes — **Mandatory**

**Rule.** PRs that change a transpiler heuristic or a hot path need benchmark data. ASV
benchmarks live in `test/benchmarks/` and reviewers ask for numbers.

**Evidence.** § 9.6 (#14911 Sabre lookahead — alexanderivrii repeatedly: *"I would really
love to see some experimental data"*), § 9.8 item 6, § 10.2 (#16014, #14719, #15881 praised
for benchmark backing).

**Counterexamples.** None — even when reviewers accept the intuition, they still ask for
data before merge.

### 11.7.3 Avoid spurious heap allocations in Rust hot paths — **Preferred**

**Rule.** Use fixed-size arrays (`[T; N]`) when N is statically known; prefer in-place ops
(`try_inverse_mut()`); don't reach for `SmallVec` / `Vec` reflexively.

**Evidence.** § 7.8, § 9.5; #16123 (mtreinish).

**Counterexamples.** Allocations are tolerated in cold paths; the rule is hot-path-specific.

### 11.7.4 Performance-changelog category is a real signal — **Preferred**

**Rule.** Performance-affecting PRs get `Changelog: Performance` (added in #16065, driven by
#16014). A `Performance` reno entry is usually requested.

**Evidence.** § 5.5, § 9.1.

**Counterexamples.** Trivially-small perf wins sometimes ride under `Changelog: None` if no
user-visible behavior changes.

### 11.7.5 `numpy` / `nalgebra` / `faer` preferred over `scipy` in Rust paths — **Preferred**

**Rule.** Active migration away from `scipy` for Rust matrix work.

**Evidence.** § 7.8, § 9.5; #16016, #15960, #15874, #15881, #15928, #15871.

**Counterexamples.** Python paths still use `scipy` freely. The rule is Rust-specific.

### 11.7.6 PGO benchmarks are part of the perf surface — **Preferred**

**Rule.** Profile-guided optimization training circuits are kept small/representative.
Inflating training inputs is a regression — see #15931 (PGO QV circuit 100→193 qubits)
reverted in #16146.

**Evidence.** § 8.11, § 10.5.

**Counterexamples.** None.

---

## 11.8 Concurrency patterns

### 11.8.1 No `async` / `await` anywhere in `qiskit/` — **Mandatory**

**Rule.** `grep -r "async def\|await " qiskit/` returns zero matches. Concurrency is
`concurrent.futures`-based via `qiskit/utils/parallel.py`.

**Evidence.** § 1.6, § 7.6.

**Counterexamples.** None.

### 11.8.2 Determinism over raw speed when ordering matters — **Mandatory**

**Rule.** Parallel implementations must preserve a deterministic order. Parallel sort that
broke ordering was reverted (#15410). Edge-order non-determinism in DAG node addition was
fixed in #15040.

**Evidence.** § 7.6, § 8.9.

**Counterexamples.** None — non-determinism gets reverted.

### 11.8.3 Rayon is the default Rust parallelism — **Preferred**

**Rule.** `rayon` is in `[workspace.dependencies]`; new parallel work uses rayon's
`par_iter`. No custom thread-pool patterns.

**Evidence.** `Cargo.toml:16-69`.

**Counterexamples.** None significant.

### 11.8.4 Behavior-changing parallelism needs a perf reno entry — **Preferred**

**Rule.** When a pass becomes parallel (e.g. CommutationAnalysis in #16014), the PR adds a
`Changelog: Performance` and a corresponding reno entry.

**Evidence.** § 9.1.

**Counterexamples.** None observed.

---

## 11.9 Abstraction preferences

### 11.9.1 Decorators carry behavior; classes carry state — **Preferred**

**Rule.** Cross-cutting concerns are added as decorators (`@deprecate_func`,
`@with_gate_array`, `@enforce_subclasses_call`, `@stdlib_singleton_key`) rather than via
mixin classes or metaclass tricks. The `MetaPass` metaclass is the rare exception (auto-
hashes `BasePass` constructor args for pass-manager dedup).

**Evidence.** § 7.11; `qiskit/transpiler/basepasses.py:29-100`.

**Counterexamples.** `MetaPass` itself, plus `SingletonGate` which uses both metaclass and
decorator. Both are intentional.

### 11.9.2 `from __future__ import annotations` everywhere; modern union syntax — **Mandatory**

**Rule.** Universal at module top in `qiskit/`. Type hints use `int | float | None`, not
`Union` / `Optional`. `if TYPE_CHECKING:` guards break circular imports.

**Evidence.** § 3.6, § 7.5.

**Counterexamples.** A handful of test files don't use the future import; not flagged in
review for tests.

### 11.9.3 Don't widen / narrow types reflexively — **Preferred**

**Rule.** Cryoris in #15832: *"Why change from `Iterable` to `set`? That seems more
restrictive."* Match the type hint to actual call-site flexibility, not to the most concrete
runtime type.

**Evidence.** § 9.4.

**Counterexamples.** None — recurring review feedback.

### 11.9.4 Singleton gates over per-call instantiation — **Preferred**

**Rule.** `SingletonGate` ensures one canonical instance; identity-based equality; reduces
memory.

**Evidence.** § 7.1; `qiskit/circuit/singleton.py`.

**Counterexamples.** Parameterized gates (`RXGate(theta)`) are not singletons; this is by
design.

### 11.9.5 Auto-hash constructor args for pass-manager dedup — **Mandatory**

**Rule.** `MetaPass` metaclass auto-hashes `BasePass` constructor args so the pass manager
deduplicates equivalent passes.

**Evidence.** § 7.2; `qiskit/transpiler/basepasses.py:29-100`.

**Counterexamples.** None.

### 11.9.6 Boilerplate-proliferation is a smell — **Preferred**

**Rule.** Reviewers prefer one general PR over many parallel narrow ones. jakelishman in
#15279: *"is there a less-boilerplate way to expand this?"*. Narrow special-case PRs get
closed in favor of the general form (#16064).

**Evidence.** § 9.6, § 10.2, § 8.10.

**Counterexamples.** Discrete bug fixes are kept separate even when similar — the rule is
about feature work, not bug clusters.

---

## 11.10 Dependency avoidance

### 11.10.1 Don't add a runtime dep without a one-liner justification — **Preferred**

**Rule.** New runtime deps must justify "why isn't `numpy`/`scipy`/`rustworkx` enough?".
Loose lower bounds (`>=`) only; upper bounds only when a known break exists.

**Evidence.** § 4.1, § 4.8.

**Counterexamples.** `numpy < 3` is the only forward upper bound currently; pre-emptive
upper-bounding is not done.

### 11.10.2 Optional deps are imported inside functions, not at module top — **Mandatory**

**Rule.** Module-top import of an optional dep would crash users without it. Use
`qiskit.utils.optionals` lazy testers + function-local import + `MissingOptionalLibraryError`.

**Evidence.** § 3.5, § 7.7; CONTRIBUTING.md:978-983.

**Counterexamples.** None at the user-facing module level.

### 11.10.3 Linter / doc-generator versions are pinned tightly; libraries loosely — **Mandatory**

**Rule.** `ruff==0.15.2`, `black[jupyter]~=25.1`, `setuptools-rust==1.12.0`, `Sphinx==9.1.0`,
`docutils==0.22.4` — anything that controls CI behavior is exact-pinned. Runtime libs use
`>=`.

**Evidence.** § 3.1, § 4.3.

**Counterexamples.** None — drift would silently change CI verdicts.

### 11.10.4 `constraints.txt` only when forced — **Preferred**

**Rule.** Each `constraints.txt` entry is a workaround for a specific known upstream
problem (`scipy < 1.11` for old Pythons, `z3-solver==4.12.2.0` on macOS,
`snowballstemmer < 3.0.0` for Sphinx).

**Evidence.** § 4.4.

**Counterexamples.** None.

### 11.10.5 No `pre-commit` framework — **Preferred** (deliberate non-adoption)

**Rule.** `.pre-commit-config.yaml` is absent. CI/tox is the gate. Local lint loop is
`tox -elint`.

**Evidence.** § 2.3.

**Counterexamples.** None.

### 11.10.6 Major Rust crate moves are hand-authored, not Dependabot — **Preferred**

**Rule.** Dependabot is for routine bumps. Major Rust crate substitutions (`scipy` → `faer`
/ `nalgebra`) are deliberate hand-authored PRs.

**Evidence.** § 4.7.

**Counterexamples.** None.

---

## 11.11 Code review expectations

### 11.11.1 Maintainers route by area — **Preferred**

**Rule.** `qiskit_bot.yaml` pings module experts. PRs reach the right reviewer faster if they
touch one area. Mixed-area PRs trigger multi-maintainer review and tend to slow down.

**Evidence.** § 5.5, § 10.6.

**Counterexamples.** None.

### 11.11.2 Concise, human-written PR descriptions; no LLM bloat — **Mandatory**

**Rule.** Tight summary, no "Validation" subsection (CI's job), no 300-line root-cause
walkthroughs. AI/LLM use must be disclosed; volume of unsupervised LLM PRs gets the author
blacklisted (#16039, #16060, #16062, #16079, #16125, #16127, #15994 closures by jakelishman).

**Evidence.** § 9.3, § 10.3; PR template updated in #15924.

**Counterexamples.** None — closures are unambiguous.

### 11.11.3 `Fixes #N` exact phrasing required — **Mandatory**

**Rule.** Use the exact `Fixes #N` GitHub auto-close phrasing. CONTRIBUTING.md flags this
as a hard requirement.

**Evidence.** § 6.8, § 9.8 item 4.

**Counterexamples.** None.

### 11.11.4 Backport label triggers Mergify — **Preferred**

**Rule.** User-visible bug fixes get `stable backport potential`; Mergify opens the backport
PR; `backport.yml` syncs labels.

**Evidence.** § 5.4; examples #16155, #15431, #15728, #15884.

**Counterexamples.** Features and refactors are not backported even when they apply cleanly.

### 11.11.5 Wait a week before re-pinging a maintainer — **Preferred**

**Rule.** Courtesy-tagging convention from CONTRIBUTING.md.

**Evidence.** § 10.6.

**Counterexamples.** Critical bug / release-blocker exceptions exist but are rare.

### 11.11.6 Close > partially merge — **Preferred**

**Rule.** Maintainers prefer to close a half-correct fix and ask for a clean redo over
merging-with-followup. They guide engaged contributors via inline comments first; closure
follows only after structural disagreement (#16116, #16124, #16064).

**Evidence.** § 10.4.

**Counterexamples.** None — the closed-without-merge taxonomy in § 10.4 is dominated by
closure rather than soft rejection.

### 11.11.7 AI/LLM disclosure box on every PR — **Mandatory**

**Rule.** PR template asks; missing-disclosure PRs get a request to re-instate (#15994).
Volume + missing disclosure is the blacklist trigger; AI use *with* disclosure and human
ownership is acceptable.

**Evidence.** § 10.3.

**Counterexamples.** None — operational consequence is a closure.

### 11.11.8 Don't fix at the wrong abstraction layer — **Mandatory**

**Rule.** A symptom in module A whose root cause is in module B gets fixed in B. jakelishman
in #16062: *"This is not a correct fix, because the root fault is not in the exporter but in
the importer."*

**Evidence.** § 9.8 item 1, § 10.2.

**Counterexamples.** None — wrong-layer fixes get closed.

---

## 11.12 Disputed / weak conventions

A small set of conventions that reviewers genuinely disagree on:

### 11.12.1 `from __future__ import annotations` vs. `if TYPE_CHECKING:` — **Disputed**

Cryoris in #15832 prefers `if TYPE_CHECKING:` guards over the future import to keep diffs
minimal in some files. Most of the codebase uses both. Either is accepted.

### 11.12.2 Single combined typo-sweep PR vs. many small ones — **Disputed**

The `ihincks` series landed many tiny typo PRs and merged. But the reviewer feedback on
#15279 (*"is there a less-boilerplate way to expand this?"*) signals a preference for sweeps.
Practice has not converged.

### 11.12.3 Where to land Python-first vs. Rust-first new features — **Disputed**

Some maintainers prefer correctness-first Python with a Rust port follow-up. Others prefer
Rust-from-the-start when the code is obviously hot. There is no single canonical sequencing.

---

## 11.13 Historical / obsolete patterns

Patterns that show up in older code but should not be propagated:

- **Hand-rolled `warnings.warn(DeprecationWarning(...))`** — superseded by `@deprecate_func`
  / `@deprecate_arg` decorators (§ 11.6.3).
- **`Union[X, Y]` / `Optional[X]` type hints** — superseded by `X | Y` / `X | None` modern
  union syntax (§ 11.9.2).
- **`println!` / `eprintln!` for debugging in committed Rust** — banned by clippy
  workspace-wide (§ 11.4.2).
- **Module-top-level optional-dependency imports** — banned by CONTRIBUTING.md:978-983
  (§ 11.10.2).
- **Parallel sort in `disjoint utils`** — reverted in #15410; non-determinism is not an
  acceptable trade for speed (§ 11.8.2).
- **Inflated PGO QV training circuit (193 qubits)** — reverted in #16146 (§ 11.7.6).

---

## 11.14 Summary table

| # | Convention | Tier |
|---|---|---|
| 11.1.1 | Single-letter / domain-shorthand gate filenames | Preferred |
| 11.1.2 | `qiskit-` prefix on Rust crates only | Mandatory |
| 11.1.3 | Tests mirror source layout | Preferred |
| 11.1.4 | Reno hash filenames | Mandatory |
| 11.1.5 | Single-underscore privacy | Preferred |
| 11.2.1 | One-way crate dependency direction | Mandatory |
| 11.2.2 | No Python imports during Rust ext init | Mandatory |
| 11.2.3 | Domain-organized modules | Preferred |
| 11.2.4 | `QuantumCircuit` as universal exchange | Preferred |
| 11.2.5 | Single-cdylib + manual `sys.modules` | Mandatory |
| 11.3.1 | `QiskitError` subclasses for domain errors | Preferred |
| 11.3.2 | `MissingOptionalLibraryError` dual-inherits `ImportError` | Mandatory |
| 11.3.3 | No runtime type validators | Preferred |
| 11.3.4 | No `expect`/panics in user-reachable Rust | Preferred (→ Mandatory) |
| 11.3.5 | Rust→Python via `import_exception!` | Mandatory |
| 11.4.1 | `logger = logging.getLogger(__name__)` per module | Preferred |
| 11.4.2 | No `print` / `println!` in library code | Mandatory |
| 11.4.3 | `warnings.warn` vs. `logger` channels | Preferred |
| 11.5.1 | Bug fixes need regression tests | Mandatory |
| 11.5.2 | Both deprecation paths tested | Mandatory |
| 11.5.3 | Control-flow tests for transpiler passes | Preferred |
| 11.5.4 | QPY round-trip fixtures | Mandatory |
| 11.5.5 | Visual-snapshot regen scrutinized | Preferred |
| 11.5.6 | No mocks across language boundary | Preferred |
| 11.6.1 | Public API = documented surface | Mandatory |
| 11.6.2 | Two-version compatibility window | Mandatory |
| 11.6.3 | Use deprecation decorators | Preferred |
| 11.6.4 | QPY format-version gating | Mandatory |
| 11.6.5 | Changelog label at merge | Mandatory |
| 11.7.1 | Rust for hot paths | Preferred |
| 11.7.2 | Empirical justification for heuristics | Mandatory |
| 11.7.3 | Avoid heap allocations in hot Rust | Preferred |
| 11.7.4 | `Changelog: Performance` | Preferred |
| 11.7.5 | Prefer numpy/nalgebra/faer over scipy in Rust | Preferred |
| 11.7.6 | Don't inflate PGO training circuits | Preferred |
| 11.8.1 | No async/await | Mandatory |
| 11.8.2 | Determinism over speed | Mandatory |
| 11.8.3 | Rayon as default | Preferred |
| 11.8.4 | Perf reno entry for parallelism | Preferred |
| 11.9.1 | Decorators for cross-cutting concerns | Preferred |
| 11.9.2 | `from __future__ import annotations` + modern unions | Mandatory |
| 11.9.3 | Don't widen/narrow types reflexively | Preferred |
| 11.9.4 | Singleton gates | Preferred |
| 11.9.5 | Auto-hash pass constructor args | Mandatory |
| 11.9.6 | Boilerplate-proliferation smell | Preferred |
| 11.10.1 | Justify new runtime deps | Preferred |
| 11.10.2 | Optional deps inside functions | Mandatory |
| 11.10.3 | Tools pinned tight, libs pinned loose | Mandatory |
| 11.10.4 | `constraints.txt` only when forced | Preferred |
| 11.10.5 | No pre-commit framework | Preferred |
| 11.10.6 | Major Rust crate moves hand-authored | Preferred |
| 11.11.1 | Route PRs to specialists | Preferred |
| 11.11.2 | No LLM bloat in PR descriptions | Mandatory |
| 11.11.3 | `Fixes #N` exact phrasing | Mandatory |
| 11.11.4 | Backport label → Mergify | Preferred |
| 11.11.5 | Week before re-pinging | Preferred |
| 11.11.6 | Close > partially merge | Preferred |
| 11.11.7 | AI/LLM disclosure box | Mandatory |
| 11.11.8 | Fix at the right layer | Mandatory |

**Tier counts:** Mandatory **23**, Preferred **30**, Disputed **3**, Historical/obsolete **6**.

The high Mandatory count clusters in **CI-gated mechanics** (deprecation, QPY, changelog,
tests) and **structural rules** (crate layering, single-cdylib, ext-init); Preferred dominates
**stylistic and review-culture** rules. Disputed and Historical categories are small —
this codebase has converged.
