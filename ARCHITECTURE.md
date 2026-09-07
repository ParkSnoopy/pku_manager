# Architecture

PKU Manager is an offline-first Flutter school life application targeting Android, iOS, Linux AppImage, macOS, and Windows NSIS distributions. Web is not supported. See `CONTEXT.md` for project vocabulary and durable product invariants.

## Document Status

The repository currently contains the Flutter starter application. This document defines the target structure implemented by `PLAN.md`; paths marked as planned do not exist until their corresponding plan task is complete.

Architecture documentation describes module ownership and runtime flow. Product terminology, safety constraints, and interpretation rules remain authoritative in `CONTEXT.md`.

## System Shape

The application is one Flutter process with four internal layers and thin platform runners.

| Layer | Path | Status | Responsibility |
|---|---|---|---|
| Entry | `lib/main.dart` | Current, to replace | Start Flutter and construct the application root. |
| Application | `lib/app/` | Planned | Build dependencies, theme, navigation shell, and feature ownership. |
| Features | `lib/features/` | Planned | Coordinate user actions and render application state. |
| Domain | `lib/domain/` | Planned | Define timetable, semester, parity, and visibility rules without infrastructure dependencies. |
| Data | `lib/data/` | Planned | Adapt files, SQLite, spreadsheets, public HTTP configuration, and platform paths to domain values. |
| Android runner | `android/` | Current | Host Flutter, declare application identity, and permit public Week Parity access. |
| iOS runner | `ios/` | Current | Host Flutter, select documents, and package the iOS application. |
| Linux runner | `linux/` | Current | Host the Flutter GTK application and produce the desktop release bundle. |
| macOS runner | `macos/` | Current | Host Flutter and produce the macOS application bundle. |
| Windows runner | `windows/` | Current | Host the Flutter Win32 application and produce the desktop release bundle. |
| Linux packaging | `packaging/linux/` | Planned | Turn the complete Linux release bundle into an AppImage. |
| Windows packaging | `packaging/windows/` | Planned | Turn the complete Windows release bundle into an NSIS installer. |
| Tests | `test/` | Current, to expand | Mirror domain, data, feature, and application boundaries with focused fixtures and widget tests. |

## Dependency Direction

Dependencies point inward:

1. Domain imports only Dart libraries needed for immutable values and calculations.
2. Features import domain contracts, own their boundary interfaces, and never import concrete data adapters.
3. Data adapters import domain contracts, consumer-owned interfaces, and external packages needed at boundaries.
4. Data adapters implement those narrow consumer-owned interfaces.
5. Application constructs concrete adapters and gives them to feature controllers.
6. Platform runners host Flutter and contain no timetable or parity rules.

Domain code never imports Flutter widgets, file pickers, filesystem paths, HTTP clients, spreadsheet packages, or platform channels.

Feature widgets never parse spreadsheets, calculate parity independently, choose storage paths, or issue HTTP requests.

Only application composition selects concrete implementations. Tests replace side-effecting boundaries with in-memory implementations.

## Application Layer (`lib/app/`)

### Entry and Composition

- `lib/main.dart` starts `PkuManagerApp` and contains no feature logic.
- `lib/app/app.dart` owns `MaterialApp`, application-level theme, adapter construction, and controller lifetime.
- `lib/app/home_page.dart` owns responsive navigation and the initial timetable destination.

The application layer creates one shared SQLite database, schedule repository, week configuration repository, clock, validated build configuration, and timetable controller. Widgets receive existing instances rather than constructing side-effecting services during `build`.

Default builds configure a 16-week semester limit. A typed build-time setting may override it within 1–53 weeks; invalid values fail before normal application use.

### Navigation

Initial scope has one timetable-focused home destination. Import, errors, and narrow-screen day selection stay inside that destination. New school-life features may add sibling destinations without moving timetable rules into the navigation shell.

## Domain Layer (`lib/domain/`)

### Semester and Parity

- `semester.dart` represents an applicable semester start and calculates semester week from a Beijing calendar date.
- Week numbering starts at one on the configured semester start date.
- One parity policy owns odd/even interpretation. Repositories, controllers, and widgets do not repeat modulo or date-boundary logic.
- Dates before every known start produce no applicable semester instead of an invented week.

### Meeting Frequency

- `week_frequency.dart` defines `every`, `odd`, `even`, and `unknown`.
- Parsing recognizes source tokens `每周`, `单周`, and `双周` at one boundary.
- One meeting-visibility policy evaluates frequency against current, odd, even, and all preview modes.
- Unknown frequency remains representable and visible.

### Course Meetings

- `course_meeting.dart` represents one normalized occurrence of a course.
- A meeting owns stable source-record identity, course name, weekday, first and last periods, room, frequency, note, and exam information.
- Weekday covers Monday through Sunday.
- Period ranges are positive, ordered, and bounded by the imported timetable structure.
- Source text remains human-readable; parsing normalizes only format syntax needed to identify fields.

### Timetable

- `timetable.dart` owns ordered meetings and read-only projections by day, period, and preview mode.
- Consecutive cells for the same occurrence can be grouped for rendering without changing persisted source bytes.
- Ordering is deterministic: weekday, first period, last period, then source order.
- Display colors and responsive geometry are presentation concerns, not timetable fields.

## Data Layer (`lib/data/`)

### Application Database and Platform Paths

- `app_paths.dart` resolves the SQLite database in the platform application-support directory.
- `app_database.dart` owns schema versions, migrations, foreign keys, transactions, integrity checks, and typed row mapping.
- Runtime data uses normalized SQLite tables and BLOBs. JSON columns are not schema substitutes.
- Production uses `path_provider` and the Dart `sqlite3` package; tests use temporary or in-memory databases.

### Schedule Acquisition

- `schedule_picker.dart` wraps `file_picker` behind one schedule-selection interface.
- Selection returns bounded file bytes and a display filename. External file bytes are never modified.
- The repository never assumes an external path remains readable after picker completion.
- Cancellation is a distinct successful no-selection outcome.
- Picker failures remain distinct from workbook validation failures.

### Workbook Decoding and Layout Parsing

`schedule_xls_parser.dart` contains a pipeline with separate responsibilities:

1. Workbook decoder validates the file signature and exposes sheet cells through a package-neutral matrix interface.
2. Layout detector inspects workbook structure rather than trusting the extension or filename.
3. A layout parser handles each supported PKU shape.
4. Field parser extracts course details, source-record identity, and typed frequency.
5. Timetable validator rejects impossible coordinates and reports every unsupported or incomplete nonempty record.

Initial layout implementations cover legacy one-row records and newer paired rows. Both produce the same domain model. Adding a source layout requires a new recognizer/parser pair, not changes to widgets or persistence.

The spreadsheet package remains isolated behind the workbook decoder. Replacing a provisional package must not change domain or feature APIs. Relevant behavioral cases from reference projects are independently reimplemented as Dart tests; reference code and fixtures are not copied without compatible licensing.

### Schedule Repository

- `schedule_repository.dart` is the sole authority for schedule source BLOBs, parsed records, completion fields, and active-schedule selection.
- Source BLOBs retain selected workbook bytes exactly and are immutable after insertion.
- Import validates size, decodes, parses, and reports every issue before any authoritative write.
- A complete candidate is inserted and activated in one SQLite transaction.
- An incomplete candidate remains transient while the user either supplies every required completion field or rejects it. Completed values are stored separately from source-derived values.
- Failed, cancelled, or rejected import leaves the previous active source and published timetable unchanged.
- Startup reads the active parsed structure and verifies its immutable source record. Corruption is reported without destructive repair.

### Week Configuration Parser

- `week_config_parser.dart` accepts the small TOML contract used by the deployed Week Parity source.
- It requires one supported timezone and a nonempty, unique, ascending list of valid ISO dates.
- It rejects unknown structural shapes rather than partially applying them.
- Parsed values are domain dates; raw HTTP and TOML details stop at this boundary.

### Week Configuration Repository

- `week_config_repository.dart` owns fetch, validation, SQLite-backed last-known-good caching, and freshness metadata.
- Production requests only `https://parksnoopy-undergraduate.github.io/week/config.toml`.
- Fetch uses HTTPS, a bounded timeout, a bounded response size, and redirect-host validation.
- New bytes replace the cache in one SQLite transaction only after complete parsing and validation.
- Network or parse failure returns valid cached data when available.
- Fresh, cached, stale, and unavailable outcomes remain distinct.
- Week configuration failure never changes or blocks stored timetable data.

## Feature Layer (`lib/features/`)

### Timetable Controller

`lib/features/timetable/timetable_controller.dart` owns one immutable view-state snapshot containing independent schedule and parity state.

Schedule state distinguishes:

- loading
- empty
- ready
- stored-file failure
- import failure while retaining prior ready data

Parity state distinguishes:

- loading
- fresh
- cached or stale
- unavailable

The controller coordinates repositories but does not parse source formats or render widgets. Import operations are serialized so older completions cannot replace newer user selections. Parity refresh remains independent and may complete before or after schedule loading.

Incomplete-import review is separate from schedule state. It holds a transient candidate and all issues until the user supplies every required field or rejects the candidate.

### Timetable Presentation

- `timetable_page.dart` owns page-level actions, state selection, and responsive layout choice.
- `week_status.dart` presents semester week, parity, freshness, and refresh action.
- `timetable_grid.dart` renders the complete week on wide layouts.
- `day_schedule.dart` renders one fixed period-index column and one visible day column on narrow layouts. Horizontal swipes select Monday through Sunday.
- `schedule_import_action.dart` owns user-facing file selection and import feedback.

Widgets consume domain projections supplied by the controller. They do not filter frequency with local string checks. Unknown-frequency warnings accompany affected meetings in every layout.

Course colors are deterministic presentation values derived from course identity. Foreground contrast is calculated from the chosen background. Color assignments are not persisted.

## Durable Storage

Production storage uses one SQLite database in application support:

| Logical record | SQLite representation | Authority | Replacement rule |
|---|---|---|---|
| Imported workbook | Immutable source BLOB | Exact user-selected bytes | Insert only after bounded parsing; never update its bytes. |
| Parsed timetable | Normalized typed rows keyed to source identities | Parser plus accepted completion fields | Publish with source and active selection in one transaction. |
| Import issues and completions | Typed rows keyed to source identities | Parser issues and explicit user input | Require complete resolution before publication. |
| Week configuration | Raw TOML BLOB, normalized starts, and freshness metadata | Last valid public source response | Replace in one transaction after complete validation. |

SQLite transactions provide publication and rollback. Database migrations are ordered and transactional. Startup integrity failure is surfaced; the app does not silently rebuild or discard source evidence.

No schedule data belongs beside the executable, in the repository, in Downloads after import, or inside installer-owned directories. The user-selected external workbook remains untouched.

## Core Data Flows

### Schedule Import

1. User invokes import from `schedule_import_action.dart`.
2. `timetable_controller.dart` requests bytes through `schedule_picker.dart`.
3. `schedule_repository.dart` checks bounds and submits bytes to `schedule_xls_parser.dart` without mutation.
4. Workbook decoder and selected layout parser create a candidate containing source identities, parsed records, and all issues.
5. A complete candidate proceeds directly; an incomplete candidate waits for complete user corrections or whole-candidate rejection.
6. Repository inserts immutable bytes, parsed rows, completion rows, and active selection in one SQLite transaction.
7. Controller publishes ready schedule state.
8. `timetable_page.dart` selects the responsive projection and renders it.

Cancellation or rejection stops without mutation. Any failure before transaction commit retains the previous ready state and source rows.

### Startup and Week Refresh

1. `app.dart` creates repositories and starts `timetable_controller.dart`.
2. Schedule repository loads active parsed rows and verifies their immutable source BLOB.
3. Week repository loads validated cached configuration rows.
4. Semester policy calculates current week from Beijing date and cached configuration.
5. Controller publishes usable local state without waiting for network success.
6. Week repository refreshes the allowed public URL.
7. Valid fresh configuration transactionally replaces cache and recalculates parity.
8. Invalid or unavailable network data leaves cached parity state intact.

### Dynamic Timetable Projection

1. Controller combines timetable, parity outcome, and selected preview mode.
2. Domain visibility policy evaluates each meeting's typed frequency.
3. Timetable projection groups visible meetings by weekday and period.
4. Wide and narrow widgets render the same projection semantics.

If current parity is unavailable, beyond the build-configured semester length, or superseded by the next configured start, the controller uses the all view rather than guessing odd or even status. UI reports why automatic filtering is unavailable.

## Failure Boundaries

| Boundary | Failure handling |
|---|---|
| File picker | Report acquisition failure or cancellation without repository mutation. |
| Workbook decoder | Reject unsupported bytes; preserve prior schedule. |
| Layout parser | Report every unsupported or incomplete nonempty record; never silently omit it. |
| Completion review | Publish only after every required field is complete; rejection changes nothing. |
| SQLite transaction | Roll back and keep prior active schedule and ready state. |
| Stored schedule load | Report integrity failure while retaining immutable source evidence. |
| Week HTTP fetch | Fall back to last valid cache. |
| Week config parse | Reject candidate and retain last valid cache. |
| Parity resolution | Show unavailable state and unfiltered timetable. |
| Presentation | Render bounded fallback text for long values without changing source data. |

## Network and Privacy Boundary

The runtime has one allowed network purpose: retrieve public Week Parity configuration. No timetable bytes, course names, rooms, notes, exam information, filenames, or usage events leave the device.

No module may request, scrape, probe, authenticate to, or embed `elective.pku.edu.cn`. README instructions may tell users to export their own file manually, but no application control initiates automated access. Elective-prettifier and Week Parity may inform independently authored Dart behavior and tests only.

Android declares Internet permission for Week Parity configuration. It does not request broad storage permission; document access uses the system picker.

## Platform and Packaging Boundaries

### Android

`android/` remains a thin Flutter host. Application identity and Internet permission belong in Android metadata. Schedule selection uses the federated picker implementation and Android document access.

### iOS

`ios/` remains a thin Flutter host. Schedule selection uses the system document interface, and SQLite data remains in application support. Device or simulator verification covers import, restart, swipe navigation, and offline use.

### Linux

`linux/` builds the GTK release bundle. `packaging/linux/` packages that complete bundle into an AppImage without changing runtime storage paths. AppImage verification launches the exact packaged artifact, not only the source-tree runner.

### macOS

`macos/` remains a thin Flutter host and produces the macOS application bundle. macOS verification launches the bundle and covers document selection, bundled SQLite, persistence, and restart.

### Windows

`windows/` builds the Win32 release bundle. `packaging/windows/installer.nsi` packages the complete bundle and defines install, upgrade, shortcut, retained application data, and uninstall behavior. Installed-runtime verification occurs on Windows.

Generated plugin registrants under platform directories are generated integration files. Dependency changes regenerate them through Flutter tooling; application logic must not be added there.

The generated Web target is removed. Application code, assets, tests, and CI do not retain Web-specific behavior.

## Testing Layout

Tests mirror production ownership:

| Test path | Scope |
|---|---|
| `test/domain/` | Pure date, parity, frequency, ordering, grouping, and visibility contracts. |
| `test/data/` | TOML parsing, bounded fetches, SQLite migrations and transactions, workbook decoding, layout parsing, immutable-source equality, and completion storage. |
| `test/features/` | Controller state combinations, incomplete review, rejection, serialized import, refresh independence, and preview selection. |
| `test/widgets/` | Empty, ready, failure, incomplete review, stale, unknown-frequency, swipeable narrow, and wide rendered states. |
| `test/fixtures/` | User-approved sanitized workbook fixtures and small public week-config samples. |

Synthetic cell matrices cover isolated parser branches. Acceptance of the spreadsheet adapter requires at least one sanitized real PKU export fixture. Fixtures containing personal or course-sensitive data do not enter the repository.

Primary verification commands are:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- `flutter build ios --release` on macOS
- `flutter build linux --release`
- `flutter build macos --release` on macOS
- `flutter build windows --release` on Windows

AppImage and NSIS checks use their source-controlled packaging definitions after those files exist. Packaged-runtime checks remain separate from Flutter compilation.

## Extension Points

Future school-life features enter as sibling feature modules and may reuse application composition, SQLite storage, and navigation. They do not expand timetable models with unrelated nullable fields.

New timetable file formats implement the workbook or layout parser boundary and produce the existing `Timetable` domain model.

New semester-data providers implement the week configuration source boundary and must produce the same validated ordered semester contract. Provider-specific network or serialization details remain outside domain policy.

New timetable presentations consume existing projections and visibility policy. They do not reinterpret Chinese frequency tokens or recalculate parity.

Cross-feature persisted selections store stable identifiers when available and derive mutable display labels from authoritative data.

## Architectural Verification

Architecture remains intact when:

- domain files have no Flutter, plugin, filesystem, HTTP, or spreadsheet imports;
- only the schedule repository inserts immutable workbook source BLOBs or changes active schedule rows;
- source BLOB tests prove exact equality before and after completion;
- only the week repository replaces cached week configuration rows;
- SQLite migrations and publication changes are transactional and integrity-checked;
- all frequency filtering uses the shared domain visibility policy;
- no source contains runtime access to `elective.pku.edu.cn`;
- generated platform files contain no application logic;
- Android, iOS, Linux AppImage, macOS, and Windows NSIS artifacts use one product identity;
- no Web runner files remain;
- packaged artifacts load application-support data after restart; and
- `PLAN.md`, `CONTEXT.md`, and this document agree on paths and ownership.