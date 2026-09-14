# Architecture

PKU Manager is one Flutter process with infrastructure-independent domain policy, consumer-owned feature boundaries, concrete data adapters, and thin native runners. See `CONTEXT.md` for vocabulary and invariants.

## Dependency direction

```text
platform runners
       │
       ▼
lib/main.dart ──► lib/app/
                      │
             ┌────────┼────────┐
             ▼        ▼        ▼
      lib/features/  lib/data/  lib/ui/
             │        │
             └────┬───┘
                  ▼
             lib/domain/
```

- `lib/domain/` imports no Flutter, filesystem, HTTP, SQLite, spreadsheet, or platform-channel APIs.
- Features own narrow boundary interfaces and consume domain values; they do not import concrete data adapters.
- Data adapters implement consumer-owned boundaries and stop external representations at their edge.
- `lib/app/` is the only composition root and owns shared adapter/controller lifetime.
- Native runners host Flutter and contain no timetable, parity, import, or persistence policy.

## Repository ownership

| Path | Technical responsibility |
|---|---|
| `lib/main.dart` | Initialize desktop window integration, register required fonts, and start the application root |
| `lib/app/` | Construct dependencies, configure `MaterialApp`, and own the responsive navigation shell |
| `lib/domain/` | Define immutable course, timetable, semester, frequency, calendar-schedule, import, and close-action contracts |
| `lib/data/` | Adapt BIFF8 workbooks, SQLite, public TOML/HTTP, file selection, and application-support paths |
| `lib/features/timetable/` | Coordinate timetable state, rendering, editing, side panes, appearance projection, and PNG/XLSX export |
| `lib/features/calendar/` | Coordinate independently persisted personal schedules and calendar projections |
| `lib/features/settings/` | Persist and expose application/timetable appearance and desktop-close settings |
| `lib/features/schedule_import/` | Render typed recovery for parser-reported failed fields |
| `lib/l10n/` | Provide complete application-owned localized strings |
| `lib/ui/` | Isolate desktop window/tray plugins, shared overlays, focus effects, and Super OTC registration |
| `test/` | Mirror domain, adapter, repository, controller, reference, and rendered-widget ownership |
| `packaging/linux/` | Assemble the Linux release bundle and non-baseline AppIndicator libraries into an AppImage |
| `packaging/windows/` | Package the Windows release bundle as a per-user NSIS installer |
| `.github/workflows/native.yml` | Build, test, package, smoke-test, upload, and release all supported targets |

Web is not supported. Generated platform registrants contain integration glue only.

## Domain contracts

### Semester and frequency

- `semester.dart` calculates semester-relative weeks from Beijing calendar dates and ordered validated starts.
- Applicability ends at the next configured start or configured week bound.
- `week_frequency.dart` owns `every`, `odd`, and `even`; source tokens are normalized only at the parser boundary.
- Unsupported frequency text maps to `every`. Unsupported weekday data is an import issue rather than a silent omission.

### Courses and timetables

- `course.dart` separates immutable source identity/name from editable display data.
- Meetings cover Monday through Friday and retain ordered, bounded period ranges.
- `timetable.dart` owns ordering, day/period projection, parity membership, conflict detection, and continued-class grouping.
- Continued same-class cells retain every source identity and are edited or deleted atomically as one visual block.
- Colors and geometry remain presentation data, not timetable fields.

### Calendar schedules

- Personal schedules are independent records with optional source-class association.
- A relationship stores the stable class source ID; display labels are derived.
- Final-exam projection uses the shared class-period clock and only complete dated source evidence.

## Data boundaries

### Workbook import

`schedule_xls_parser.dart` is a staged boundary:

1. Validate BIFF8 input and expose cells through a package-neutral matrix.
2. Detect a supported layout from workbook structure.
3. Parse source fields into typed meetings with stable sheet/row/column identities.
4. Preserve every unsupported nonempty record as typed failed-field metadata.
5. Validate coordinates and return one immutable candidate without persistence.

Legacy one-row and paired-row layouts produce the same domain contract. New layouts add a recognizer/parser pair rather than changing features or storage.

`schedule_picker.dart` returns bounded bytes, not a durable external path. Compatibility follows content rather than filename extension. Cancellation, file acquisition failure, workbook rejection, and incomplete review remain distinct outcomes.

### SQLite

`app_database.dart` owns connection setup, foreign keys, schema creation, transactions, integrity checks, and row mapping. Production stores one SQLite database in platform application-support storage.

| Record | Authority | Mutation rule |
|---|---|---|
| Imported workbook BLOB | Exact selected bytes | Insert-only and immutable |
| Parsed meetings | Parser plus accepted field completions | Publish with source and active selection in one transaction |
| Import issues/completions | Parser metadata and explicit corrections | Resolve completely before publication |
| User meetings | Active-source overlays | Create, edit, or delete independently of source bytes |
| Calendar schedules | User-owned typed records | Persist independently; clear only invalidated class associations |
| Week configuration | Last completely validated public response | Replace atomically; retain last-known-good data on failure |
| Appearance/settings | Typed portable values plus device-local UI scale and timetable system font | Persist immediately through their owning SQLite or device-settings adapter |

Application-owned durable schema uses typed SQLite columns rather than JSON blobs. Version `0.1.0` establishes schema version `1`; valid schema-zero databases migrate in place without rewriting domain rows. Schema version `1` remains backward-compatible throughout the `0.1.x` line. A breaking schema change requires a user-authorized minor-version release and a forward migration from version `1`.

`app_data_transfer.dart` exports a consistent SQLite snapshot through the online backup API. Import writes and validates a bounded candidate, migrates legacy schema zero, snapshots the current database for rollback, and replaces the live database through the same backup API. Controllers reload only after replacement validates. The `.pkudata` container is the SQLite database itself, so `PRAGMA user_version` remains the sole format authority. `device_settings.json` separately owns display-local UI scale and the timetable's optional system-font choice without changing schema version `1`; purge clears both stores and compacts the emptied database.

### Public configuration

- `week_config_parser.dart` validates the supported TOML shape, timezone, and ascending unique ISO dates.
- `week_config_repository.dart` bounds HTTP duration and bytes, validates redirect hosts, and replaces cache only after complete parsing.
- Runtime fetches only `https://parksnoopy-undergraduate.github.io/week/config.toml`.
- Fetch or parse failure cannot block or mutate the stored timetable.

## Application flows

### Startup

1. `lib/app/app.dart` resolves application-support storage and constructs shared repositories/controllers.
2. The schedule repository loads normalized active rows and verifies the corresponding immutable source record.
3. The week repository loads validated cached configuration.
4. The controller publishes usable local state, then starts a bounded public refresh.
5. A valid response atomically replaces cache and recalculates parity; failure retains cached state.

### Import publication

1. The controller obtains bounded bytes from the picker boundary.
2. The parser returns a complete or reviewable immutable candidate.
3. Review applies values only to fields marked failed, grouped by immutable source class name where one answer governs repeated occurrences.
4. Complete source bytes, parsed rows, completion rows, derived complete exams, and active selection publish in one SQLite transaction.
5. Cancellation, rejection, parse failure, or transaction failure preserves the previously published timetable.

### Presentation and export

- Screen, PNG, and XLSX consume the same grouped-span geometry, appearance map, theme transformation, content roles, and typography authority.
- Parity affects screen emphasis without deleting meetings. Export intentionally renders the complete Monday–Friday timetable fully opaque.
- Course-name emphasis is a shared semantic role: bold on screen and in both exports while room and remark text retain configured weight.
- Pointer overlays and flashing navigation outlines are shared UI adapters, not domain state.

## Platform boundaries

| Target | Boundary |
|---|---|
| Android | Flutter host, stable application identity, derived numeric version code, Internet permission, and system document interface |
| iOS | Flutter host, system document interface, and application-support persistence |
| Linux | GTK runner plus AppImage packaging with executable-relative tray dependencies and runtime-staged tray icon |
| macOS | Flutter host, application bundle, native document selection, window management, and tray integration |
| Windows | Win32 runner plus versioned per-user NSIS installation, complete payload replacement on upgrade, launch, and uninstall |

Desktop plugin calls stay behind `lib/ui/app_window_controller.dart`. Tray setup occurs before window hiding; failure leaves the window recoverable. Linux packages non-baseline AppIndicator dependencies with `$ORIGIN` lookup and stages tray artwork under the shared runtime directory so an external indicator process can read it.

## Network and source boundaries

- No source module or development tool may access `elective.pku.edu.cn`.
- Timetable bytes, names, rooms, notes, exams, filenames, and usage data never leave the process.
- Reference behavior is independently reimplemented. AGPL/GPL source and fixtures are not copied without an approved license decision.
- Local real-workbook fixtures remain ignored unless sanitized and explicitly approved for publication.

## Verification topology

| Test area | Scope |
|---|---|
| `test/domain/` | Date, parity, frequency, ordering, continued-class grouping, conflict, and visibility policy |
| `test/data/` | TOML/HTTP boundaries, BIFF8 parsing, SQLite publication, persistence, and immutable-source equality |
| `test/reference/` | Independently authored behavior mapped in `docs/REFERENCE_CASES.md` |
| Root widget/controller tests | Responsive composition, editing, appearance, localization, export, window, and tray behavior |

Primary local checks are `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test`. Platform compilation, packaging, installed-runtime checks, and artifact publication are separate workflow evidence defined in `.github/workflows/native.yml`.