# Context

## Vocabulary

- `school life management application`: the whole Flutter product. Timetable and week parity are its first feature set, not the permanent limit of its scope.
- `support Android/Linux(appimage)/Windows(nsis installer)`: ship installable Android output, one Linux AppImage, and one Windows NSIS installer. A successful raw Flutter desktop build alone does not satisfy support.
- `week parity`: semester-relative week number and odd/even status calculated using Beijing calendar dates and validated semester starts from the public Week Parity configuration.
- `Week Parity source`: `https://parksnoopy-undergraduate.github.io/week/config.toml` for runtime data. Hosted HTML and WASM are reference presentation, not application dependencies.
- `schedule.xls`: the file manually exported and supplied by the user. It is the authoritative timetable record retained in application-support storage.
- `store timetable`: preserve original `schedule.xls` bytes across restarts. Parsed meetings are derived state unless a later feature requires independent user-authored data.
- `import schedule`: acquire one user-selected local file through the platform file picker, validate and parse it completely, then atomically replace the prior stored schedule.
- `elective site`: `elective.pku.edu.cn`. The app and development process must never fetch, scrape, probe, authenticate to, or embed it.
- `pretty timetable`: a native Flutter timetable informed by the elective-prettifier output contract. It does not mean embedding that website or copying its AGPL source without an approved license strategy.
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
- Schedule repository: sole authority for loading and atomically replacing stored `schedule.xls`.
- Spreadsheet parser: infrastructure adapter that converts supported PKU workbook layouts into domain meetings while reporting every unsupported nonempty record.
- Application-support storage: private platform-managed durable directory, not Downloads, current working directory, or a path beside the executable.
- AppImage: distributable Linux application bundle built from the release bundle and verified by launching the exact packaged artifact.
- NSIS installer: Windows installer around the complete Flutter release output, with explicit install, upgrade, retained-data, and uninstall behavior.

## Invariants

- No automated access to `elective.pku.edu.cn` under any circumstance.
- Candidate schedule must parse successfully before replacing existing data.
- Import cancellation and failure leave existing schedule unchanged.
- Original spreadsheet bytes remain authoritative; derived labels and parsed state are not duplicated in storage without need.
- Week refresh failure never blocks viewing a stored timetable.
- Only validated Week Parity configuration can replace the last valid cache.
- Parity uses Beijing calendar dates, not an arbitrary device-local midnight.
- Unknown source data remains visible or causes an explicit import issue; it is never silently discarded.
- Weekend classes remain supported.
- UI is native Flutter, responsive, flat, readable, accessible, and uses no gradients.
- Product identity must be consistent across Flutter, Android, Linux, Windows, AppImage, and NSIS metadata.
- Platform support means packaged-runtime verification, not compilation alone.
- AGPL-licensed source is not copied until licensing obligations are explicitly accepted or permission is obtained.
- Real parser compatibility requires a user-provided sanitized fixture; synthetic examples alone are insufficient.

## Known Boundaries

- Repository currently contains only the Flutter starter application.
- Product name and publisher identity are not finalized.
- No sanitized PKU schedule fixture is present.
- Spreadsheet reader choice is provisional until fixture-backed validation.
- Week Parity repository URL currently appears inconsistent; deployed configuration is the known usable data source.
- Semester configuration exposes start dates but no explicit semester end dates.
- Windows installer verification requires Windows CI or a Windows machine.