---
name: qiskit-qpy-compatibility
description: Walk through a Qiskit QPY format-version bump — add a fixture under `test/qpy_compat/`, increment the format version in both Python and Rust, ensure round-trip on the corpus, and add a reno entry under `features_qpy` or `upgrade_qpy`. Use whenever the user touches `qiskit/qpy/`, `crates/qpy/`, adds a new serializable type, or asks how to bump the QPY version. QPY round-trip bugs are the #2 recurring bug category in Qiskit; the `qpy.yml` workflow gates merge.
---

# Qiskit QPY backward-compatibility

QPY is Qiskit's binary serialization format for circuits. The format is versioned, the corpus is in `test/qpy_compat/`, and the `qpy.yml` workflow runs the compat suite on every PR. QPY round-trip bugs are the **#2 recurring bug category** (§8.2): seven format / round-trip / Rust-port bugs in the last 6 months alone (#15623, #15649, #15847, #16076, #15663, #15158, #15934).

## When you need this skill

- Adding a new instruction or annotation that needs to be serializable.
- Changing how an existing type is serialized.
- Adding metadata to QPY headers.
- Fixing a round-trip bug.
- Bumping the format version for any reason.

## The recurring traps

These are the bug shapes that repeatedly slip past review:

1. **Rust `bytes` vs Python `bytes`** — different size encodings, endianness, gzip stream framing (#15158, #15847).
2. **User-defined registers named `'ancilla'`** clashing with reserved register names (#15623).
3. **Annotations** not handled in the Rust path even though they were added on the Python side (#15649).
4. **`ParameterExpression`** historical encoding lossy compared to the Polish-form rewrite (#15934).
5. **Integer durations on `Delay`** quietly losing the type tag (#16076).

## Checklist for a format bump

### 1. Increment the format version in both Python and Rust

Two locations. They must match:

- `qiskit/qpy/common.py` — find the `QPY_VERSION` constant.
- `crates/qpy/src/...` — find the equivalent constant in the Rust port.

If either is missed, the loader will accept the new bytes but mis-interpret them.

### 2. Add a fixture under `test/qpy_compat/`

`test/qpy_compat/` contains scripts that generate fixtures with the **previous** format version and a corpus that the workflow loads back. The pattern (read existing `test/qpy_compat/` fixtures for shape):

- A small generator script that creates circuits exercising the new feature, dumps them under the *old* version (so the new code can read old files), AND under the *new* version (so old code's behaviour on new files can be validated).
- A reference dump committed under the right corpus directory (typically a hash-named binary file).
- Round-trip assertions: dump → load → re-dump and verify equality.

### 3. Round-trip test in Python

`test/python/qpy/` holds the unit tests (separate from the version-corpus tests). Add a test that:

```python
class TestNewFeature(QiskitTestCase):

    def test_round_trip(self):
        qc = QuantumCircuit(...)  # with the new feature
        with io.BytesIO() as buf:
            qpy.dump(qc, buf)
            buf.seek(0)
            loaded = qpy.load(buf)[0]
        self.assertEqual(qc, loaded)

    def test_back_compat_load(self):
        # Load a fixture that was dumped at format-version N-1 and
        # confirm the new code reads it correctly.
        with open("test/qpy_compat/fixtures/some_old_v13_dump.qpy", "rb") as f:
            loaded = qpy.load(f)[0]
        self.assertEqual(loaded, expected)
```

### 4. Round-trip test in Rust

If the Rust port also handles the new field, add a `#[test]` under `crates/qpy/src/...` that round-trips through the Rust path. Cargo tests run via `tox -erust` and `cargo test`.

### 5. Reno entry

Under `features_qpy` for additions or `upgrade_qpy` for behavior changes that affect users with old QPY files. State the new format version explicitly. See [[qiskit-release-notes]].

```yaml
---
features_qpy:
  - |
    QPY format version is now 14, adding support for serializing
    user-defined annotations on circuit instructions. Files written
    by qiskit 2.5+ require qiskit 2.5+ to load; older files continue
    to load correctly.
```

### 6. Test gzip and non-gzip paths

`qpy.dump` accepts both raw and gzip streams. #15158 fixed `qpy.dump` failing with gzip write streams. Always test with **both**:

```python
import gzip

with io.BytesIO() as buf:
    qpy.dump(qc, buf)
    buf.seek(0)
    self.assertEqual(qpy.load(buf)[0], qc)

with io.BytesIO() as buf:
    with gzip.open(buf, "wb") as gz:
        qpy.dump(qc, gz)
    buf.seek(0)
    with gzip.open(buf, "rb") as gz:
        self.assertEqual(qpy.load(gz)[0], qc)
```

### 7. CI workflow

`qpy.yml` runs on every PR and is a required check. If it fails, read the workflow log first — most failures are missing fixtures or version mismatches between Python and Rust.

## Heuristics

- **Bump the format version even for "compatible" additions** if the byte stream changes. Loaders use the version to decide which path to take.
- **Never re-use a version number.** Always increment monotonically; don't reorder if a release shipped with a given version.
- **Backwards compatibility is non-negotiable.** New code must read old files. The loader picks the parser by version.
- **Forward compatibility is best-effort.** Old code reading new files may fail with a clear error message, never silently produce a wrong circuit.
- **Annotations and metadata are first-class** — handle them in both Python and Rust paths.

## Related skills

- [[qiskit-release-notes]] — `features_qpy` / `upgrade_qpy` YAML.
- [[qiskit-good-pr-checklist]] — confirms fixture and reno entry exist.
- [[qiskit-py-rust-bridge]] — when the Rust port needs a new submodule.
- [[qiskit-bug-triage]] — for round-trip bugs, category 8.2.
