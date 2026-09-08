# PKU Manager

An offline-first weekday timetable for PKU students, with semester week numbers and odd/even emphasis. Korean is the default interface language; English and Simplified Chinese are available in Settings.

## Import your timetable

1. Export your timetable yourself, then select **Import** in PKU Manager.
2. Select your workbook. All filenames are selectable; the app checks its actual contents. Supported input is an Excel 97–2003 workbook containing a recognized PKU timetable layout, not arbitrary spreadsheets.
3. If information is incomplete, review the original text and complete the required fields. Ambiguous tutorial times or room alternatives need confirmation. **Reject and ignore** cancels the whole import and keeps your existing timetable.

Your original workbook is never edited. Exact source bytes and parsed timetable are retained locally. An unreadable file produces a concise message without replacing your current timetable. Files must not exceed 8 MiB.

## View classes

- On a phone, swipe left or right between Monday and Friday beside a fixed period column. Previous/next controls also support keyboard navigation.
- Wide windows show Monday through Friday together using the same timetable proportions, typefaces, time labels, row spacing, and alignment as the referenced prettifier.
- Every class is shown. Classes outside the current week appear at half opacity.
- Tap an occupied cell to edit its course information, or tap an empty cell to add a course. Imported workbook bytes remain unchanged; edits are stored separately.
- On pointer devices, hover for one second to show details beside the pointer.
- Use **Roll colors** repeatedly for another timetable color combination. Settings provides persistent accent controls and one language button that advances through Korean, English, and Simplified Chinese with each click.
- Use **Export** to save the complete Monday–Friday timetable as PNG or XLSX. PNG uses the reference timetable's four-times export scale and complete unscaled table dimensions.

Week numbers use Beijing dates and public Week Parity semester starts. A standard edition uses a 16-week semester. Outside an applicable semester, all classes appear. Configuration refreshes at startup and after every foreground resume; failures retain cached data and never block your timetable. Unsupported frequency text maps to `每周`.

## Privacy and availability

No login is requested. PKU Manager never accesses the elective system; you obtain the export yourself. Workbook processing stays on your device. Only public Week Parity configuration is fetched.

Target editions are Android, iOS, Linux AppImage, macOS application bundle, and Windows per-user installer. Apple and Windows distribution validation is pending; no signed store release is currently provided. Windows uninstall retains your timetable data.
