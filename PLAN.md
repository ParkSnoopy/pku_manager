# Development Plan

This plan defines change order and release evidence for the current architecture.

## Authorities

- `pubspec.yaml` and `pubspec.lock`: SDK, package version, and dependency authority.
- `CONTEXT.md`: vocabulary, behavioral invariants, source boundaries, and platform-support meaning.
- `ARCHITECTURE.md`: dependency direction, module ownership, persistence, and runtime flow.
- `docs/REFERENCE_CASES.md`: pinned external provenance and independently authored behavior coverage.
- `.github/workflows/native.yml`: supported build, package, smoke-test, artifact, and release commands.

When authorities disagree, inspect source and tests, then update every affected document in the same change. Do not preserve historical implementation status in normative files.

## Change sequence

### 1. Define the contract

- Express product terminology and cross-layer invariants in `CONTEXT.md` before changing ownership or serialized state.
- Identify the authoritative identity for every relationship, source cell, generated color, and persistence key.
- Keep in-app copy limited to end-user decisions, actions, correction, recovery, and current state.
- Keep repository documents limited to developer-relevant interfaces, architecture, structure, workflows, constraints, and evidence.

### 2. Change domain policy

- Put timetable ordering, source-cell separation, conflict, parity, date, and relationship rules in `lib/domain/`.
- Keep domain values immutable and independent from Flutter and infrastructure packages.
- Represent finite states with typed values instead of string checks or nullable-field bags.
- Add focused domain coverage for normal, boundary, and invalid cases.

### 3. Change data boundaries

- Keep workbook decoding and layout recognition behind `schedule_xls_parser.dart`.
- Preserve exact imported bytes and stable source identities across every parser or schema change.
- Parse and validate complete candidates before publication.
- Apply authoritative source, parsed rows, corrections, derived records, and active selection in one SQLite transaction.
- Keep Week Parity fetch/parse/cache failure independent from timetable persistence.
- Evolve application-owned storage through typed columns and explicit contracts; do not introduce JSON schema substitutes.

### 4. Change feature coordination

- Let controllers coordinate repositories and immutable domain projections without reimplementing parser or date policy.
- Keep side effects behind injectable, consumer-owned boundaries.
- Serialize authoritative mutations by target; keep advisory refresh and presentation paths side-effect free.
- Update localization for every changed visible string in Korean, English, and Simplified Chinese.

### 5. Change presentation and export together

- Reuse one timetable geometry, appearance, content-role, and typography authority for screen, PNG, and XLSX.
- Preserve responsive wide/narrow semantics without introducing feature-local data models.
- Keep manual appearance keyed by stable source identity and derive display labels from authoritative records.
- Test rendered structure and export semantics at the shared boundary rather than duplicating one-off format logic.
- Perform real runtime inspection when visual behavior changes; widget tests alone do not establish production typography or native-window behavior.

### 6. Change platform integration

- Keep native runners thin and product logic in Dart.
- Regenerate plugin registrants through Flutter tooling after dependency changes; never add application logic to generated files.
- Resolve desktop resources executable-relative and verify packaged, not source-tree, paths.
- For Linux AppImage changes, verify bundled non-baseline libraries, `$ORIGIN` lookup, extracted AppImage launch, direct AppDir launch, and runtime tray-icon staging.
- For Android release changes, verify a monotonically increasing derived version code and packaged identity.
- For Windows installer changes, verify install, stale-payload replacement during upgrade, registered version/location metadata, installed launch, and uninstall against the complete release bundle.
- For Apple changes, build macOS, iOS device, and iOS simulator outputs and exercise runtime behavior on macOS hardware or CI where required.

## Validation contract

### Source checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

- Domain files retain infrastructure-free imports.
- Source contains no runtime or development access to `elective.pku.edu.cn`.
- Import tests prove source-BLOB equality before and after correction/edit flows.
- Parser tests account for every populated in-scope source cell or reject the candidate explicitly.
- Reference tests remain independently authored and mapped to `docs/REFERENCE_CASES.md`.
- No unsanitized workbooks, generated build trees, temporary probes, or unapproved copied source enter the diff.

### Platform evidence

| Target | Required evidence |
|---|---|
| Android | Release APK, increasing derived version code, and application-ID inspection |
| iOS | Unsigned device build, simulator build, and runtime exercise on an Apple runner/device |
| Linux | Release bundle, AppImage assembly, bounded packaged launch, direct AppDir dependency resolution, and user-data reload |
| macOS | Release application bundle and runtime exercise on macOS |
| Windows | Release bundle, versioned NSIS build, install/upgrade with stale-payload removal, registry inspection, installed launch, and uninstall |

Compilation, packaging, launch, and feature-path verification are separate assertions. Record only evidence produced from the same source revision.

## Parser acceptance

Synthetic matrices protect format branches but cannot establish BIFF8 compatibility. Before claiming parser compatibility:

1. Obtain an explicitly approved sanitized real PKU export without accessing the elective site.
2. Keep personal or course-sensitive workbooks outside source control.
3. Run the existing opt-in fixture path and verify every in-scope nonempty cell is parsed or reported.
4. Verify Chinese text, line breaks, paired rows, tutorial details, exams, period bounds, and source-byte equality through production adapters.

## Release gate

A release is eligible only when:

- the package version comes from `pubspec.yaml` and changes only with related executable source changes;
- schema version `1` remains backward-compatible for every `0.1.x` release, and any breaking successor waits for a manually authorized minor-version update;
- all source checks pass;
- each published target provides its required platform evidence;
- artifact names and release target refer to the same source revision;
- Android releases use a version code derived from the regular package version;
- AppImage and NSIS outputs come from source-controlled packaging definitions;
- runtime storage remains in platform application-support paths across install/upgrade/restart;
- no source, test, workflow, artifact, or document contains unsanitized schedule data; and
- documentation describes current technical contracts without end-user feature instructions or stale implementation history.