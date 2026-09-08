# Context

## Vocabulary

- `school life management application`: the whole Flutter product. Timetable and week parity are its first feature set, not the permanent limit of its scope.
- `supported platforms`: ship Android and iOS application builds, one Linux AppImage, one macOS application bundle, and one Windows NSIS installer. Web is not a supported target. A successful raw Flutter desktop build alone does not satisfy desktop support.
- `week parity`: semester-relative week number and odd/even status calculated using Beijing calendar dates and validated semester starts from the public Week Parity configuration.
- `Week Parity source`: `https://parksnoopy-undergraduate.github.io/week/config.toml` for runtime data. Hosted HTML and WASM are reference presentation, not application dependencies.
- `schedule.xls`: the file manually exported and supplied by the user. Its exact bytes are immutable source evidence retained as a SQLite BLOB; neither import nor later completion may rewrite them.
- `store timetable`: retain immutable source bytes, parsed records, parse issues, and user-supplied completion fields in the application SQLite database. Parsed and completed records remain traceable to stable source-record identities.
- `import schedule`: acquire one user-selected local file through the platform file picker, validate and parse it completely, then transactionally publish its immutable bytes and parsed structure.
- `schedule`: the product term for a user-controlled Calendar item; use `schedule`, not `event`.
- File selection is unrestricted by extension. Content detection determines compatibility. Catastrophic parsing failures show a concise message without internal details and preserve the current timetable.
- `elective site`: `elective.pku.edu.cn`. The app and development process must never fetch, scrape, probe, authenticate to, or embed it.
- `pretty timetable`: a native Flutter timetable informed by elective-prettifier behavior. Logic and tests are independently reimplemented in Dart; AGPL code and fixtures are not copied without an approved compatible license strategy.
- `dynamic timetable`: derive visible meetings from current semester parity at display time; never delete odd-week or even-week meetings from stored data.
- `每周`: meeting is visible in both odd and even weeks.
- `单周`: meeting is visible only in odd-numbered semester weeks.
- `双周`: meeting is visible only in even-numbered semester weeks.
- Frequency text outside `每周`, `单周`, and `双周` maps to `每周`.
- `current week`: week selected from current Beijing date and latest applicable validated semester start.
- `offline-first`: stored timetable remains fully usable without network access. Week configuration refresh may improve parity data but cannot gate local timetable access.
- `reference repo`: source used to understand behavior and file shapes. It is not automatically approved for code copying, dependency inclusion, or runtime access.

## Project Concepts

- Semester: ordered start date, Beijing timezone interpretation, current week number, and parity.
- Week configuration: small validated public configuration cached only after a complete successful parse.
- Course meeting: one normalized Monday–Friday course occurrence with period range, room, frequency, note, and exam information.
- Timetable: ordered collection of course meetings derived from the stored spreadsheet.
- Timetable visibility: every meeting is shown by default. Current-week meetings remain opaque; meetings outside the current week render at half opacity.
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
- Unsupported weekday source records cause an explicit import issue and are never silently discarded; unsupported frequency tokens alone map to `每周`. Saturday and Sunday source columns are intentionally outside the product timetable.
- UI is native Flutter, responsive, flat, readable, accessible, and uses no gradients.
- Mobile timetable view shows one fixed period-index column and one day column; horizontal swipes change the visible day.
- A left vertical navigation rail owns Timetable, Calendar, and Settings destinations plus a **教学网** action that opens the fixed PKU Teaching Network page in the default browser.
- Timetable geometry, typefaces, alignment, class times, meal breaks, aspect fitting, and export dimensions follow the `pages` branch of `ParkSnoopy/pku-elective-prettify`. Period-index cells show only the period number; complete start/end times appear in class hover details. Course colors fill complete course blocks. Class equality and color identity use the immutable class name parsed from the original `schedule.xls`, never a user-edited display name. Vertically touching same-name source classes on one weekday render as one group without losing their source identities.
- Landscape Timetable layouts show upcoming personal schedules without class information in the right pane; selecting a course changes that pane into the editor. Landscape Calendar layouts show the nearest upcoming class without personal schedule information. Portrait timetable selection uses a dialog.
- Pointer hover for 100 ms opens a detail box positioned beside and following the pointer until exit.
- Course and schedule editors apply every valid change immediately and expose no Save action.
- Application text defaults to 1.2× scale. Settings provide immediate 1.0×–2.0× scale and Thin–Black weight controls. Timetable classroom text matches class-name size and starts with two spaces.
- New Calendar schedules are all-day by default and may reference one timetable class by stable source ID. A class hover detail lists schedules related to any source occurrence with the same immutable source class name.
- Selecting an upcoming personal schedule opens its Calendar entry. Selecting the upcoming class opens that class from Timetable.
- Importance outlines default to red at 1.5 px.
- Roll uses a user-selectable palette identified in the UI by its exact supplied name and colors, never by an ordinal index. Palette names and valid colors come from `palette.json` at `ParkSnoopy/pku-elective-prettify` revision `eaacca788e246a18c36ea013ced2bed6b62bd995`; the upstream palette containing the malformed literal `##ffafcc` is not normalized or offered.
- Import review prompts only for fields that parsing could not determine. A multi-room exercise-class issue uses the direct classroom-choice prompt from the `pages` branch at revision `1fb0610248b8c3975fc82f8aa5248f90f4156d3e`: class name, weekday, period range, and one vertically listed room choice including an unavailable option.
- Week configuration refresh runs at startup and whenever the application returns to foreground; no manual refresh control is shown.
- Korean is the default interface language. One Settings button displays only the active language and cycles Korean → English → Simplified Chinese on successive clicks; the selection and accent color persist.
- Theme accents and manual course colors accept arbitrary palette choices. A manual course color is visibly marked and may be locked against palette rolls. Important-class outlines persist their independently selected color and thickness, defaulting to red and 1.5 logical pixels. Settings may hide the Roll colors rail action.
- Course names and classroom text use the same fixed 22.5-pixel base size, and both remain padded and truncate within the course block. Classroom text starts with two spaces.
- Calendar presents an independent personal month view for user-created schedules. It never adds timetable classes to the month. Its landscape right pane shows only the nearest upcoming class.
- The application version is `0.0.7`. Throughout `0.0.x`, the development database keeps `PRAGMA user_version = 0`; no backward-compatibility or migration code is retained until an explicit schema-version bump is requested.
- Flutter packages one Sans and one Serif Static Super OTC CJK collection, each containing Korean, Japanese, Chinese, and every static weight. Separate regional and weight-specific CJK font assets are forbidden. Sans is active; Serif is retained for future presentation use.
- Imported meetings can be edited and empty weekday cells can create user meetings. These overlays are stored separately from immutable workbook bytes.
- A persistent color-roll seed lets users generate another deterministic timetable color combination repeatedly after import.
- The complete Monday–Friday timetable exports locally as PNG or XLSX.
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