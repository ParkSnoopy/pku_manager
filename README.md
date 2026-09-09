# PKU Manager

An offline-first weekday timetable for PKU students, with semester week numbers and odd/even emphasis. Korean is the default interface language; English and Simplified Chinese are available in Settings.

## Import your timetable

1. Export your timetable yourself, then select **Import** in PKU Manager.
2. Select your workbook. All filenames are selectable; the app checks its actual contents. Supported input is an Excel 97–2003 workbook containing a recognized PKU timetable layout, not arbitrary spreadsheets.
3. If information is incomplete, the app asks only for values it could not parse. One correction applies to every matching occurrence of the same class. Tutorial-room alternatives appear as a direct classroom choice with the class day and periods. **Reject and ignore** cancels the whole import and keeps your existing timetable.

Your workbook stays on your device and is not modified. An unreadable file does not replace your current timetable. Files must not exceed 8 MiB.

## View classes

- On a phone, swipe left or right between Monday and Friday beside a fixed period column. Previous/next controls also support keyboard navigation.
- Wide windows show Monday through Friday together using the same timetable proportions, typefaces, row spacing, and alignment as the referenced prettifier.
- Every class block is shown. Classes outside the current week appear at half opacity without cell text.
- Vertically touching cells for the same course on one weekday appear as one block. Select the block to edit every session together, or select an empty cell to add a course.
- The course editor applies valid changes immediately, supports a blank-by-default short name, can choose any class color, and can set an importance-outline color and thickness. The default outline is red. A custom class color remains fixed across **Roll colors** until **Use automatic color** immediately removes the custom color and then disappears.
- Course blocks have padding on every side, 1.5× line spacing, and a blank line before parsed remarks. Structured remarks already converted into a separate class, such as an exercise class, are not repeated.
- On pointer devices, hover briefly to show class times, separated details, and related personal schedules beside the pointer.
- **Timetable** uses a transparent grid canvas while retaining a configurable header/index color. Dark mode blends the header, index, and class-cell colors into the dark surface. Each upcoming personal schedule stays in its own box, with its related class appended below in a separately styled cell. Every right-pane schedule and class shows its remaining time as **DDL**. All-day schedules omit a redundant time label. Selecting one opens its details first, with a separate action to reveal it in Calendar.
- **Calendar** gives adjacent-month cells a light-grey background. New schedules begin with a blank title, use the current theme color by default, and are applied with **Save** or discarded with **Cancel**. All-day schedules use 23:59 Beijing time as their deadline. Schedules can include a note, fixed custom color, time, and related class; **Use theme color** immediately removes a selected custom color. Its landscape right pane lists every class scheduled tomorrow, each class's upcoming schedules, and then unassociated schedules after a separator. Every listed item shows its remaining time as **DDL**. Navigation entries briefly flash their target without leaving it selected.
- Select **教学网** below Settings to open PKU's Teaching Network in your default browser.
- Use **Roll colors** repeatedly for another timetable color combination. Settings can enable dark mode, shows each palette by its supplied name and colors, can hide that navigation action, choose any theme accent or timetable header color, enable automatic light text on dark course colors, adjust text from 1.0× to 2.0× and Thin through Black, and provides one language button that advances through Korean, English, and Simplified Chinese with each click.
- Use **Export** to save the complete Monday–Friday timetable as PNG or XLSX. PNG uses the reference timetable's four-times export scale and complete unscaled table dimensions.

Week numbers use Beijing dates and public Week Parity semester starts. A standard edition uses a 16-week semester. Outside an applicable semester, all classes appear. Configuration refreshes at startup and after every foreground resume; failures retain cached data and never block your timetable. Unsupported frequency text maps to `每周`.

## Privacy and availability

No login is requested. PKU Manager never accesses the elective system; you obtain the export yourself. Workbook processing stays on your device. Only public Week Parity configuration is fetched.

Target editions are Android, iOS, Linux AppImage, macOS application bundle, and Windows per-user installer. Apple and Windows distribution validation is pending; no signed store release is currently provided. Windows uninstall retains your timetable data.
