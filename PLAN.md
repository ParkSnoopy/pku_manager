# PKU Manager Implementation Plan

## Goal

Build an offline-first school life management application for Android, Linux, and Windows. Its first complete feature set imports and retains a user-supplied PKU `schedule.xls`, renders a polished timetable, and filters odd-week and even-week classes using semester dates published by the Week Parity project.

## Current Context

- Repository is a clean Flutter 3.47.2 starter project on `main` at version `0.0.1`.
- `lib/main.dart` and `test/widget_test.dart` still contain Flutter counter-template code.
- Android, Linux, and Windows Flutter runners already exist.
- No application architecture, persistence layer, parser, packaging definitions, or relevant tests exist.
- The deployed Week Parity application currently reads `https://parksnoopy-undergraduate.github.io/week/config.toml`.
- The supplied Week Parity repository URL currently resolves inconsistently and must not be treated as a stable runtime dependency.
- The elective prettifier supports legacy one-row and newer paired-row timetable layouts, but its source is AGPL-3.0.
- A sanitized real `schedule.xls` fixture is required before parser compatibility can be accepted.

## Product and Safety Constraints

- Never request, scrape, probe, authenticate to, or embed `elective.pku.edu.cn`.
- Users obtain `schedule.xls` themselves and import it through a native file picker.
- Keep the imported `schedule.xls` as the authoritative timetable source.
- Keep all timetable processing local; network access is limited to public Week Parity configuration.
- Do not silently omit malformed or unsupported class records.
- Preserve Monday through Sunday even if a reference renderer hides weekends.
- Use a native Flutter interface rather than a WebView around either reference site.
- Avoid copying AGPL-licensed implementation unless the project explicitly adopts compatible licensing obligations or obtains permission.
- Do not choose a spreadsheet dependency permanently until it parses a sanitized real export successfully.
- Keep implementation small and direct; add abstraction only around filesystem, file selection, time, and network boundaries that require deterministic tests.

## Architecture

### Application Layer

- `lib/app/app.dart`: application root, theme, dependency construction, and startup state.
- `lib/app/home_page.dart`: responsive shell and timetable-focused home surface.
- `lib/main.dart`: minimal entry point that launches the application root.

### Domain Layer

- `lib/domain/week_frequency.dart`: typed `every`, `odd`, `even`, and `unknown` frequency values plus visibility rules.
- `lib/domain/semester.dart`: semester start, Beijing calendar date, week number, and parity calculations.
- `lib/domain/course_meeting.dart`: normalized course name, weekday, period range, room, frequency, note, and exam information.
- `lib/domain/timetable.dart`: ordered meetings, period bounds, day grouping, and consecutive-cell grouping.

Domain objects remain independent of Flutter widgets, filesystems, HTTP, and spreadsheet packages.

### Data Layer

- `lib/data/week_config_parser.dart`: strict parser for ordered semester dates and supported timezone from `config.toml`.
- `lib/data/week_config_repository.dart`: last-known-good cache, bounded public fetch, refresh state, and atomic cache replacement.
- `lib/data/schedule_xls_parser.dart`: spreadsheet-adapter boundary that recognizes supported PKU layouts and returns a normalized timetable.
- `lib/data/schedule_repository.dart`: candidate validation, authoritative file storage, startup reload, and atomic replacement.
- `lib/data/app_paths.dart`: application-support paths supplied through `path_provider`.
- `lib/data/schedule_picker.dart`: native `.xls` acquisition supplied through `file_picker`.

The repository stores only authoritative `schedule.xls` bytes and the last valid Week Parity configuration. Parsed timetable state is regenerated rather than duplicated in durable storage.

### Feature Layer

- `lib/features/timetable/timetable_controller.dart`: startup loading, import coordination, parity refresh, preview mode, and error states.
- `lib/features/timetable/timetable_page.dart`: responsive timetable page.
- `lib/features/timetable/timetable_grid.dart`: desktop and wide-screen weekly grid.
- `lib/features/timetable/day_schedule.dart`: compact selected-day presentation for narrow screens.
- `lib/features/timetable/week_status.dart`: semester week, parity, freshness, and refresh status.
- `lib/features/schedule_import/schedule_import_action.dart`: import affordance and user-facing validation failures.

### Runtime Data Flow

- Startup loads and parses stored `schedule.xls` when present.
- Startup calculates parity from cached Week Parity configuration, then attempts a bounded refresh.
- Successful refresh replaces the cache only after complete validation.
- Import reads a bounded candidate, parses it fully, writes a temporary file, atomically replaces the prior source, then publishes the parsed timetable.
- Failed refresh retains the last valid parity data and reports stale or unavailable state.
- Failed import leaves the prior timetable unchanged.
- Timetable visibility is derived from selected preview mode and each meeting's typed frequency.

## Dependencies

- Add `file_picker` for native Android, Linux, and Windows file selection.
- Add `path_provider` for application-support storage.
- Evaluate `excel2003` first because it is a pure-Dart, zero-dependency BIFF8 reader matching the declared `.xls` format.
- Replace or supplement the parser only if a sanitized real PKU export proves that its bytes or workbook features are unsupported.
- Use `dart:io` HTTP support unless testing or platform behavior demonstrates a need for a separate HTTP package.
- Retain generated plugin registrants produced by Flutter dependency resolution.

## Ordered Work

### 1. Establish Domain Contracts

- Replace the counter test in `test/widget_test.dart` only after equivalent application smoke coverage exists.
- Create `lib/domain/week_frequency.dart` and `test/domain/week_frequency_test.dart`.
- Parse only exact `每周`, `单周`, and `双周` tokens; map all other values to `unknown`.
- Verify every frequency against odd, even, and unfiltered preview modes.
- Create `lib/domain/semester.dart` and `test/domain/semester_test.dart`.
- Verify semester start day, Sunday boundary, next Monday, odd/even transitions, pre-semester dates, and Beijing-date handling.
- Create `lib/domain/course_meeting.dart` and `lib/domain/timetable.dart`.
- Verify stable ordering, Monday-through-Sunday retention, period bounds, and consecutive meeting grouping.

### 2. Implement Week Configuration

- Create `lib/data/week_config_parser.dart` and `test/data/week_config_parser_test.dart`.
- Validate required keys, supported timezone, nonempty dates, ISO calendar dates, uniqueness, and ascending order.
- Create `lib/data/week_config_repository.dart` with injected fetch, cache, clock, and timeout boundaries.
- Accept only a successful HTTPS response from the exact Week Parity config URL.
- Bound response size and reject redirects outside the allowed host.
- Preserve the previous cache after malformed, oversized, timed-out, or failed responses.
- Report whether current parity came from fresh data, cached data, or no usable data.
- Add Android Internet permission in `android/app/src/main/AndroidManifest.xml`.
- Test fresh fetch, valid cache fallback, invalid cache, network failure, redirect rejection, and atomic replacement.

### 3. Confirm Spreadsheet Compatibility

- Obtain one sanitized, representative `schedule.xls` directly from the user; never fetch it from the elective site.
- Record it under `test/fixtures/` only after the user confirms all personal and course-sensitive content has been removed.
- Add the provisional spreadsheet dependency to `pubspec.yaml` and resolve `pubspec.lock` normally.
- Create a focused adapter probe in `test/data/schedule_xls_parser_test.dart`, not a temporary script.
- Confirm workbook signature, sheet discovery, row and column values, Chinese text, line breaks, empty cells, and both timetable layouts represented by available fixtures.
- Keep `excel2003` only if this evidence passes; document any required replacement before broader parser work.

### 4. Implement Timetable Parsing

- Create `lib/data/schedule_xls_parser.dart` around one spreadsheet-reader adapter.
- Detect supported layout from workbook structure rather than filename.
- Parse course name, room, frequency, note, exam information, weekday, and period.
- Preserve unrecognized nonempty cells as explicit import issues instead of dropping them.
- Normalize only structural punctuation and whitespace needed by the source format; preserve user-visible text.
- Support repeated and consecutive meetings without duplicating durable course identity fields.
- Add fixture-backed tests for both supported layouts, blank cells, unavailable rooms, mixed frequency/exam text, malformed rows, weekend classes, and unsupported workbooks.

### 5. Implement Authoritative Schedule Storage

- Create `lib/data/app_paths.dart` and `lib/data/schedule_repository.dart`.
- Store one authoritative file at the application-support location as `schedule.xls`.
- Enforce a documented input-size limit before parsing or writing.
- Parse the candidate before replacing existing data.
- Write and flush a sibling temporary file, verify readable bytes, then atomically rename it over the prior file.
- Load and parse stored data at startup; surface corruption without deleting evidence automatically.
- Test first import, replacement, cancellation, parse failure, write failure, interrupted temporary state, and unchanged prior schedule on every failed path.

### 6. Add Native File Acquisition

- Create `lib/data/schedule_picker.dart` with an injectable picker boundary.
- Request one `.xls` document and consume selected bytes rather than assuming a stable external path.
- Treat cancellation as a no-op.
- Distinguish selection/read errors from workbook validation errors.
- Confirm Android uses the system document interface without broad storage permission.
- Add unit or widget coverage proving cancellation does not mutate repository state.

### 7. Build Application State

- Create `lib/features/timetable/timetable_controller.dart`.
- Model loading, empty, ready, stale parity, import failure, and stored-file failure explicitly.
- Serialize imports so concurrent selections cannot replace each other out of order.
- Keep parity refresh independent from local timetable availability.
- Provide current, odd, even, and all preview modes without changing stored data.
- Test startup combinations of schedule present or absent and parity fresh, cached, or unavailable.

### 8. Build Responsive Timetable UI

- Replace `lib/main.dart` with the minimal production entry point.
- Create `lib/app/app.dart`, `lib/app/home_page.dart`, and timetable feature widgets.
- Show import guidance when no stored schedule exists.
- Show week number, odd/even status, data freshness, and manual refresh without blocking local timetable use.
- Render full weekly grid on wide layouts and a selected-day schedule on narrow layouts.
- Keep a horizontal weekly view available on mobile when users need full-week context.
- Show unknown-frequency meetings with a visible warning rather than hiding them.
- Derive stable course colors from course identity and maintain readable foreground contrast.
- Use flat visual hierarchy, no gradients, bounded labels, accessible semantics, and keyboard navigation on desktop.
- Add widget tests for empty, loading, populated, odd, even, unknown-frequency, stale-data, narrow, and wide states.

### 9. Apply Product Identity

- Select final product and publisher identities before changing generated platform namespaces.
- Update `pubspec.yaml`, Android label and application ID, Linux binary and application ID, Windows executable metadata, and visible application title together.
- Do not leave `com.example`, `Flutter Demo`, or counter-template identity in release artifacts.
- Verify identifiers and labels from built artifacts on each platform.

### 10. Add Linux AppImage Packaging

- Create `packaging/linux/` with one reproducible AppImage definition and required desktop metadata.
- Build from `flutter build linux --release` output without downloading executable helpers at runtime.
- Resolve application resources relative to the installed executable bundle.
- Include required Flutter and plugin libraries without bundling unrelated host libraries.
- Produce one AppImage artifact and launch that exact artifact under a bounded display session.
- Inspect application title, icon, startup state, file picker opening, and local schedule reload.

### 11. Add Windows NSIS Packaging

- Create `packaging/windows/installer.nsi` and required installer assets after product identity is fixed.
- Package the complete `flutter build windows --release` output.
- Install per user by default unless product requirements later require elevation.
- Define deterministic upgrade, shortcut, uninstall, and retained-user-data behavior.
- Build with `makensis` in Windows CI.
- Install the generated artifact on a clean Windows runner, launch the installed executable, verify bundled DLL discovery, then uninstall it.

### 12. Add Cross-Platform CI and Release Evidence

- Create focused CI jobs for static analysis and tests, Android release build, Linux release and AppImage build, and Windows release and NSIS build.
- Pin packaging tool versions and verify downloaded build tools by published checksums.
- Keep signing outside the initial unsigned packaging milestone; never commit credentials.
- Record artifact names, sizes, checksums, and smoke-test results from the same source revision.
- Update `README.md` only with end-user description, import instructions, parity behavior, privacy boundary, and supported installers.

## Validation Contract

- `dart format --output=none --set-exit-if-changed lib test` passes for all Dart sources.
- `flutter analyze` reports no issues.
- `flutter test` passes all domain, parser, repository, and widget tests.
- Fixture-backed parsing proves the actual sanitized PKU export loads without lost nonempty course cells.
- A failed replacement test proves existing `schedule.xls` remains byte-for-byte unchanged.
- Week-boundary tests prove current, odd, and even views use Beijing calendar dates correctly.
- A network-denial test proves timetable import and display work without network access.
- Source search confirms no application request targets `elective.pku.edu.cn`.
- `flutter build apk --release` succeeds and packaged metadata contains the intended application identity and Internet permission without broad storage permission.
- `flutter build linux --release` succeeds, and the release bundle launches on Linux.
- The generated AppImage launches and reloads a previously imported schedule from its real application-support directory.
- `flutter build windows --release` succeeds in Windows CI.
- The generated NSIS installer installs, launches, upgrades, and uninstalls without deleting retained timetable data unless removal is explicitly selected.
- Narrow and wide real-runtime captures show readable timetable states with no clipping, overflow, hidden warnings, or gradients.
- Final diff contains no credentials, generated build directories, temporary probes, unsanitized schedules, or copied AGPL source lacking an approved license decision.

## Risks and Decisions

- Product name, publisher, application IDs, and installer identity remain undecided and block final platform metadata.
- Licensing strategy remains undecided. Directly porting AGPL-3.0 elective-prettifier code can impose source-distribution obligations.
- Parser dependency remains provisional until tested against a sanitized export.
- Week Parity repository ownership or location needs confirmation; runtime should use the deployed config endpoint while validating host and content.
- Semester configuration has start dates but no explicit end dates. UI must expose stale data rather than inventing semester boundaries.
- AppImage portability depends on careful GTK and plugin-library packaging and must be tested on more than the build host before release.
- Windows installer behavior cannot be proven from Linux; Windows CI or a Windows machine is required.

## Acceptance Criteria

- User imports one local PKU `schedule.xls` without any request to the elective site.
- Valid import survives restart on Android, Linux AppImage, and Windows NSIS installation.
- Invalid import never replaces the prior valid schedule.
- App displays the correct Beijing-calendar semester week and odd/even status from validated fresh or cached configuration.
- `每周`, `单周`, and `双周` meetings appear in correct current-week views; unknown frequencies remain visible with warnings.
- Timetable remains usable offline and when Week Parity refresh fails.
- Monday-through-Sunday classes and all nonempty source details remain represented.
- Android release, Linux AppImage, and Windows NSIS artifacts build and pass their declared installed-runtime checks.
- No release artifact or source path contains automated elective-site access.