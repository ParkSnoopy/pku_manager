# PKU Manager

An offline-first weekday timetable for PKU students, with semester week numbers and odd/even emphasis. Korean is the default interface language; English and Simplified Chinese are available in Settings.

## Import your timetable

1. Export your timetable yourself, then select **Import** in PKU Manager.
2. Select your workbook. All filenames are selectable; the app checks its actual contents. Supported input is an Excel 97–2003 workbook containing a recognized PKU timetable layout, not arbitrary spreadsheets.
3. If information is incomplete, review the original text and complete the required fields. Ambiguous tutorial times or room alternatives need confirmation. **Reject and ignore** cancels the whole import and keeps your existing timetable.

Your workbook stays on your device and is not modified. An unreadable file does not replace your current timetable. Files must not exceed 8 MiB.

## View classes

- On a phone, swipe left or right between Monday and Friday beside a fixed period column. Previous/next controls also support keyboard navigation.
- Wide windows show Monday through Friday together using the same timetable proportions, typefaces, row spacing, and alignment as the referenced prettifier.
- Every class is shown. Classes outside the current week appear at half opacity.
- Vertically touching cells for the same course on one weekday appear as one block. Select the block to edit every session together, or select an empty cell to add a course.
- The course editor applies valid changes immediately, can choose any class color, and can set an importance-outline color and thickness. The default outline is red. Manual colors carry a lock/palette marker; locked colors survive **Roll colors**, while an unlocked manual color returns to generated colors on the next roll.
- On pointer devices, hover briefly to show class times, details, and related personal schedules beside the pointer.
- **Timetable** shows upcoming personal schedules in its landscape right pane. Selecting a timetable block replaces that pane with an editable details pane.
- **Calendar** lets you add personal schedules to the month. New schedules are all-day by default, update as you edit, and can be related to a class. Its landscape right pane shows the nearest upcoming class, while classes are never added to the month. Select either side-pane entry to open its corresponding item.
- Select **教学网** below Settings to open PKU's Teaching Network in your default browser.
- Use **Roll colors** repeatedly for another timetable color combination. Settings can select its palette, hide that navigation action, choose any theme accent, adjust text from 1.0× to 2.0× and Thin through Black, and provides one language button that advances through Korean, English, and Simplified Chinese with each click.
- Use **Export** to save the complete Monday–Friday timetable as PNG or XLSX. PNG uses the reference timetable's four-times export scale and complete unscaled table dimensions.

Week numbers use Beijing dates and public Week Parity semester starts. A standard edition uses a 16-week semester. Outside an applicable semester, all classes appear. Configuration refreshes at startup and after every foreground resume; failures retain cached data and never block your timetable. Unsupported frequency text maps to `每周`.

## Privacy and availability

No login is requested. PKU Manager never accesses the elective system; you obtain the export yourself. Workbook processing stays on your device. Only public Week Parity configuration is fetched.

Target editions are Android, iOS, Linux AppImage, macOS application bundle, and Windows per-user installer. Apple and Windows distribution validation is pending; no signed store release is currently provided. Windows uninstall retains your timetable data.
