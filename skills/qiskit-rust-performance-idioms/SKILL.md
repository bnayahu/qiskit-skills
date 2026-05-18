---
name: qiskit-rust-performance-idioms
description: Apply Qiskit's hot-path Rust idioms — avoid `expect`/panics, prefer fixed-size arrays over `SmallVec`/`Vec` when N is statically known, use `try_inverse_mut()` and other in-place ops, prefer `numpy`/`nalgebra`/`faer` over `scipy` in Rust. Use whenever the user is writing or reviewing Qiskit Rust code in `crates/`, especially in performance-sensitive crates (`qiskit-circuit`, `qiskit-transpiler`, `qiskit-synthesis`, `qiskit-quantum-info`). These are the recurring nits mtreinish and jakelishman ask for in review.
---

# Qiskit Rust performance idioms

These are the patterns reviewers (mtreinish, jakelishman, alexanderivrii) repeatedly ask contributors to apply. None are CI-enforced beyond the workspace clippy denies, but missing them is a near-certain review round-trip.

## 1. No `expect` / panic on user-reachable paths (§11.3.4)

User-reachable Rust panics surface as opaque Python tracebacks and are treated as bugs.

- **#16010** "Replace infallible `expect` with compile-time checks in VF2".
- **#15635** "Avoid panics in Quantum Shannon Decomposition Rust code".
- **#16054** panic on parameterized global phase.

**Patterns:**

```rust
// Bad: expect on user data
let m: Matrix2<Complex64> = SOME_MAP.get(&key).expect("present").clone();

// Better: propagate via Result, surface as QiskitError
let m: Matrix2<Complex64> = SOME_MAP
    .get(&key)
    .ok_or_else(|| QiskitError::new_err(format!("unknown key {key}")))?
    .clone();

// Best when the invariant is structural: encode it in the type
// (e.g. enum variants, NonZeroU32, fixed-size arrays).
```

`unwrap()` is not categorically banned, but it's worse than `expect` because there's no message at all — prefer `?` propagation or restructuring.

## 2. Don't allocate when you can stack-allocate (§11.7.3)

mtreinish in **#16123**: *"Since this is always 4 matrices you don't need the smallvec … allocating a vec is extra overhead we don't need yet."*

```rust
// Bad: heap allocation when N is known
let mut mats: SmallVec<[Matrix2<Complex64>; 4]> = SmallVec::new();
for ... { mats.push(m); }

// Good: fixed-size array on the stack
let mats: [Matrix2<Complex64>; 4] = [m0, m1, m2, m3];
```

For matrix inverses use **in-place** operations:

```rust
// Bad: allocate-and-invert
let inv = m.try_inverse().ok_or_else(|| singular_err())?;

// Good: in-place
let mut m = m;
if !m.try_inverse_mut() { return Err(singular_err()); }
// m is now the inverse
```

## 3. Don't reimplement existing iterators (jakelishman, #15999)

> *"In principle I think this is sound … but I would rather just make `nodes_on_wire` the iterator natively than largely duplicating its logic."*

If the data structure already has an iterator, extend it (add a method, expose a different starting point) rather than copying its loop body into a new function.

## 4. Prefer `numpy` / `nalgebra` / `faer` over `scipy` in Rust (§11.7.5)

Active migration in the last 6 months: #16016, #15960, #15874, #15881, #15928, #15871. `scipy` is fine in Python paths, but in Rust the preferred matrix libraries are:

- **`numpy`** (the rust-numpy crate) — when the matrix lives in NumPy already.
- **`nalgebra`** — small fixed-size dense linear algebra (`Matrix2`, `Matrix4`, etc.).
- **`faer`** — large dense / sparse linear algebra; SVD, eigendecomposition.

When porting from Python → Rust, **don't** call back into Python `scipy` from the Rust path; pick a Rust crate instead.

## 5. Workspace clippy denies (§3.1)

Configured in `Cargo.toml:71-86`:

- `deny(print_stdout)` — no `println!`.
- `deny(print_stderr)` — no `eprintln!`.
- `deny(unsafe_op_in_unsafe_fn)` — every unsafe op inside an `unsafe fn` must be in its own `unsafe { … }` block.
- `allow(comparison_chain)` — `if a < b { … } else if a > b { … }` is fine.

`#16128` enabled clippy on tests too (`--all-targets`), so test code is held to the same standard.

For diagnostics, use `tracing` or `log` if you really need it; for development, comment out before commit. The clippy lint is the reason rolling cleanup PRs (#15280, #15107, #15716, #15804, #16052) keep happening.

## 6. Use `import_exception!` for Python-facing errors (§11.3.5)

```rust
use pyo3::prelude::*;
use pyo3::import_exception;

import_exception!(qiskit.exceptions, QiskitError);
import_exception!(qiskit.exceptions, TranspilerError);

fn do_thing() -> PyResult<()> {
    if bad { return Err(QiskitError::new_err("...")); }
    Ok(())
}
```

This gives Python users the right exception type. Don't return `PyValueError` for a domain error.

## 7. Be deliberate about parallelism (§11.8.2, §11.8.3)

- **Rayon is the default.** New parallel work uses `par_iter`, not custom thread pools.
- **Output ordering must be deterministic.** A parallel sort that broke ordering was reverted (#15410). DAG node insertion order non-determinism was fixed (#15040).
- **Behavior-changing parallelism needs a `Changelog: Performance` reno entry** (§11.8.4).

If you're adding `par_iter`, hand off to [[qiskit-determinism-audit]].

## 8. PyO3 idioms

- `Python::with_gil(|py| { … })` for ad-hoc GIL access.
- `pyo3 = "0.28.3"` with `abi3-py310` (stable ABI) — match the workspace pin (`Cargo.toml:53`).
- `Qubit`, `Clbit`, `Var`, `Block` are transparent `u32` newtypes; convert via `FromPyObject`.
- Don't import Python submodules at Rust ext init time (§11.2.2). `import_exception!` is the documented exception.

## 9. Static-knowledge wins

When N is small and known:

```rust
// Bad: dynamic vector for the same 4 elements every call
let v: Vec<f64> = (0..4).map(...).collect();

// Good: array on the stack, no allocation
let v: [f64; 4] = std::array::from_fn(...);
```

When the input shape determines the output shape:

```rust
// Use generic const expressions or N-dim arrays where supported
fn rotate<const N: usize>(mat: [[f64; N]; N]) -> [[f64; N]; N] { ... }
```

## Heuristics

- **Profile before optimizing.** ASV benchmarks live in `test/benchmarks/` (see [[qiskit-performance-benchmarks]]). Don't move a hot path to nalgebra without the before/after numbers.
- **Hot path = appears in pgo training circuits or transpile() flame graphs.** Cold path = startup, error paths, one-shot construction. The rules above are hot-path-specific.
- **`Cargo.lock` must be current.** PR #15839 added a Cargo.lock currency check in lint. After any `Cargo.toml` change, run `cargo update -p <crate>` (or `cargo build`) and commit `Cargo.lock`.

## Related skills

- [[qiskit-coding-conventions]] — Rust formatting (rustfmt) and clippy rules.
- [[qiskit-determinism-audit]] — when adding `par_iter`.
- [[qiskit-performance-benchmarks]] — required ASV before/after for any hot-path change.
- [[qiskit-error-handling]] — `import_exception!` and exception class choice.
- [[qiskit-py-rust-bridge]] — when adding a new crate or submodule.
