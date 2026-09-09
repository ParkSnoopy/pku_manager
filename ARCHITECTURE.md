# Architecture

PKU Manager is an offline-first Flutter school life application targeting Android, iOS, Linux AppImage, macOS, and Windows NSIS distributions. Web is not supported. See `CONTEXT.md` for project vocabulary and durable product invariants.

## Document Status

The repository contains the Flutter timetable application, SQLite adapters, independently authored reference tests, and native packaging definitions. `PLAN.md` separates implemented application behavior from platform release evidence still required in CI.

Architecture documentation describes module ownership and runtime flow. Product terminology, safety constraints, and interpretation rules remain authoritative in `CONTEXT.md`.

## System Shape

The application is one Flutter process with four internal layers and thin platform runners.

| Layer | Path | Status | Responsibility |
|---|---|---|---|
| Entry | `lib/main.dart` | Current | Start Flutter and construct the application root. |
| Application | `lib/app/` | Current | Build dependencies, theme, navigation shell, and feature ownership. |
| Features | `lib/features/` | Current | Coordinate user actions and render application state. |
| Domain | `lib/domain/` | Current | Define timetable, semester, parity, and visibility rules without infrastructure dependencies. |
| Data | `lib/data/` | Current | Adapt files, SQLite, spreadsheets, public HTTP configuration, and platform paths to domain values. |
| Android runner | `android/` | Current | Host Flutter, declare application identity, and permit public Week Parity access. |
| iOS runner | `ios/` | Current | Host Flutter, select documents, and package the iOS application. |
| Linux runner | `linux/` | Current | Host the Flutter GTK application and produce the desktop release bundle. |
| macOS runner | `macos/` | Current | Host Flutter and produce the macOS application bundle. |
| Windows runner | `windows/` | Current | Host the Flutter Win32 application and produce the desktop release bundle. |
| Linux packaging | `packaging/linux/` | Current | Turn the complete Linux release bundle into an AppImage. |
| Windows packaging | `packaging/windows/` | Current | Turn the complete Windows release bundle into an NSIS installer. |
| Tests | `test/` | Current | Exercise domain, adapters, controller, and widget behavior. |

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
- `lib/ui/super_otc_font.dart` selects and registers required Korean and Simplified Chinese faces from both Static Super OTC collections before application startup so Settings can switch between Serif and Sans Serif.
- `lib/features/timetable/timetable_page.dart` is the initial destination and owns the responsive shell; there is no redundant home-page wrapper.

The application layer creates one shared SQLite database, schedule repository, week configuration repository, clock, validated build configuration, and timetable controller. Widgets receive existing instances rather than constructing side-effecting services during `build`.

Default builds configure a 16-week semester limit. A typed build-time setting may override it within 1–53 weeks; invalid values fail before normal application use.

### Navigation

The navigation shell owns Timetable, Calendar, and Settings destinations. Import, errors, and narrow-screen day selection stay inside Timetable. Calendar consumes timetable and semester projections without moving recurrence rules into widgets.

## Domain Layer (`lib/domain/`)

### Semester and Parity

- `semester.dart` represents an applicable semester start and calculates semester week from a Beijing calendar date.
- Week numbering starts at one on the configured semester start date.
- One parity policy owns odd/even interpretation. Repositories, controllers, and widgets do not repeat modulo or date-boundary logic.
- Dates before every known start produce no applicable semester instead of an invented week.

### Meeting Frequency

- `week_frequency.dart` defines `every`, `odd`, and `even`.
- Parsing recognizes source tokens `每周`, `单周`, and `双周` at one boundary.
- One meeting-visibility policy identifies current-week meetings while the timetable includes all meetings by default.
- Unsupported frequency tokens map to `every` and display as `每周`.

### Course Meetings

- `course.dart` represents one normalized occurrence of a course.
- A meeting owns stable source-record identity, course name, weekday, first and last periods, room, frequency, note, and exam information.
- Weekday covers Monday through Friday. Source weekend columns are intentionally excluded from the application timetable.
- Period ranges are positive, ordered, and bounded by the imported timetable structure.
- Source text remains human-readable; parsing normalizes only format syntax needed to identify fields.

### Timetable

- `timetable.dart` owns ordered meetings and read-only projections by day, period, and preview mode.
- Vertically touching meetings with identical details on one weekday form one source-preserving group. Rendering uses one block, and group edits update every retained source identity atomically without changing workbook bytes.
- Ordering is deterministic: weekday, first period, last period, then source order.
- Display colors and responsive geometry are presentation concerns, not timetable fields.

## Data Layer (`lib/data/`)

### Application Database and Platform Paths

- `lib/app/app.dart` resolves the SQLite database in the platform application-support directory during composition.
- `app_database.dart` owns schema versions, migrations, foreign keys, transactions, integrity checks, and typed row mapping.
- Runtime data uses normalized SQLite tables and BLOBs. JSON columns are not schema substitutes.
- Production uses `path_provider` and the Dart `sqlite3` package; tests use temporary or in-memory databases.

### Schedule Acquisition

- `schedule_picker.dart` wraps `file_selector` behind one schedule-selection interface.
- Selection accepts every filename and returns bounded bytes. Content, not extension, determines compatibility. External file bytes are never modified.
- The repository never assumes an external path remains readable after picker completion.
- Cancellation is a distinct successful no-selection outcome.
- Picker failures remain distinct from workbook validation failures.

### Workbook Decoding and Layout Parsing

`schedule_xls_parser.dart` contains a pipeline with separate responsibilities:

1. Workbook decoder validates the file signature and exposes sheet cells through a package-neutral matrix interface.
2. Layout detector inspects workbook structure rather than trusting the extension or filename.
3. A layout parser handles each supported PKU shape.
4. Field parser extracts course details, source-record identity, and typed frequency.
5. Timetable validator rejects impossible coordinates and reports each field that could not be parsed for every unsupported or incomplete nonempty record.

Initial layout implementations cover legacy one-row records and newer paired rows. Both produce the same domain model. Adding a source layout requires a new recognizer/parser pair, not changes to widgets or persistence.

The spreadsheet package remains isolated behind the workbook decoder. Replacing a provisional package must not change domain or feature APIs. Relevant behavioral cases from reference projects are independently reimplemented as Dart tests; reference code and fixtures are not copied without compatible licensing.

### Schedule Repository

- `schedule_repository.dart` is the sole authority for schedule source BLOBs, parsed records, completion fields, and active-schedule selection.
- Source BLOBs retain selected workbook bytes exactly and are immutable after insertion.
- Import validates size, decodes, parses, and reports every issue before any authoritative write.
- A complete candidate is inserted and activated in one SQLite transaction.
- An incomplete candidate remains transient while the user supplies only the fields identified as failed or rejects it. Issues with the same immutable source class name share one correction prompt, and each correction is applied to matching failed fields without overwriting successfully parsed per-occurrence values. Multi-room exercise classes use the `pages`-branch classroom-choice interaction rather than a full correction form. Completed values are stored separately from source-derived values.
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

`lib/features/timetable/timetable_controller.dart` coordinates independent schedule and parity state with Flutter `ChangeNotifier`; published timetable, candidate, and domain collections are immutable.

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

- `timetable_page.dart` owns page-level actions, state selection, responsive layout choice, and Escape restoration of ephemeral page state. Per-page generation keys dispose hover overlays and reset navigation-local presentation without reverting persisted settings or data.
- `timetable_page.dart` presents Timetable, Calendar, and Settings destinations plus import/export/color-roll actions. It refreshes week configuration on every foreground resume without a manual action.
- `timetable_grid.dart` renders Monday through Friday on wide layouts using the reference 120-unit index column, 44-unit header, 100-unit period rows, 30-unit meal breaks after periods 4 and 9, and reference timetable fonts/alignment. Index cells contain only period numbers; class times belong to hover details. Course blocks show parsed remarks on a separately spaced line.
- The same `timetable_grid.dart` renders one fixed period-index column and one day on narrow layouts. Page-level horizontal gestures and previous/next buttons select Monday through Friday.
- Import feedback stays in `timetable_page.dart`; `schedule_import_review.dart` owns the completion form.
- `course_editor_dialog.dart` creates user courses and applies every valid imported-record correction immediately without changing source bytes or exposing a Save action.
- `timetable_export.dart` generates complete five-weekday PNG and XLSX files from the same grouped-span geometry as the screen. PNG adds 12 logical units of canvas padding and renders the complete table at 4× resolution; XLSX retains four role rows per period underneath merged course blocks with matching dimensions, fonts, and alignment.
- `features/settings/appearance_controller.dart` owns persistent light/dark mode, accent and theme blending, language, font family, application and timetable font scales, font weight, timetable header/index color, automatic course-text contrast, and timetable-palette state. `settings_page.dart` applies those values immediately, groups typography controls, exposes the editable Custom palette and named upstream palettes as swatches instead of indexes, and advances font family and language through cyclic buttons.
- `course_appearance` stores optional manual color, roll lock, and importance-outline color/thickness by active-source meeting identity. User-selected manual colors are fixed until the editor immediately clears the custom appearance through **Use automatic color**; rolling still clears any legacy unlocked manual colors. The same typed appearance map feeds screen, PNG, and XLSX output. Settings can persistently hide the rail's Roll colors action, and theme, course, and outline colors use the shared arbitrary-color picker.
- `features/calendar/calendar_page.dart` renders an independent personal calendar containing only user-created schedules. A vertical week-row viewport shows five rows, derives its month heading from the month owning most visible cells, and marks intrinsic month boundaries with foreground vertical and partial horizontal divider lines rather than heading-dependent cell fills; schedule boxes meet both cell side borders, and today uses a `TODAY` label. A null schedule color derives from the active theme; an optional custom color remains fixed until explicitly cleared. All-day schedules normalize to 23:59 Beijing time at repository boundaries. The larger schedule editor keeps a local draft and writes title, note, optional color, all-day/time, and optional related-class identity only on Save; Cancel performs no mutation. Primary activation of a related Calendar schedule resolves its stored source ID and reveals every occurrence sharing the immutable source class name in Timetable; long-press edits. Landscape Timetable keeps each schedule in its own cell, appends its related class as a separate styled cell, and inserts spacing between groups. Schedule hover uses the shared pointer-following overlay; primary activation navigates, and secondary-click/long-press edits. Landscape Calendar lists every class scheduled tomorrow, related upcoming schedules beneath each class, and unassociated schedules last. Only schedule cells derive a unified `DDL` label from their authoritative instant. Navigation targets use a bounded flashing outline and never open an editor merely because navigation occurred.
- The fourth navigation-rail action launches the fixed PKU Teaching Network HTTPS URL through the platform default browser. The launcher is injectable at the widget boundary so tests verify the exact URI without opening a real browser.

Widgets consume domain projections supplied by the controller. They do not filter frequency with local string checks. Every meeting block is shown; meetings outside current parity render at half opacity without cell text. In dark mode, one shared presentation rule blends weekday, index, and class backgrounds toward the active dark surface and derives readable foregrounds.

Throughout `0.0.x`, `PRAGMA user_version` remains 0. The development application does not retain backward-compatibility or migration paths.

Course colors use deterministic values selected from a persisted Roll palette and seed using the immutable workbook-parsed class name. The Custom palette persists five editable colors; other palettes preserve valid upstream values from revision `eaacca788e246a18c36ea013ced2bed6b62bd995`, excluding the malformed `##ffafcc` palette. Optional manual colors and configurable importance outlines are persisted by active-source identity. A blank optional short name replaces the full name only when explicitly entered. Course content has all-around padding and 1.5× line height; a full blank line precedes a wrapped, prefix-free remark. A successfully parsed structured tutorial remark is consumed when its separate tutorial class is created, while ambiguous source text remains available for review. Course text is black unless automatic contrast is enabled, in which case dark blocks use white. The timetable canvas is unfilled while the weekday/index surfaces share one configurable persisted color. `ui/following_hover_card.dart` supplies the shared bounded, pointer-following overlay used by class and right-pane schedule details; class detail content separates times, metadata, and related schedules with horizontal dividers.

## Durable Storage

Production storage uses one SQLite database in application support:

| Logical record | SQLite representation | Authority | Replacement rule |
|---|---|---|---|
| Imported workbook | Immutable source BLOB | Exact user-selected bytes | Insert only after bounded parsing; never update its bytes. |
| Parsed timetable | Normalized typed rows keyed to source identities | Parser plus accepted completion fields | Publish with source and active selection in one transaction. |
| Import issues and completions | Typed rows keyed to source identities | Parser issues and explicit user input | Require complete resolution before publication. |
| Week configuration | Validated TOML text and fetched-at timestamp; typed dates derived on load | Last valid public source response | Replace in one transaction after complete validation. |
| Appearance | Typed accent/theme blending, language, font family, application/timetable scale, font weight, header/index color, automatic-text-color flag, Roll palette/seed/custom colors, and source-bound course appearance rows | Explicit Settings, editor, and Roll interactions | Apply immediately and transactionally; reject styles outside the active schedule. |
| User courses | Typed full/short name and weekday rows linked to the active immutable source | Empty-cell additions | Insert, edit, or delete independently from source and parsed rows. |
| Calendar schedules | Typed title, note, selected color, date/time, all-day flag, and optional related-class source ID independent from timetable sources | User-created personal schedules | Save one complete editor draft; Cancel leaves stored schedules unchanged. |

SQLite transactions provide publication and rollback. All `0.0.x` versions keep schema version 0 without compatibility migrations. Startup integrity failure is surfaced; the app does not silently rebuild or discard source evidence.

No schedule data belongs beside the executable, in the repository, in Downloads after import, or inside installer-owned directories. The user-selected external workbook remains untouched.

## Core Data Flows

### Schedule Import

1. User invokes import from `timetable_page.dart`.
2. `timetable_controller.dart` requests bytes through `schedule_picker.dart`.
3. The controller submits bounded bytes to its `ScheduleDecoder` port, implemented by `schedule_xls_parser.dart`, without mutation.
4. Workbook decoder and selected layout parser create a candidate containing source identities, parsed records, and all issues.
5. A complete candidate proceeds directly; an incomplete candidate groups matching source-class issues into one failed-field prompt, with direct room selection for multi-room exercise classes, or waits for whole-candidate rejection.
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

1. Controller combines timetable and parity outcome.
2. Timetable exposes every meeting; domain current-week membership controls presentation opacity.
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
| Export generation/save | Report failure locally; never mutate timetable or source bytes. |

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
| `test/data/import_lifecycle_test.dart` | Controller import lifecycle against real SQLite storage. |
| `test/widget_test.dart` | Rendered application state, responsive navigation, and import cancellation. |
| `test/reference/` | Independently recreated reference behavior; provenance in `docs/REFERENCE_CASES.md`. |
| Ignored `.sample/` | User-owned local workbooks used only by explicit opt-in tests; never distributed as fixtures. |

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

AppImage and NSIS checks use their source-controlled packaging definitions. Packaged-runtime checks remain separate from Flutter compilation. The current user-approved validation scope is application logic; native build and distribution checks remain in GitHub Actions for later user-supplied CI results.

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