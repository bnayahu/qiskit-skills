---
name: qiskit-determinism-audit
description: Audit a Qiskit change that adds parallelism (rayon `par_iter`, `concurrent.futures`) for ordering non-determinism. Walks the patterns that caused #15410 (parallel sort revert) and #15040 (DAG edge-order). Use whenever the user adds `par_iter`, `par_sort`, `par_chunks`, threading, or asks "is this safe to parallelize?". Determinism over raw speed is Mandatory in Qiskit (§11.8.2) — non-deterministic parallelism gets reverted.
---

# Qiskit determinism audit

Qiskit's rule (§11.8.2, **Mandatory**): parallel implementations must preserve a deterministic output order. Reverts that prove the rule:

- **#15410** "Stop using a parallel sort in disjoint utils" — the parallel sort produced different orderings on different runs.
- **#15040** Fixed edge-order non-determinism when adding DAG nodes.

This skill audits a parallel change for the patterns that historically broke determinism.

## When to run this audit

Any diff that adds:

- `rayon::iter::par_iter()`, `into_par_iter()`, `par_sort*`, `par_chunks*`, `par_extend`.
- `concurrent.futures.ThreadPoolExecutor`, `ProcessPoolExecutor`, `ThreadPool`.
- `qiskit/utils/parallel.py` callers (`parallel_map`).
- Multi-threaded native code anywhere in `crates/`.

## The four ordering hazards

### 1. Parallel sort with non-total ordering

`par_sort_unstable` is non-deterministic when the comparator has ties. **#15410** hit exactly this. If the keys can tie (e.g. sort by qubit index where multiple gates sit on the same qubit), use `par_sort` (stable) or follow with a tiebreaker.

```rust
// Bad: ties resolve non-deterministically
gates.par_sort_unstable_by_key(|g| g.qubit_index());

// Good: deterministic tiebreaker on insertion order
gates.par_sort_by(|a, b| {
    a.qubit_index().cmp(&b.qubit_index())
        .then(a.dag_index().cmp(&b.dag_index()))
});
```

### 2. Collecting from `par_iter` into a `HashMap` / `HashSet`

Default hash maps (`std::collections::HashMap`, Python `dict` after 3.7 actually preserves insertion order — but don't rely on that across language boundaries) iterate in non-deterministic order even when the contents are identical. If the consumer reads back via iteration, the ordering is unstable.

```rust
// Bad: parallel collect into a HashMap → downstream iteration order varies
let m: HashMap<_, _> = items.par_iter().map(|x| (key(x), val(x))).collect();
for (k, v) in &m { /* order varies! */ }

// Good: collect into a Vec, sort once if needed
let mut v: Vec<_> = items.par_iter().map(|x| (key(x), val(x))).collect();
v.sort_by(|a, b| a.0.cmp(&b.0));
```

If you really need a map, use an `IndexMap` (`indexmap` crate, already in the workspace via rustworkx).

### 3. Inserting into a shared graph from multiple threads

`#15040` was an edge-order non-determinism in DAG node addition: edges were added by multiple threads and their order in the adjacency lists varied. Two safe patterns:

- **Compute in parallel, mutate sequentially.** `par_iter` to produce `Vec<Edge>`, then add them to the graph in a single-threaded loop.
- **Sort before commit.** If you must insert from multiple threads, sort the produced edges by a deterministic key before inserting.

### 4. Floating-point reductions

`par_iter().sum::<f64>()` is non-deterministic in the last few bits because addition is not associative on floats. For most circuit costs this is fine; for SVD residuals, fidelity comparisons, or anything that the test suite checks bit-exact, it's a bug.

```rust
// Best: serial sum if exactness matters
let s: f64 = vals.iter().sum();

// Acceptable if a few-ULP difference is tolerable
let s: f64 = vals.par_iter().sum();
```

## Audit checklist

For a diff that adds parallelism:

1. **What's the output type?** If it's a `Vec` or fixed-size array constructed by `par_iter().collect()`, rayon preserves input ordering — safe.
2. **Are there hash maps in the parallel path?** If yes, replace with `IndexMap` or sort the output.
3. **Are there sorts?** If yes, are the keys total? If not, add a tiebreaker.
4. **Is there shared state being mutated under a `Mutex`/`RwLock`?** If yes, the order of acquisition is non-deterministic.
5. **Are floats being summed/reduced?** If yes, decide whether ULP differences are acceptable; the test suite usually surfaces this.
6. **Are tests deterministic?** Run the test suite a few times — `tox -epy311 -- test.python.transpiler.test_<your_pass> --repeat 5` (or run by hand). Any test that flakes proves determinism is broken.

## What to do when in doubt

If you can't easily prove determinism, **don't parallelize that piece**. The Qiskit pattern is "compute the heavy work in parallel, commit serially." For a transpiler pass:

```python
def run(self, dag):
    # Parallel: compute per-node decisions
    with parallel_map(...) as pool:
        decisions = pool.map(self._decide, dag.op_nodes())
    # Serial: apply them in DAG order
    for node, dec in zip(dag.op_nodes(), decisions):
        self._apply(dag, node, dec)
    return dag
```

## Reno entry for parallelism

Behavior-changing parallelism gets `Changelog: Performance` and a perf reno entry (§11.8.4). State the parallelism explicitly so users with non-deterministic-sensitive workflows know to inspect.

```yaml
---
features_transpiler:
  - |
    :class:`.CommutationAnalysis` now runs in parallel using rayon.
    Output ordering is preserved; the parallelism is purely internal.
```

## Related skills

- [[qiskit-rust-performance-idioms]] — broader Rust patterns.
- [[qiskit-performance-benchmarks]] — required ASV table for the speedup claim.
- [[qiskit-release-notes]] — `Changelog: Performance` YAML.
- [[qiskit-good-pr-checklist]] — runs this audit when `par_iter` shows up in the diff.
