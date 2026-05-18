---
name: qiskit-security-review
description: Apply Qiskit's security checklist for C API / FFI / unsafe-Rust code — every `unsafe` block has a justification, no `expect`/panic on user-reachable paths, miri passes on the path where it can run, UBSan via `make ctest` covers FFI, public C API surface gated by Doxygen `\qk_deprecated{}` for evolving paths (pre-3.0 C API is explicitly unstable). Use whenever the user is touching `crates/cext/`, `crates/cext-vtable/`, `unsafe` Rust blocks, or FFI boundaries; review-time check for memory-safety hazards.
---

# Qiskit security review

Qiskit's security surface is concentrated in the C API and unsafe Rust. The python side has no `eval`/`exec` of user input and no privilege boundaries. This skill focuses on the FFI / unsafe paths where safety is structural.

## Scope

Run this skill on PRs touching:

- `crates/cext/`, `crates/cext-vtable/`, `crates/bindgen/`.
- Any `unsafe { ... }` block in Rust.
- `test/c/` and `make ctest` paths.
- `extern "C"` functions or types crossing FFI.

Pre-3.0, the C API is **explicitly unstable** (`DEPRECATION.md:258-304`). Deprecations are best-effort; the surface may break at any minor.

## Checklist

### 1. Every `unsafe` block has a justification

The workspace clippy denies `unsafe_op_in_unsafe_fn` — even inside an `unsafe fn`, every unsafe operation must be in its own `unsafe { ... }` block. Each block should have a comment on the line above explaining *why* the operation is safe:

```rust
// SAFETY: `ptr` was just constructed from `Box::into_raw` and is valid
// for reads and writes for the lifetime of `obj`. No other reference
// exists because `obj` was just consumed.
unsafe {
    *ptr = new_value;
}
```

If you can't write a 1–2 sentence safety justification, the operation probably isn't safe.

### 2. No `expect`/panic on user-reachable paths (§11.3.4)

Panics across FFI are undefined behavior. Replace with:

- `?` propagation through `Result`.
- Compile-time invariants (NonZero types, fixed-size arrays).
- Explicit error returns to C callers (set an error code, return null pointer, etc.).

Prior PRs: #16010 (replaced `expect` with compile-time checks in VF2), #15635 (panics in QSD), #16054 (panic on parametric global phase). All three were treated as panic-class bugs.

### 3. miri passes (where it can)

`miri.yml` is a required check. Miri cannot model FFI — FFI tests are **excluded**. So a green miri run does **not** prove the FFI path is safe. For FFI:

- Run UBSan via `make ctest` (the C API test suite).
- Add pure-Rust unit tests that exercise the unsafe block without crossing FFI.

#15049 ("Fix UB invocation in `SparseObservable` C API test") is the canonical case — UB in a Rust path surfaced through the C test, not through miri.

### 4. C API surface gating

Public C functions are declared in `crates/bindgen/include/qiskit/`. The bindgen tool generates these from Rust `#[no_mangle] extern "C"` functions. Mark evolving entry points:

- Rust: `#[deprecated(since = "x.y", note = "...")]` propagates to the C header via cbindgen.
- Doxygen: use `\qk_deprecated{version|reason}` in the documentation comment.

Pre-3.0, contributors can change C signatures more freely than Python signatures, but should still mark deprecation when reasonable.

### 5. Memory ownership clarity

For each function that takes or returns a pointer, document:

- **Who allocates?** (caller / callee / static)
- **Who frees?** (and via which function)
- **Aliasing rules.** (exclusive / shared)
- **Lifetime.** (until next call to X, until process exit, etc.)

Mismatched expectations between C callers and Rust callees are the #1 source of FFI bugs. #16113 fixed `restype` for void-returning C functions — a small mismatch that can corrupt the stack.

### 6. Integer overflow on size types

C uses `size_t` (`usize`); Rust often uses `u32` for circuit-domain types. Conversions on the FFI boundary need explicit overflow checks. Use `try_into()` and propagate on `Err`, never `as u32` on a value that might exceed 32 bits.

### 7. Null pointer handling

For every `extern "C" fn` accepting a pointer, the first line of the implementation should check null and return an error code:

```rust
#[no_mangle]
pub extern "C" fn qk_obj_method(obj: *const Obj, ...) -> i32 {
    if obj.is_null() {
        return QK_ERR_NULL_POINTER;
    }
    // SAFETY: null check passed; caller contract requires `obj` be valid.
    let obj = unsafe { &*obj };
    // ...
}
```

### 8. C tests cover the new surface

`test/c/` holds CMake-built C tests. `make ctest` builds and runs them. Any new C entry point gets:

- A "happy path" test.
- A "null pointer in" test.
- A "boundary value" test (zero, max).

UBSan flags use-after-free, OOB access, integer UB. Run locally:

```bash
make c        # generate headers
make clib     # build the library
make ctest    # build and run C tests with UBSan
```

### 9. cbindgen artifacts

If you change the public C surface, regenerate the headers:

```bash
make c
git diff crates/bindgen/include/qiskit/   # confirm only the expected changes
```

Don't hand-edit the generated headers; they're rebuilt from Rust source.

## Common hazards

### a. Double-free across FFI

Pattern: Rust returns a `*mut T` from `Box::into_raw`; the C caller forgets to call `qk_obj_free` and the Rust side `Box::from_raw`s a stale pointer later. Document ownership transfer at every entry/exit.

### b. Aliasing into a `Vec`'s buffer

Pattern: Rust returns `vec.as_mut_ptr()` to C, then mutates the `Vec` (which may reallocate). The C-held pointer is now dangling. Rule: don't expose `Vec` buffers across FFI; copy into a stable allocation.

### c. UB on integer overflow

Rust's `usize → i32` cast wraps in release; in debug it panics. Use `try_from()` and convert `Err` to a clear error code.

### d. Panics across the FFI boundary

Rust panics propagated into C frames are UB. Wrap every `extern "C"` body in `std::panic::catch_unwind` and return an error code on panic, OR ensure no panic can fire (no `unwrap`, no `expect`, no array indexing without bounds check).

## Heuristics

- **Read the surrounding C tests before writing the Rust.** They show what assertions the user is allowed to make.
- **Panic-free is the goal.** When in doubt, prefer an error code over an `unwrap`.
- **Ownership transfer always crosses one direction at a time.** Don't return a pointer that the caller is supposed to free *and* that Rust still holds a reference to.
- **The C API is unstable pre-3.0.** Don't pretend it's frozen; mark deprecations and move forward.

## Related skills

- [[qiskit-rust-performance-idioms]] — no-panic / no-`println!` / fixed-size arrays.
- [[qiskit-debugging]] — miri vs UBSan; the FFI carve-out.
- [[qiskit-error-handling]] — `import_exception!` (Python side) and error codes (C side).
- [[qiskit-bug-triage]] — §8.7 panics/leaks, §8.8 C API/FFI categories.
- [[qiskit-ci-workflows]] — `miri.yml`, `ctests.yml`.
