# Reference Cases

This document records external technical provenance and the independently authored regression cases under `test/reference/`.

## Source boundary

| Repository | Revision | Use |
|---|---|---|
| `parksnoopy-undergraduate/week-parity` | `9b2f2e1916e98731d3bb556a68e55ac12f52e8a8` | Semester-week, parity, TOML, and timezone behavior |
| `ParkSnoopy/pku-elective-prettify` | `eaacca788e246a18c36ea013ced2bed6b62bd995` | Workbook field parsing, timetable structure, palette source, XLSX output, and CLI behavior |
| `ParkSnoopy/pku-elective-prettify` `pages` tree | `1fb0610248b8c3975fc82f8aa5248f90f4156d3e` | Render geometry, export scale, and multi-room tutorial recovery interaction |

Source trees were inspected through authenticated GitHub API reads without cloning or executing upstream programs. The development process made no request to `elective.pku.edu.cn`.

The inspected Week Parity tree includes GPL license text; elective-prettify includes AGPL license text. Project tests use invented values and call native Dart domain/parser APIs. They contain no copied implementation, upstream test body, upstream fixture, or ignored local workbook data.

## Week Parity coverage

`test/reference/week_reference_test.dart` maps these cases:

| Case | Contract |
|---|---|
| W01–W04 | Start-day and elapsed-day week numbering with odd/even parity |
| W05 | Dates before every configured start have no applicable semester |
| W06 | Latest applicable start wins over earlier and future starts |
| W07 | Valid base-date list and supported timezone reach the domain calendar |
| W08–W09 | Missing date or timezone fields fail parsing |
| W10 | Empty, malformed, duplicate, or unordered date lists fail parsing |
| W11 | Supported comments and trailing commas parse |
| W12 | Beijing midnight, not UTC midnight, changes the calendar day |
| W13–W14 | Configured week bound and next start terminate applicability |
| W15 | Build-configured week bounds are validated |

W01–W09 correspond to the upstream Rust test semantics. W10–W15 are project-owned strengthening around validation, Beijing dates, and bounded semester applicability. The application intentionally omits upstream arbitrary date-selection UI and unbounded week behavior.

## Elective timetable coverage

`test/reference/elective_reference_test.dart` maps these cases:

| Case | Contract |
|---|---|
| E01 | Recognized frequency plus title, room, remark, and exam fields |
| E02–E04 | Fullwidth delimiters, title qualifiers, human spacing, and raw-text retention |
| E05–E09 | Empty/missing remarks, malformed records, trailing fields, and unknown-frequency fallback |
| E10–E11 | Tutorial extraction remains explicit and cannot replace the main occurrence frequency |
| E12–E16 | Header/index structure, blank rows, weekday scope, all periods, and Chinese period labels |
| E17–E20 | Stable source identities, presentation-only grouping, parity coexistence, and header-driven weekday coordinates |
| E21–E22 | Paired detail rows and unsupported populated columns preserve data or fail closed |
| E23–E24 | Immutable candidate-byte snapshots and non-BIFF rejection |
| E25 | Tutorial inference preserves original records and either expands safely or remains reviewable |
| E26 | Full projection retains every occurrence while parity projection filters membership |

### Deliberate divergences

- Source identity is sheet/row/column based; upstream title equality is not used as durable identity.
- Immutable source class name governs grouping and generated color identity. Room, note, frequency, exam, and edited display name do not redefine it.
- Unknown frequency maps to `每周` rather than retaining an unsupported state.
- Tutorial inference never makes an arbitrary room choice, overwrites an occupied destination, or silently drops an out-of-range/weekend destination.
- Saturday and Sunday are outside the product timetable.
- Course color selection is deterministic application-owned presentation state rather than the upstream random adjacency algorithm.
- Source text preserves human-readable spacing instead of removing every ASCII space.

## Render and export contract

The `pages` reference supplies the observable geometry protected by `test/timetable_reference_style_test.dart` and export/widget coverage:

- 120-unit period-index width;
- 44-unit weekday header;
- 100-unit period rows;
- 30-unit meal breaks after periods 4 and 9;
- reference class-period times and font roles;
- 1.15 fitted table aspect;
- 12-unit export padding; and
- 4× PNG output scale.

The application owns color policy and uses one shared geometry/content-role authority across Flutter, PNG, and XLSX. Class names are bold while room and remark roles retain configured timetable weight.

The pinned palette revision supplies named five-color palettes. The malformed upstream `##ffafcc` value is rejected rather than repaired; `CONTEXT.md` owns the resulting palette invariant.

## Evidence limits

- These tests do not execute upstream code.
- Synthetic matrices prove isolated parser behavior, not compatibility with a real BIFF8 export.
- Positive real-workbook decoding remains an explicit ignored/local-fixture gate.
- Parser success does not establish Flutter rendering, native picker behavior, persistence, packaging, or visual parity; those have separate tests and runtime gates in `PLAN.md`.
- Revision changes require re-inspection and an explicit update to this provenance map before reference-derived behavior changes.