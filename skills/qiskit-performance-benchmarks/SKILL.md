---
name: qiskit-performance-benchmarks
description: Use Qiskit's ASV benchmarks (`test/benchmarks/`) to produce before/after numbers for any PR that touches a heuristic, hot path, or default. Generates the table format reviewers ask for and writes the matching `Changelog: Performance` reno entry. Use whenever the user is changing a transpiler heuristic, parallelizing a pass, optimizing Rust code, modifying Sabre / BasisTranslator / synthesis, or asks "how do I prove this is faster?". Empirical justification for heuristic changes is Mandatory — the Sabre lookahead PR #14911 went through three review rounds because the contributor kept skipping this.
---

# Qiskit performance benchmarks

For any PR that changes a transpiler heuristic, parallelizes a pass, or modifies a hot Rust path, reviewers (alexanderivrii in particular) require benchmark numbers. This is **Mandatory** (§11.7.2) even when the reviewer agrees with the intuition: alexanderivrii on #14911 (Sabre lookahead): *"I would really love to see some experimental data. Even though I am on board with the intuition behind the new heuristic, we don't want to risk making sabre accidentally worse."*

## When you need this skill

- Changing a transpiler heuristic (Sabre cost function, layout heuristic, BasisTranslator priority).
- Parallelizing a pass (e.g. #16014 CommutationAnalysis).
- Replacing a serial Rust path with `par_iter`.
- Migrating Rust matrix code from scipy → nalgebra/faer (#15960, #15881, #15874, …).
- Changing a default value that affects perf (e.g. approximation degrees, optimization level defaults).

## Tool: ASV (`test/benchmarks/`)

Qiskit uses [Airspeed Velocity](https://github.com/airspeed-velocity/asv). Configuration: `asv.conf.json:21`. Benchmarks are organized by area:

```
test/benchmarks/
├── circuit_construction.py
├── synthesis.py
├── transpiler_levels/
├── compilation/
├── ...
```

## Running benchmarks

`asv` runs benchmarks across a configurable matrix of git revisions. Typical workflow for a PR:

```bash
# 1. Make sure you have asv installed (it's part of the dev group).
pip install --group dev   # or pip install asv

# 2. Run benchmarks for two revisions: main, and your branch.
cd test/benchmarks
asv run main..HEAD --steps 2

# 3. Compare them.
asv compare main HEAD --factor 1.05 --machine <name>

# 4. Or generate a single before/after run.
asv continuous main HEAD --factor 1.05
```

`--factor 1.05` flags any benchmark that moved by more than 5% — both wins and regressions.

For a focused change, use `--bench` (regex on benchmark name):

```bash
asv continuous main HEAD --bench "Sabre" --factor 1.05
```

## Output format reviewers want

Include the table in the **PR body**, not just as a reno entry. Format observed across #16014, #15881, #15960:

```markdown
### Benchmarks

ASV `continuous` on a 27-qubit transpile workload, level 3, 8-core x86_64.
Lower is better.

| Benchmark                                          | main (ms) | branch (ms) | Δ      |
|----------------------------------------------------|-----------|-------------|--------|
| `transpile.TranspileLevel3.time_transpile_qv_27`   | 1840 ± 30 | 1410 ± 25   | -23%   |
| `transpile.TranspileLevel3.time_transpile_qft_27`  | 920 ± 18  | 690 ± 12    | -25%   |
| `synthesis.Decomposer.time_two_qubit_decomp`       | 4.2 ± 0.1 | 4.0 ± 0.1   | -5%    |

Hardware / methodology: <one line — machine, number of repetitions>.
```

Notes:

- **State methodology** in one line: machine, ASV iteration count, what was held constant.
- **Include error bars** (ASV reports them; `mean ± stddev` or just `± stddev`).
- **Negative deltas are wins** (lower latency); always state the convention.
- **Don't cherry-pick.** If three benchmarks regressed and seven improved, show all ten.

## Required: `Changelog: Performance` label and reno entry

For any speed/memory change, add the `Changelog: Performance` label (added in #16065, driven by #16014). Write a `performance:` reno entry — see [[qiskit-release-notes]].

```yaml
---
performance:
  - |
    :class:`.CommutationAnalysis` now runs in parallel using rayon.
    On 27-qubit benchmark circuits the pass is roughly 4x faster on
    an 8-core machine. See `#16014
    <https://github.com/Qiskit/qiskit/pull/16014>`__ for benchmark
    detail.
```

## PGO training-circuit caveat (§11.7.6)

Profile-guided optimization training circuits live somewhere visible (referenced via build configuration). #15931 inflated a PGO QV training circuit from 100→193 qubits, which dramatically slowed PGO collection. **#16146 reverted it.** If you change PGO training inputs, treat that as a separate (and potentially regressing) change.

## Heuristics

- **Run benchmarks more than once.** A single run has too much noise. ASV's default repetition count (`--repeat`) is fine; for noisy benchmarks bump it.
- **Use realistic workloads.** Transpile level 3 on a 27-qubit QV circuit is the canonical example. A toy 4-qubit Bell circuit doesn't tell you anything.
- **Compare apples to apples.** Use the same machine, same Python version, same Rust profile (`release`, never `debug`). Don't run benchmarks under tox unless tox is configured for release.
- **Don't claim wins from variance.** A 2% change with 5% stddev is noise; reviewers will spot it.
- **For Rust microbenchmarks** (the level below ASV), `criterion` is also acceptable when the change is in a single Rust function and ASV is too coarse.

## Related skills

- [[qiskit-rust-performance-idioms]] — what to actually change in the Rust code.
- [[qiskit-release-notes]] — the `performance:` YAML.
- [[qiskit-pr-preparation]] — `Changelog: Performance` label.
- [[qiskit-determinism-audit]] — when the win comes from parallelism.
- [[qiskit-good-pr-checklist]] — checks the benchmark table is in the PR body.
