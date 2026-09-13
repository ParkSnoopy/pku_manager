# Context

This file defines project vocabulary and cross-layer invariants. Structural ownership belongs in `ARCHITECTURE.md`; development sequencing and release evidence belong in `PLAN.md`.

## Vocabulary

- `school life management application`: the complete Flutter product. Timetable and Calendar are feature modules, not architectural boundaries for future scope.
- `supported platforms`: Android, iOS, Linux AppImage, macOS application bundle, and Windows MSIX package. Web is excluded. Platform support requires packaged-runtime evidence, not compilation alone.
- `schedule.xls`: a user-supplied BIFF8 workbook. Its selected bytes are immutable source evidence stored as a SQLite BLOB.
- `import schedule`: acquire bounded bytes through the platform picker, parse every nonempty in-scope record, resolve typed failures, and publish atomically.
- `schedule`: a user-controlled Calendar record. Do not substitute `event` in product-owned names or copy.
- `source identity`: stable workbook sheet/row/column identity used to bind parsed records, corrections, appearance, and optional Calendar relationships.
- `source class name`: immutable workbook-parsed class name used for grouping, deterministic color identity, and class-wide relationships. Editable display or short names do not replace it.
- `week parity`: semester-relative week number and odd/even status calculated from Beijing dates and validated semester starts.
- `dynamic timetable`: retain all meetings and derive current-week emphasis at presentation time.
- `Week Parity source`: runtime TOML at `https://parksnoopy-undergraduate.github.io/week/config.toml`.
- `elective site`: `elective.pku.edu.cn`; prohibited for application and development-process access.
- `reference repo`: source inspected for behavior or file shape, without permission to copy implementation or fixtures.

## Source and import invariants

- File compatibility follows content, not filename or extension.
- Selected workbook bytes remain byte-for-byte unchanged. Parsed rows, failed-field metadata, corrections, user meetings, and appearance are separate records.
- Parsing is complete before authoritative writes. Unsupported nonempty records become explicit typed issues and are never silently omitted.
- Cancellation, rejection, acquisition failure, parse failure, incomplete review, and transaction failure preserve the active timetable.
- Corrections apply only to parser-identified failed fields. Issues sharing one source class name may share one answer without overwriting successfully parsed occurrence data.
- Saturday and Sunday source columns are outside the timetable; unsupported weekday records must still fail explicitly rather than disappear.
- Imported meetings may be edited through overlays, and user meetings remain separate from immutable source rows.
- A complete dated final exam may create one related Calendar schedule during the same publication transaction. Incomplete date evidence is never guessed.
- Real parser acceptance requires an approved sanitized workbook; synthetic matrices alone establish only isolated parser behavior.

## Time and parity invariants

- `每周`, `单周`, and `双周` map to every, odd, and even weeks. Other frequency text maps to `每周`.
- Semester calculations use Beijing calendar dates, the latest applicable validated start, the next-start boundary, and the configured week bound.
- Week configuration refresh is independent of local timetable availability. Invalid or unavailable responses retain the last validated cache.
- No parity failure may block, delete, or rewrite stored timetable data.

## Persistence invariants

- One SQLite database in platform application-support storage owns workbook BLOBs, parsed and user meetings, issues/corrections, Calendar schedules, week cache, and appearance/settings.
- Publication and class-wide mutation are transactional. Advisory refresh or presentation failures cannot partially mutate authoritative state.
- Relationships persist stable IDs only; labels and mutable state are derived from authoritative records.
- Application-owned schema-like data uses typed SQLite columns, Protobuf, or XML rather than JSON.
- Version `0.1.0` establishes `PRAGMA user_version = 1` and migrates valid schema-zero databases without data loss.
- Schema version `1` remains backward-compatible throughout `0.1.x`. Breaking schema changes require the user to authorize the next minor version manually and must include a forward migration.
- App-data export uses a consistent SQLite snapshot. Import validates and migrates a bounded candidate before replacing current data, and restores the prior database if replacement fails.
- Runtime data never belongs beside the executable, inside the repository, in installer-owned directories, or in an external workbook path.

## Presentation invariants

- UI is native Flutter, responsive, flat, accessible, and contains no gradients.
- In-app copy contains only information required to decide, act, correct, recover, or understand current state. Implementation details and defensive assurances are excluded.
- Wide timetable layouts render Monday through Friday; narrow layouts retain one period-index column and one selected weekday projection.
- All meetings retain their grid footprint. Non-current meetings use reduced emphasis without cell text; conflict calculation remains domain-owned and excludes odd/even-only alternation.
- Vertically adjacent meetings with the same source class name and weekday share one visual block while preserving every source identity.
- Screen, PNG, and XLSX use one geometry, grouping, color, outline, content-role, and typography authority. Export renders the complete timetable fully opaque.
- Class names are bold across screen and exports. Room and remark text retain configured timetable weight.
- Calendar schedules remain independent records. Optional class association is ID-based and must be cleared, not delete the schedule, when its class disappears.
- Timetable and Calendar cross-navigation changes transient presentation only. Escape-style restoration must not revert persisted state.
- Appearance settings persist typed values and apply through one shared projection. Manual course colors and outlines are source-identity-bound; generated labels/colors are derived.
- Korean, English, and Simplified Chinese localization must cover every application-owned visible string.

## Platform and security invariants

- Product identity is PKU Manager by ParkSnoopy. Android/Linux use `com.parksnoopy.pku_manager`; Apple uses `com.parksnoopy.pku-manager` because Apple bundle identifiers prohibit underscores.
- Native runners and plugins bridge platform facilities only; product behavior remains in Dart.
- Desktop close behavior is typed and persisted. Tray creation precedes hiding, explicit tray exit destroys the application, and tray failure leaves the window visible.
- Linux AppImage libraries resolve executable-relative. Tray artwork is staged under a shared runtime path readable outside AppImage/Firejail mount namespaces.
- Runtime network access is limited to the validated Week Parity endpoint. Timetable content, filenames, and usage data never leave the process.
- No application or development command may request, scrape, probe, authenticate to, or embed `elective.pku.edu.cn`.
- Reference code and fixtures remain independently reimplemented unless license compatibility or explicit permission is established. Provenance is recorded in `docs/REFERENCE_CASES.md`.
- Ignored local workbook samples are not publication assets or license grants.