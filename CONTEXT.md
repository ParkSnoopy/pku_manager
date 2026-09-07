# Context

## Vocabulary

- `school life management application`: the whole Flutter product. Timetable and week parity are its first feature set, not the permanent limit of its scope.
- `supported platforms`: ship Android and iOS application builds, one Linux AppImage, one macOS application bundle, and one Windows NSIS installer. Web is not a supported target. A successful raw Flutter desktop build alone does not satisfy desktop support.
- `week parity`: semester-relative week number and odd/even status calculated using Beijing calendar dates and validated semester starts from the public Week Parity configuration.
- `Week Parity source`: `https://parksnoopy-undergraduate.github.io/week/config.toml` for runtime data. Hosted HTML and WASM are reference presentation, not application dependencies.
- `schedule.xls`: the file manually exported and supplied by the user. Its exact bytes are immutable source evidence retained as a SQLite BLOB; neither import nor later completion may rewrite them.
- `store timetable`: retain immutable source bytes, parsed records, parse issues, and user-supplied completion fields in the application SQLite database. Parsed and completed records remain traceable to stable source-record identities.
- `import schedule`: acquire one user-selected local file through the platform file picker, validate and parse it completely, then transactionally publish its immutable bytes and parsed structure.
- File selection is unrestricted by extension. Content detection determines compatibility. Catastrophic parsing failures show a concise message without internal details and preserve the current timetable.
- `elective site`: `elective.pku.edu.cn`. The app and development process must never fetch, scrape, probe, authenticate to, or embed it.
- `pretty timetable`: a native Flutter timetable informed by elective-prettifier behavior. Logic and tests are independently reimplemented in Dart; AGPL code and fixtures are not copied without an approved compatible license strategy.
- `dynamic timetable`: derive visible meetings from current semester parity at display time; never delete odd-week or even-week meetings from stored data.
- `每周`: meeting is visible in both odd and even weeks.
- `单周`: meeting is visible only in odd-numbered semester weeks.
- `双周`: meeting is visible only in even-numbered semester weeks.
- `unknown frequency`: nonempty frequency text outside `每周`, `单周`, and `双周`; preserve and display it with a warning rather than hiding the meeting.
- `current week`: week selected from current Beijing date and latest applicable validated semester start.
- `offline-first`: stored timetable remains fully usable without network access. Week configuration refresh may improve parity data but cannot gate local timetable access.
- `reference repo`: source used to understand behavior and file shapes. It is not automatically approved for code copying, dependency inclusion, or runtime access.

## Project Concepts

- Semester: ordered start date, Beijing timezone interpretation, current week number, and parity.
- Week configuration: small validated public configuration cached only after a complete successful parse.
- Course meeting: one normalized course occurrence with weekday, period range, room, frequency, note, and exam information.
- Timetable: ordered collection of course meetings derived from the stored spreadsheet.
- Preview mode: current, odd, even, or all view over the same timetable; it never mutates source data.
- Schedule repository: sole authority for importing immutable workbook bytes and publishing parsed timetable records through one SQLite transaction.
- Spreadsheet parser: infrastructure adapter that converts supported PKU workbook layouts into domain meetings while reporting every unsupported nonempty record.
- Source record identity: stable workbook location identity used to associate parsed records and user completion fields without changing source bytes.
- Application database: one SQLite database in private platform-managed application-support storage containing source BLOBs, parsed records, completion fields, issues, week configuration, and freshness metadata.
- Application-support storage: private platform-managed durable directory, not Downloads, current working directory, or a path beside the executable.
- AppImage: distributable Linux application bundle built from the release bundle and verified by launching the exact packaged artifact.
- NSIS installer: Windows installer around the complete Flutter release output, with explicit install, upgrade, retained-data, and uninstall behavior.

## Invariants

- No automated access to `elective.pku.edu.cn` under any circumstance.
- Candidate schedule must parse successfully before replacing existing data.
- Import cancellation, rejection, and failure leave existing schedule unchanged.
- Original spreadsheet bytes remain byte-for-byte unchanged and authoritative. Parsed records and user completion fields are separate, traceable application data.
- An incomplete candidate reports every discovered issue. The user may complete required information and import, or reject the whole candidate. Unsupported records are never silently omitted.
- Week refresh failure never blocks viewing a stored timetable.
- Only validated Week Parity configuration can replace the last valid cache.
- Parity uses Beijing calendar dates, not an arbitrary device-local midnight.
- Unknown source data remains visible or causes an explicit import issue; it is never silently discarded.
- Weekend classes remain supported.
- UI is native Flutter, responsive, flat, readable, accessible, and uses no gradients.
- Mobile timetable view shows one fixed period-index column and one day column; horizontal swipes change the visible day.
- Product identity must be consistent across Flutter, Android, iOS, Linux, macOS, Windows, AppImage, and NSIS metadata.
- Platform support means packaged-runtime verification, not compilation alone.
- Product behavior stays in Dart. Flutter plugins or narrow Dart wrappers may bridge native platform or SQLite facilities, but native code does not own timetable or parity rules.
- Application-owned schema-like interchange uses Protobuf or XML instead of JSON. External source formats remain unchanged at their boundaries.
- AGPL-licensed source, tests, and fixtures are not copied until licensing obligations are explicitly accepted or permission is obtained. Every relevant reference behavior and test scenario is independently represented in Dart tests.
- Real parser compatibility requires a user-provided sanitized fixture; synthetic examples alone are insufficient.
- Semester applicability ends after the build-configured week count or at the next configured semester start, whichever comes first.

## Known Boundaries

- Product identity is PKU Manager, published by ParkSnoopy. Android/Linux use `com.parksnoopy.pku_manager`; Apple uses `com.parksnoopy.pku-manager` because Apple identifiers prohibit underscores.
- Flutter domain, SQLite adapters, import review, responsive timetable, and native packaging/workflow definitions are implemented. Platform distribution acceptance is separate from application logic verification.
- User-provided workbooks under ignored `.sample/` may be used locally but are never copied into tracked tests. Tests opt in using `SCHEDULE_FIXTURE`; fixture content is not a license grant or publication permission.
- The pure-Dart `excel2003` reader parses the local BIFF8 source. Paired-row layout coverage also uses independently authored cases.
- Reference repositories are `parksnoopy-undergraduate/week-parity` and `ParkSnoopy/pku-elective-prettify`; provenance is recorded in `docs/REFERENCE_CASES.md`.
- Semester configuration exposes start dates but no explicit semester end dates.
- Apple runtime verification requires macOS CI or Apple hardware; Windows installer verification requires Windows CI or a Windows machine.