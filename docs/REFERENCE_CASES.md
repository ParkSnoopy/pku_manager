# Reference cases and independently authored coverage

## Evidence and scope

Both authenticated GitHub repository trees were enumerated recursively before individual files were read. The pinned trees were not truncated. Each text file was then read through `gh api -H 'Accept: application/vnd.github.raw+json' repos/OWNER/REPO/contents/PATH?ref=REVISION`. No repository was cloned, no upstream program was executed, and no elective-site request was made. The icon was inventoried by its tree hash, not downloaded. File hashes below are **Git blob SHA-1 identifiers**, not ordinary file SHA-1 digests. All tracked text files, including build metadata and lockfiles, were inspected; executable behavior resides in the modules described below.

The Dart tests use invented course names, rooms, dates, and in-memory matrices. They contain no copied upstream implementations, test bodies, private fixtures, or local `.sample` data. They call the existing domain and parser APIs, not reconstructed Python/Rust helpers. Structural format tokens are necessary interoperability vocabulary. Neither upstream license is treated as permission to copy code: week-parity has GPL text; elective-prettify has AGPL text.

This inventory distinguishes upstream assertions, behavior inferred directly from source, deliberate product differences, and unverified presentation/export behavior. A passing parser test is not visual verification. Synthetic matrix coverage is not proof of real BIFF workbook compatibility; the parent task owns approved local-sample verification.

## Every upstream test scenario

`week-parity` contains exactly nine Rust test functions: six in `src/date.rs`, three in `src/config.rs`. All other Rust modules were checked for embedded tests. `pku-elective-prettify` contains no test files, test functions, or test-framework dependency in the inspected revision; its entries below are **source-derived scenarios**, not claimed upstream tests.

| Upstream semantic assertion | Independent Dart case |
|---|---|
| Start date itself is first, odd week | W01: offset 0 |
| Seven elapsed calendar days give second, even week | W02: offset 7 |
| Thirteen elapsed days remain second, even week | W03: offset 13 |
| Fourteen elapsed days give third, odd week | W04: offset 14 |
| Earlier date reports before-start status | W05: no applicable semester, native-domain equivalent |
| Select latest configured start not after current date | W06 |
| Read base-date list and timezone | W07 |
| Missing base-date field fails | W08 |
| Missing timezone field fails | W09 |

## Week-parity source behavior inventory

- **Dates (`date.rs`)**: ISO calendar-date parsing; negative elapsed days produce before-start status; integer seven-day groups start at week one; odd/even status alternates without an upstream semester-length limit. Latest-date selection examines all entries rather than relying on input order; when every date is future it chooses the earliest; an empty list produces no selection. Current date uses JavaScript Intl formatting for the configured timezone and propagates formatting failures.
- **Configuration (`config.rs`, `config.toml`)**: fetch relative `config.toml`, require successful HTTP status and text conversion, locate bracketed base-date values and quoted timezone, reject missing/empty date list and missing timezone. The upstream parser is a small string extractor rather than a general TOML parser; it does not validate chronological order, duplicate dates, date validity, or supported timezone at this boundary. Runtime config supplies several semester starts and Beijing timezone.
- **App (`app.rs`, `lib.rs`, `main.js`)**: initialize theme, then asynchronously load config; obtain today and selected semester; fallback to today if selection is absent. Render sorted start-date options with a selected entry and a native current-date picker. Both controls have accessible names; change events update their corresponding visible labels and recompute status. Invalid event targets are ignored. Event-listener render errors are ignored; startup rejection is logged by the JS bootstrap. Library exports a synchronous week-status function and async application entry.
- **Status (`status.rs`)**: before-start status is plain text; valid status combines week number and a localized odd/even badge with separate CSS classes.
- **DOM (`dom.rs`)**: missing window, document, or requested element returns explicit errors.
- **Theme (`theme.rs`)**: initial mode follows system preference; manual button alternates light/dark; a subsequent system preference change overrides the manual selection. Root theme attribute, button text, accessible pressed state, and next-action label update together. No persisted preference.
- **Layout (`index.html`, CSS)**: centered single card, maximum 480px width, 12px rounded border, two separated label/value rows, and result below. Body uses viewport-relative side padding. At 640px and below card padding and heading/result sizes shrink. Theme control is fixed at upper left. Date controls are hidden until hover or focus-within and float to the left of the displayed date. Odd badge is blue, even badge pink; light/dark token palettes differ. Card and floating controls use shadows. Main heading has a small uppercase monospaced eyebrow. Actual CSS uses sans-serif text despite README's serif-design description.
- **Build**: Rust cdylib/rlib compiled to WebAssembly, browser bindings, JS initialization, and static hosting; no native packaging implementation upstream.

W10–W15 add product-required validation, comment/trailing-comma support, Beijing midnight including leap day, exclusive configured semester end, next-start truncation, and week-count limits. Native policy intentionally rejects unsorted/duplicate dates and unsupported timezones, returns no semester before every start, fixes timezone to Beijing, and stops after the configured semester length. It does not reproduce upstream arbitrary date-selection UI or unbounded week numbers. Fetch, browser DOM, accessibility, CSS, system-theme events, and packaging have no domain/parser seam and are **not exercised by this suite**.

## Elective-prettify source behavior and case map

### Input and field parsing

| Behavior observed in source | Dart case / native treatment |
|---|---|
| Read first workbook sheet, remove first header row and first index column | E12 verifies structural header/index removal; current Dart decoder intentionally rejects multiple sheets |
| Empty spreadsheet cells become empty timetable slots | E13 |
| Default omits final Saturday/Sunday columns | E14 intentionally omits both days per product requirement |
| Coordinates correspond to period rows and weekday columns | E12, E15, E16, E20 |
| Parse title, room, remark, main frequency, and exam | E01, all three recognized frequency tokens |
| Normalize halfwidth/fullwidth delimiters | E02 |
| Fold one-character parenthesized title qualifiers back into title | E03 preserves qualifier semantics, without requiring upstream inserted whitespace |
| Upstream strips all ASCII spaces before splitting | E04 intentionally retains human-readable spaces and exact raw text |
| Empty/malformed field sets can cause upstream unpack/index/regex failures | E05–E07 test valid empty remark and explicit review instead of silent omission |
| Main frequency chosen from outside tutorial remark | E11 |
| Additional parenthesized fields become appended remark text, separated by semicolons | E08 tests preservation without corrupting primary frequency |
| Upstream assumes recognized frequency; native unknown values must remain visible and retain text | E09, E26 |
| Exact cell equality uses class/type, title and coordinates; partial equality uses title | E17–E19 intentionally retain source-location identities, not title-based deduplication |

### Tutorial extraction

`cell.py` has two tutorial-note recognizers: a verbose time/classroom phrase and a shorter phrase with an optional period-unit suffix. Both derive tutorial label, frequency, weekday, inclusive period range, and room alternatives. The surrounding code tries both recognizers, prints combined failures if neither works, and otherwise clears the main note after creating the tutorial. It requires a table object; asks the user to select one room from alternatives; converts Chinese weekday and one-based inclusive periods into zero-based cells; deduplicates appended tutorials by derived title and coordinates. `table.py` subsequently writes appended cells into the timetable, potentially overwriting an occupied destination. A repeated tutorial title may suppress a distinct later note. Weekend destinations may exceed the default weekday-only grid. These are observable source behaviors, not safe rules to reproduce literally.

- E10 independently represents **both note forms**, multiple room alternatives, and unrecognized tutorial syntax.
- E25 covers a single room, repeated parent occurrences, occupied destination, out-of-bounds period, and weekend destination. It checks original records and stable identity retention.
- The native safe expectation is explicit derived meetings **or a review issue**, never silently accepting an unscheduled tutorial. No arbitrary room choice or destructive overwrite is allowed. Current production expands unambiguous weekday tutorials, identifies only fields that failed parsing, and reproduces the `pages` branch's direct class/day/period classroom chooser for multi-room exercise classes.

### Table and rendering behavior

`table.py` exposes shape, row, column, cell, coordinates, and four orthogonal neighbors with edge bounds. Color preparation clears existing labels and per-title memory. Color assignment traverses columns then rows, skips empty/already-colored cells, treats palette index zero as a valid assigned label, avoids labels used by neighboring cells, and reuses a vertically adjacent same-title label. Group-by-class additionally reuses a title's remembered color across positions; random mode does not globally group. Missing neighbor labels are removed from the exclusion set. No available label raises an upstream random-choice error. Although a palette size is passed into the assignment wrapper, the call to the label picker omits it and falls back to the default size. Re-preparing allows recoloring without reparsing.

The native equivalents exposed by the domain are deterministic ordering, period/day projection, stable identities, and presentation-only consecutive grouping (E17–E20, E26). Product class equality uses the immutable workbook-parsed class name; room, frequency, note, exam, and edited display name do not redefine it. **Random palette selection, adjacency color exclusion, zero-label bookkeeping, and recoloring have no existing domain/data API and are not asserted here.** Native deterministic accessible colors are a presentation responsibility, not a requirement to reproduce the upstream random algorithm.

### Output layout, formats, and CLI

- `excel.py` creates one `Timetable` sheet and hides gridlines. The source has **one row per period**; the generated XLSX has **two physical rows per period plus one header**. These are not two upstream input parsers. Index cells merge vertically across each pair, show period number and teaching time; course cells themselves are not vertically merged.
- Index column width is 16; weekday widths are 24 by default. When weekends are enabled the F–H range is set to 22 (including Friday). Header height is 24; upper content rows are 32 and lower rows 24. Index and headers have gray fill and centered text; index has a stronger right border and headers a stronger bottom border.
- Upper course row contains a bold title and room/frequency subtitle, with normal palette fill. Lower row contains note, an optional newline only when note is nonempty, and exam text, with lighter fill and bottom border. Course text is wrapped and top/left aligned. SimHei is the main font, Consolas is used for period times. Header/index fonts are 10pt, title 9.5pt, subtitle 10pt, detail 7pt, emphasized period number 16pt.
- Empty ordinary cells receive a bottom border on their lower row. The final day column is handled separately: upper and lower rows get right borders, including empty cells; its header also gets a right border. The top-left header/index corner has a full thin border.
- `consts.py` defines twelve teaching-time slots from morning through late evening, numeral mapping, a five-color default, weekday-only default, and two lightening iterations. E15 protects all twelve periods, **not the presentation time labels**.
- `palette.py` selects a color by label; lighter fill uppercases hex text and increments each hex digit twice, saturating at F. `palette.json` supplies eleven five-color variants. This is digit-wise lightening, not RGB interpolation.
- `formatter.py` accumulates base format settings; each temporary override deep-copies them rather than changing the base.
- `options.py` prompts for palette JSON path, palette choice, and whether equal titles share colors (default yes).
- `cli_utils.py` checks for a manually downloaded file, otherwise asks for confirmation and can abort; input/output paths are chosen interactively. Format choices are PNG, XLSX, or both. PNG conversion loads the first sheet, uses 300 DPI and 0.15 margins, renders its populated bounds, and disposes the converter.
- `cli.py` always generates XLSX first. PNG is Windows-only; requesting it elsewhere prints an error and exits the generation loop before normal cleanup. On Windows it can open the PNG, remove intermediate XLSX for PNG-only output, and rerun generation with new choices. Input stem uses the segment before the first dot. No automated schedule download is implemented.
- Build scripts bake dependency requirements and package a Windows one-file executable with icon, native converter libraries, and version metadata. Requirements/lockfiles describe dependencies; output directory placeholder is not runtime behavior.

E21 guards paired detail-row preservation or explicit fail-closed handling. Dedicated parser tests cover recognized paired layouts. E22–E24 protect unmapped populated columns, immutable candidate bytes, and invalid workbook signatures. Against `pages` tree `1fb0610248b8c3975fc82f8aa5248f90f4156d3e`, the application independently implements the observable timetable contract: 120-unit index width, 44-unit header, 100-unit period rows, 30-unit meal breaks after periods 4 and 9, reference class times and fonts, 1.15 fitted aspect, 12-unit export padding, and 4× PNG output. Course color selection is intentionally application-owned. CJK coverage and weights come from upstream Sans and Serif Static Super OTC assets; Serif is reserved for future use. The exact upstream Noto CJK and Roboto Mono license notices remain beside the font assets.

## Execution and defects

Current independently authored reference tests pass. E07/E08 parser gaps were fixed; E09 now follows product policy by mapping unsupported frequency text to `每周`; E10/E25 produce deterministic tutorial meetings or explicit completion issues. The suite does not execute upstream code. Positive BIFF decoding remains covered only by the opt-in local workbook test, while HTTP, SQLite lifecycle, and Flutter presentation have separate application tests.

## Pinned upstream file inventory

### `parksnoopy-undergraduate/week-parity`

Revision: `9b2f2e1916e98731d3bb556a68e55ac12f52e8a8`. Tree: `129a0348af964055058bfeaca99bdc1519d954a3`.

| Path | Git blob hash | Inspection |
|---|---|---|
| `.gitignore` | `e5939bb9860d32d1ea96f453d160414d4195c079` | Raw text read |
| `Cargo.lock` | `9c464aa09961ac24da392cf4f9e0c65d828d0512` | Raw text read |
| `Cargo.toml` | `7424476736e2110debc03d20d5499bbc4277c754` | Raw text read |
| `LICENSE` | `d159169d1050894d3ea3b98e1c965c4058208fe1` | Raw text read |
| `README.md` | `c851558a30d17312fe47037ef67bc63da81596f9` | Raw text read |
| `config.toml` | `56184eafcafed888ff76e9edf115ebfb8b4666e3` | Raw text read |
| `index.html` | `a390c88f08a3047812e920e40abbfe4da61bfee7` | Raw text read |
| `src/app.rs` | `48646d32355e7721ada6c1b21fa11895e519057f` | Raw text read |
| `src/config.rs` | `5e1be4350731774ac3525174d7c6b5d7fea0c62d` | Raw text read |
| `src/date.rs` | `a701326a37cb4f3f73f8ecd063fa586fac2f3f98` | Raw text read |
| `src/dom.rs` | `6aa9c89ffbaf241076e9657be65361a946fb8de4` | Raw text read |
| `src/lib.rs` | `94d9d8cd525efaba570ecee4670430b0ea6da3fb` | Raw text read |
| `src/status.rs` | `4637085f94551f67f6d261641acfe3ba2b85015e` | Raw text read |
| `src/theme.rs` | `3a235835d94f504b4496c0abba2887b6e2fe8bbb` | Raw text read |
| `static/css/styles.css` | `327ebcc2da9aee529b7aa50d56d85d19fe9b508f` | Raw text read |
| `static/js/main.js` | `acddf9204cd17efb7c727d4c7949feab0a1acc72` | Raw text read |

### `ParkSnoopy/pku-elective-prettify`

Revision: `eaacca788e246a18c36ea013ced2bed6b62bd995`. Tree: `4fc5cdf8a911fef8ffcb56b1f11ec2122d93bae2`.

| Path | Git blob hash | Inspection |
|---|---|---|
| `.gitignore` | `9dafff1a933101781fc7ff37fda710c0d1536377` | Raw text read |
| `.python-version` | `24ee5b1be9961e38a503c8e764b7385dbb6ba124` | Raw text read |
| `LICENSE` | `0ad25db4bd1d86c452db3f9602ccdbe172438f52` | Raw text read |
| `README.md` | `2e3a6ce37a49f81ec9f0b18e49a3db33e1c2e040` | Raw text read |
| `assets.build/PKU.icon.ico` | `e752105658a90bdb3958e3fbfbb68be64717238d` | Binary metadata only |
| `bake-deps.bat` | `0da4fe86c193e877fb7cdcbfbb4d9ecb71d64ab5` | Raw text read |
| `build.nuitka.bat` | `84658e5c2f49ddf67d92e568a6dc7342c20ad6ab` | Raw text read |
| `cli.py` | `d23c69c3b4094a410d302d86b41a505534a401f5` | Raw text read |
| `cli_utils.py` | `e5e7964c9afe780bc3f068ad9b36e90bbfbb41ba` | Raw text read |
| `output/.gitkeep` | `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` | Raw text read |
| `palette.json` | `5ebc1270ab123a4fe8fb57c745bda5a55e56da4a` | Raw text read |
| `pyproject.toml` | `cb2a5ee847e88236747944ae35599c6bcf8881c2` | Raw text read |
| `requirements.txt` | `cfcdb5d641d443c1dfeb97134e49755ab1ba3d09` | Raw text read |
| `src/cell.py` | `e8d03aba91bb2acf869a1d863184c6467a782850` | Raw text read |
| `src/consts.py` | `63fbe6fdeb7eb5a1264da97fb78fe357d010cdc7` | Raw text read |
| `src/excel.py` | `a46063da098ca6b54360d61cbabe5dd4953d0dc3` | Raw text read |
| `src/formatter.py` | `19a7eca481a4b49ccd02c4ff7fb1389204890688` | Raw text read |
| `src/lib.py` | `b62034e35b8b1df4b21a2ad65c4e8ff37247084f` | Raw text read |
| `src/options.py` | `bdd7f1724cf9c6f7c7a68e30038d5d87a5b02401` | Raw text read |
| `src/palette.py` | `060a2bdcd65d5fccec525e3401e0a5ccce3629a7` | Raw text read |
| `src/table.py` | `74f12cd9ef60b17a5f50b14e30ec1789dbd60837` | Raw text read |
| `uv.lock` | `306e5239cf19486ea5ac5907eeec133f9768c223` | Raw text read |

