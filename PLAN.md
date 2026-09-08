# PKU Manager Implementation Plan

## Goal

Build an offline-first school life management application for Android, iOS, Linux, macOS, and Windows. Its first complete feature set imports and retains an immutable user-supplied PKU `schedule.xls`, stores parsed application data in SQLite, renders a polished timetable, and filters odd-week and even-week classes using semester dates published by the Week Parity project. Web is not a target.

## Current Context

- The Flutter application is at version `0.0.2`; all `0.0.x` builds keep schema version 0 without compatibility code.
- Android, iOS, Linux, macOS, and Windows Flutter runners exist. Web is unsupported.
- Domain, SQLite, workbook parsing, responsive timetable, editing, appearance, export, and native packaging layers are implemented.
- The deployed Week Parity application currently reads `https://parksnoopy-undergraduate.github.io/week/config.toml`.
- The supplied Week Parity repository URL currently resolves inconsistently and must not be treated as a stable runtime dependency.
- The elective prettifier supports legacy one-row and newer paired-row timetable layouts, but its source is AGPL-3.0.
- A sanitized real `schedule.xls` fixture is required before parser compatibility can be accepted.

## Product and Safety Constraints

- Never request, scrape, probe, authenticate to, or embed `elective.pku.edu.cn`.
- Users obtain `schedule.xls` themselves and import it through a native file picker.
- Keep the imported `schedule.xls` as the authoritative timetable source.
- Preserve imported workbook bytes exactly. Store source bytes, parsed records, issues, user completion fields, and week data in one application SQLite database.
- Keep all timetable processing local; network access is limited to public Week Parity configuration.
- Do not silently omit malformed or unsupported class records.
- Present Monday through Friday; intentionally ignore Saturday and Sunday source columns.
- Use a native Flutter interface rather than a WebView around either reference site.
- Avoid copying AGPL-licensed implementation unless the project explicitly adopts compatible licensing obligations or obtains permission.
- Independently reimplement relevant Week Parity and elective-prettifier behavior in Dart and recreate every applicable reference test scenario without copying unapproved code or fixtures.
- Do not choose a spreadsheet dependency permanently until it parses a sanitized real export successfully.
- Keep implementation small and direct; add abstraction only around filesystem, file selection, time, and network boundaries that require deterministic tests.
- Keep business logic in Dart. Use Flutter packages or narrow Dart wrappers only where native platform facilities are required.
- Avoid JSON for application-owned schema-like formats; use Protobuf or XML when an interchange schema is needed.

## Architecture

### Application Layer

- `lib/app/app.dart`: application root, theme, dependency construction, build configuration, and startup state.
- `lib/app/home_page.dart`: responsive shell and timetable-focused home surface.
- `lib/main.dart`: minimal entry point that launches the application root.

### Domain Layer

- `lib/domain/week_frequency.dart`: typed `every`, `odd`, and `even` frequency values plus current-week membership rules; unsupported tokens map to `every`.
- `lib/domain/semester.dart`: semester start, Beijing calendar date, week number, and parity calculations.
- `lib/domain/course_meeting.dart`: normalized course name, weekday, period range, room, frequency, note, and exam information.
- `lib/domain/timetable.dart`: ordered meetings, period bounds, day grouping, and consecutive-cell grouping.

Domain objects remain independent of Flutter widgets, filesystems, HTTP, and spreadsheet packages.

### Data Layer

- `lib/data/week_config_parser.dart`: strict parser for ordered semester dates and supported timezone from `config.toml`.
- `lib/data/week_config_repository.dart`: last-known-good cache, bounded public fetch, refresh state, and transactional cache replacement.
- `lib/data/schedule_xls_parser.dart`: spreadsheet-adapter boundary that recognizes supported PKU layouts and returns a normalized timetable.
- `lib/data/schedule_repository.dart`: candidate validation, immutable source storage, parsed-record publication, completion overlays, and transactional replacement.
- `lib/data/app_database.dart`: SQLite schema, migrations, transactions, integrity checks, and typed row mapping.
- `lib/app/app.dart` resolves application-support storage through `path_provider`.
- `lib/data/schedule_picker.dart`: unrestricted native acquisition through `file_selector`; workbook content determines compatibility.
- `lib/data/sqlite_appearance_store.dart`: typed SQLite persistence for theme and timetable color-roll seed.

The application stores exact workbook source bytes and all application-owned durable state in one SQLite database. Parsed records, issues, and user completion fields reference stable source-record identities. No completion operation mutates the source BLOB.

Boundary interfaces are owned by their consumers. Features import domain contracts, not `lib/data/`; concrete data adapters depend on the narrow ports they implement. `lib/app/` is the only composition root.

### Feature Layer

- `lib/features/timetable/timetable_controller.dart`: startup loading, import coordination, parity refresh, preview mode, and error states.
- `lib/features/timetable/timetable_page.dart`: responsive navigation shell and timetable page.
- `lib/features/calendar/calendar_page.dart`: month calendar derived from timetable and semester parity.
- `lib/features/timetable/timetable_grid.dart`: desktop and wide-screen weekly grid.
- `lib/features/timetable/day_schedule.dart`: compact selected-day presentation for narrow screens.
- `lib/features/timetable/week_status.dart`: semester week, parity, freshness, and refresh status.
- `lib/features/schedule_import/schedule_import_action.dart`: import affordance and user-facing validation failures.
- `lib/features/schedule_import/schedule_import_review.dart`: complete every reported required field or reject the candidate without mutation.
- `lib/features/settings/appearance_controller.dart` and `settings_page.dart`: persistent accent, language, and repeatable timetable color rolls.
- `lib/features/timetable/course_editor_dialog.dart`: add weekday meetings and edit imported records through separate overlays.
- `lib/features/timetable/timetable_export.dart`: complete Monday–Friday PNG and XLSX export.

### Runtime Data Flow

- Startup loads the active parsed timetable from SQLite and verifies its immutable source record remains present.
- Startup calculates parity from cached Week Parity configuration, then attempts a bounded refresh.
- Successful refresh replaces cached week data in one transaction only after complete validation.
- Import reads a bounded candidate, parses all records, and reports all issues before mutation.
- A complete candidate, or an incomplete candidate completed by the user, stores exact source bytes and parsed structure and switches the active schedule in one SQLite transaction.
- Rejecting or ignoring a candidate leaves the active schedule unchanged.
- Failed refresh retains the last valid parity data and reports stale or unavailable state.
- Failed import leaves the prior timetable unchanged.
- Timetable visibility is derived from selected preview mode and each meeting's typed frequency.

## Dependencies

- Add `file_picker` for native Android, iOS, Linux, macOS, and Windows file selection.
- Add `path_provider` for application-support storage.
- Add the maintained `sqlite3` Dart package, whose build hooks bundle SQLite across Android, iOS, Linux, macOS, and Windows. Do not add the obsolete `sqlite3_flutter_libs` package.
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
- Verify stable ordering, Monday-through-Friday retention, period bounds, and consecutive meeting grouping.
- Add stable source-record identity and separate typed completion fields; neither can mutate source workbook bytes.
- Add validated build configuration for semester length. Default builds use 16 weeks; values outside 1–53 weeks fail startup or build validation.

### 2. Implement Week Configuration

- Create `lib/data/week_config_parser.dart` and `test/data/week_config_parser_test.dart`.
- Validate required keys, supported timezone, nonempty dates, ISO calendar dates, uniqueness, and ascending order.
- Create `lib/data/week_config_repository.dart` with injected fetch, cache, clock, and timeout boundaries.
- Accept only a successful HTTPS response from the exact Week Parity config URL.
- Bound response size and reject redirects outside the allowed host.
- Preserve the previous cache after malformed, oversized, timed-out, or failed responses.
- Report whether current parity came from fresh data, cached data, or no usable data.
- Treat a semester as applicable only before the next configured start and within the build-configured week count.
- Add Android Internet permission in `android/app/src/main/AndroidManifest.xml`.
- Test fresh fetch, valid cache fallback, invalid cache, network failure, redirect rejection, and transactional replacement.

### 3. Confirm Spreadsheet Compatibility

- Obtain one sanitized, representative `schedule.xls` directly from the user; never fetch it from the elective site.
- Record it under `test/fixtures/` only after the user confirms all personal and course-sensitive content has been removed.
- Add the provisional spreadsheet dependency to `pubspec.yaml` and resolve `pubspec.lock` normally.
- Create focused adapter coverage in `test/data/schedule_xls_parser_test.dart`, not a temporary script.
- Confirm workbook signature, sheet discovery, row and column values, Chinese text, line breaks, empty cells, and both timetable layouts represented by available fixtures.
- Keep `excel2003` only if this evidence passes; document any required replacement before broader parser work.
- Inventory every applicable behavioral case from Week Parity and elective-prettifier references and recreate it as an independently authored Dart test. Record provenance without copying unapproved test code or fixtures.

### 4. Implement Timetable Parsing

- Create `lib/data/schedule_xls_parser.dart` around one spreadsheet-reader adapter.
- Detect supported layout from workbook structure rather than filename.
- Parse course name, room, frequency, note, exam information, weekday, and period.
- Preserve unrecognized nonempty cells as explicit import issues instead of dropping them.
- Normalize only structural punctuation and whitespace needed by the source format; preserve user-visible text.
- Support repeated and consecutive meetings without duplicating durable course identity fields.
- Add fixture-backed tests for both supported layouts, blank cells, unavailable rooms, mixed frequency/exam text, malformed rows, ignored weekend columns, and unsupported workbooks.
- Return stable source identities, parsed values, and all issues as one candidate. Do not persist during parsing.

### 5. Implement SQLite Storage and Authoritative Schedule Import

- Create `lib/data/app_paths.dart`, `lib/data/app_database.dart`, and `lib/data/schedule_repository.dart`.
- Store exact workbook bytes as an immutable SQLite BLOB alongside parsed records, issues, and user completion fields.
- Use typed tables, foreign keys, schema migrations, transactions, and an integrity check. Do not use JSON columns as substitute schemas.
- Enforce a documented input-size limit before parsing or writing.
- Parse the complete candidate before opening its publication transaction.
- If issues require information, present all of them and accept only complete typed corrections or whole-candidate rejection.
- Insert immutable source bytes and normalized records, then change the active schedule within one SQLite transaction.
- Load parsed data at startup; retain corrupt source evidence and surface database integrity or migration failures without destructive repair.
- Test first import, replacement, cancellation, parse failure, incomplete review, rejection, transaction failure, source-byte equality, completion persistence, and unchanged prior schedule on every failed path.

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
- Model incomplete import review separately from failure and ready state.
- Serialize imports so concurrent selections cannot replace each other out of order.
- Keep parity refresh independent from local timetable availability.
- Show every meeting by default; non-current meetings render at half opacity without a visibility toggle.
- Test startup combinations of schedule present or absent and parity fresh, cached, or unavailable.

### 8. Build Responsive Timetable UI

- Replace `lib/main.dart` with the minimal production entry point.
- Create `lib/app/app.dart`, `lib/app/home_page.dart`, and timetable feature widgets.
- Show import guidance when no stored schedule exists.
- Show week number and odd/even status without blocking local timetable use. Refresh automatically at startup and after every foreground resume.
- Render Monday through Friday on wide layouts.
- On narrow layouts, keep one fixed period-index column and one day column visible; horizontal swipes move between Monday and Friday while the visible weekday remains explicit.
- Map unsupported frequency tokens to `每周`.
- Match timetable shape, dimensions, font sizes, alignment, class-time labels, meal breaks, aspect fitting, and 4× PNG export resolution to the `pages` reference; retain application-owned course colors as the only intentional visual exception. Package each CJK family as one Static Super OTC instead of separate region/weight files; keep both Sans and future-use Serif collections.
- Derive course colors from course identity plus a persistent roll seed, allow repeated color rolls after import, and maintain readable foreground contrast.
- Default to Korean, persist English and Simplified Chinese alternatives, localize all application controls, and expose one active-language button that cycles through the three entries per click.
- Group vertically touching identical weekday meetings into one block and atomically edit all retained source identities without mutating imported source bytes; export the complete timetable as PNG or XLSX.
- Persist arbitrary manual colors, explicit manual-color markers, roll locks, and configurable importance-outline colors and thicknesses by source identity. Apply them consistently to the timetable and exports; clear only unlocked manual colors during a palette roll.
- Let Settings choose an arbitrary theme accent and hide the Roll colors rail action. Use fixed padded one-line course typography with truncation.
- Add a month Calendar derived from course recurrence and semester parity. In landscape, Timetable uses an upcoming-schedule pane that becomes the inline editor on selection; Calendar uses an upcoming-class pane. Keep dialog editing for portrait timetable layouts.
- Add a **教学网** rail action that opens the exact PKU Teaching Network URL in the platform default browser.
- Use flat visual hierarchy, no gradients, bounded labels, accessible semantics, and keyboard navigation on desktop.
- Add widget tests for empty, loading, populated, current-week opacity, stale-data, narrow, wide, left navigation and exact external URL dispatch, grouped inline editing, upcoming countdowns, reference timetable geometry/typography, course-and-room full-cell color, repeated color rolls, cyclic language selection, persistent theme editing, 100 ms pointer-following details, foreground refresh, and reference export dimensions.
- Keep `PRAGMA user_version = 0` throughout `0.0.x` and retain no migrations until a schema-version bump and backward compatibility are explicitly requested.

### 9. Apply Product Identity

- Select final product and publisher identities before changing generated platform namespaces.
- Update `pubspec.yaml`, Android label and application ID, iOS bundle metadata, Linux binary and application ID, macOS bundle metadata, Windows executable metadata, and visible application title together.
- Do not leave `com.example`, `Flutter Demo`, or counter-template identity in release artifacts.
- Verify identifiers and labels from built artifacts on each platform.

### 10. Complete Apple Platform Support

- Keep iOS and macOS runners thin and free of timetable or parity logic.
- Verify native file selection, bundled SQLite loading, application-support database persistence, swipe behavior, and offline startup on iOS and macOS.
- Build and launch the macOS application bundle on macOS.
- Build the iOS application and exercise it on a simulator or device; signing and store publication remain separate release concerns.

### 11. Add Linux AppImage Packaging

- Create `packaging/linux/` with one reproducible AppImage definition and required desktop metadata.
- Build from `flutter build linux --release` output without downloading executable helpers at runtime.
- Resolve application resources relative to the installed executable bundle.
- Include required Flutter and plugin libraries without bundling unrelated host libraries.
- Produce one AppImage artifact and launch that exact artifact under a bounded display session.
- Inspect application title, icon, startup state, file picker opening, and local schedule reload.

### 12. Add Windows NSIS Packaging

- Create `packaging/windows/installer.nsi` and required installer assets after product identity is fixed.
- Package the complete `flutter build windows --release` output.
- Install per user by default unless product requirements later require elevation.
- Define deterministic upgrade, shortcut, uninstall, and retained-user-data behavior.
- Build with `makensis` in Windows CI.
- Install the generated artifact on a clean Windows runner, launch the installed executable, verify bundled DLL discovery, then uninstall it.

### 13. Add Cross-Platform CI and Release Evidence

- Create focused CI jobs for static analysis and tests, Android release build, Apple builds on macOS, Linux release and AppImage build, and Windows release and NSIS build.
- Pin packaging tool versions and verify downloaded build tools by published checksums.
- Keep signing outside the initial unsigned packaging milestone; never commit credentials.
- Record artifact names, sizes, checksums, and smoke-test results from the same source revision.
- Update `README.md` only with end-user description, import instructions, parity behavior, privacy boundary, and supported installers.

## Validation Contract

- `dart format --output=none --set-exit-if-changed lib test` passes for all Dart sources.
- `flutter analyze` reports no issues.
- `flutter test` passes all domain, parser, repository, and widget tests.
- Fixture-backed parsing proves the actual sanitized PKU export loads without lost nonempty course cells.
- Tests prove the imported source BLOB exactly equals selected workbook bytes before and after user completion.
- Failed, cancelled, incomplete, and rejected imports leave the active source and parsed timetable unchanged.
- Week-boundary tests prove current, odd, and even views use Beijing calendar dates correctly.
- A network-denial test proves timetable import and display work without network access.
- Source search confirms no application request targets `elective.pku.edu.cn`.
- `flutter build apk --release` succeeds and packaged metadata contains the intended application identity and Internet permission without broad storage permission.
- Apple builds succeed on macOS; real iOS and macOS runtimes import, persist, restart, and reload the same timetable through SQLite.
- `flutter build linux --release` succeeds, and the release bundle launches on Linux.
- The generated AppImage launches and reloads a previously imported schedule from its real application-support directory.
- `flutter build windows --release` succeeds in Windows CI.
- The generated NSIS installer installs, launches, upgrades, and uninstalls without deleting retained timetable data unless removal is explicitly selected.
- Narrow and wide real-runtime captures show readable timetable states with no clipping, overflow, hidden warnings, or gradients.
- Final diff contains no credentials, generated build directories, temporary probes, unsanitized schedules, or copied AGPL source lacking an approved license decision.
- Source search finds no application-owned JSON schema or JSON-backed SQLite column.

## Risks and Decisions

- Product name, publisher, application IDs, and installer identity remain undecided and block final platform metadata.
- Licensing strategy remains undecided. Directly porting AGPL-3.0 elective-prettifier code can impose source-distribution obligations.
- Parser dependency remains provisional until tested against a sanitized export.
- Week Parity repository ownership or location needs confirmation; runtime should use the deployed config endpoint while validating host and content.
- Semester configuration has start dates but no explicit end dates. UI must expose stale data rather than inventing semester boundaries.
- AppImage portability depends on careful GTK and plugin-library packaging and must be tested on more than the build host before release.
- Windows installer behavior cannot be proven from Linux; Windows CI or a Windows machine is required.

## Acceptance Criteria

- User imports one local PKU `schedule.xls` without any request to the elective site, and retained source bytes remain exact.
- Valid import survives restart on Android, iOS, Linux AppImage, macOS, and Windows NSIS installation.
- Invalid import never replaces the prior valid schedule.
- Incomplete import reports every issue and changes data only after the user completes all required fields; rejection changes nothing.
- App displays the correct Beijing-calendar semester week and odd/even status from validated fresh or cached configuration.
- `每周`, `单周`, and `双周` meetings receive correct current-week emphasis; unsupported frequency text maps to `每周`.
- Timetable remains usable offline and when Week Parity refresh fails.
- Monday-through-Friday classes and all in-scope nonempty source details remain represented.
- Android, iOS, Linux AppImage, macOS, and Windows NSIS artifacts build and pass their declared runtime checks.
- No release artifact or source path contains automated elective-site access.