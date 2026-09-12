# PKU Manager

PKU Manager is an offline-first Flutter application for PKU timetable and personal-schedule data. It targets Android, iOS, Linux AppImage, macOS, and Windows NSIS; Web is intentionally unsupported.

## Development scope

- Dart owns domain policy, import parsing, persistence coordination, presentation, and export generation.
- SQLite stores immutable imported workbook bytes and normalized application state.
- Native runners remain thin Flutter hosts. Platform plugins provide document selection, application-support paths, URL launch, desktop window control, and tray integration.
- Runtime network access is limited to validated public Week Parity configuration from `https://parksnoopy-undergraduate.github.io/week/config.toml`.
- Source and tooling must never request, scrape, probe, authenticate to, or embed `elective.pku.edu.cn`.

See `CONTEXT.md` for terminology and invariants, `ARCHITECTURE.md` for ownership and data flow, `PLAN.md` for development sequencing and release gates, and `docs/REFERENCE_CASES.md` for independently authored reference coverage.

## Repository structure

| Path | Responsibility |
|---|---|
| `lib/app/` | Composition root, application shell, and shared dependency lifetime |
| `lib/domain/` | Infrastructure-independent timetable, semester, schedule, and import contracts |
| `lib/data/` | SQLite, workbook, HTTP configuration, file-selection, and platform-path adapters |
| `lib/features/` | Timetable, Calendar, Settings, import review, editing, and export presentation |
| `lib/ui/` | Shared desktop and rendering adapters |
| `test/` | Domain, adapter, persistence, controller, reference, and widget coverage |
| `android/`, `ios/`, `linux/`, `macos/`, `windows/` | Flutter platform runners and metadata |
| `packaging/linux/` | AppImage assembly and executable-relative library packaging |
| `packaging/windows/` | NSIS installer definition |
| `.github/workflows/native.yml` | Cross-platform build, package, runtime-smoke, and release workflow |

## Toolchain

The Flutter version is authoritative in `.github/workflows/native.yml`. The Dart SDK constraint and package versions are authoritative in `pubspec.yaml` and `pubspec.lock`.

```sh
flutter pub get
```

The two Noto CJK Static Super OTC files and their exact upstream license are tracked under `assets/fonts/`. Do not replace them with regional or per-weight extracts.

Linux builds require CMake, Ninja, Clang, GTK 3 development files, `pkg-config`, and Ayatana AppIndicator development files. Platform packaging dependencies and commands are defined in `.github/workflows/native.yml`.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Available release builds are produced with:

```sh
flutter build apk --release
flutter build linux --release
flutter build macos --release
flutter build ios --release --no-codesign
flutter build windows --release
```

Run Apple commands on macOS and the Windows command on Windows. A raw Flutter build does not establish distribution support: AppImage, application-bundle, simulator/device, and installed-NSIS checks remain separate release evidence. Use the source-controlled workflow and packaging definitions rather than ad hoc artifact assembly.

## Release credentials and update continuity

Android accepts an APK update only when the application ID is unchanged, the new version code is greater, and the signing certificate is compatible. The workflow derives Android's internal version code from the regular `major.minor.patch` package version as `major × 1,000,000 + minor × 1,000 + patch`; `pubspec.yaml` therefore remains a three-component version without build metadata. Minor and patch components must each remain below 1,000.

Generate the long-lived Android release key once on a trusted machine. The command prompts for the keystore password, certificate identity, and key password, so none enters shell history:

```sh
keytool -genkeypair -keystore pku-manager-release.jks -storetype JKS -alias pku-manager -keyalg RSA -keysize 4096 -validity 10000
openssl base64 -A -in pku-manager-release.jks -out /tmp/pku-manager-release.jks.base64
gh secret set ANDROID_KEYSTORE_BASE64 < /tmp/pku-manager-release.jks.base64
rm /tmp/pku-manager-release.jks.base64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD
```

Enter `pku-manager` for `ANDROID_KEY_ALIAS` when using the command above. Store the original JKS and its passwords in an independent offline backup or password manager; GitHub secrets cannot be recovered and are not a backup. Never commit the JKS, its Base64 representation, or `android/key.properties`.

The same secrets can be created in GitHub under repository **Settings → Secrets and variables → Actions → New repository secret**. The Android workflow fails before building when any signing input is absent or invalid, and verifies the resulting APK identity, version code, and APK signature before upload.

`RELEASE_TOKEN` is also required because this is a private repository and a release target may modify workflow files. Use either a classic personal access token with `repo` and `workflow` scopes or a fine-grained token restricted to this repository with Contents and Workflows read/write access. The token owner must have repository write access. Add the token as the `RELEASE_TOKEN` Actions secret; do not place it in source or workflow literals.

The published `v0.0.13` APK has version code `1` and was signed by an ephemeral CI debug certificate. Its private key is unavailable, so no differently signed APK can cryptographically update that installation. Existing `v0.0.13` Android installations require one uninstall before installing the first stable-key release. Releases signed with the new retained key can update one another normally.

NSIS updates do not require a credential. Installer continuity comes from the stable per-user install directory and uninstall registry key. The installer reuses a previously selected directory, removes the prior application bundle, writes the complete new bundle, and updates registered version metadata while leaving application-support data outside the install directory intact. Authenticode signing may improve Windows trust prompts but is separate from in-place update behavior.

Parser acceptance requires a sanitized real PKU BIFF8 workbook in addition to synthetic matrices. Keep local workbook samples ignored; never commit personal timetable data.

## App-data transfer contract

`lib/data/app_data_transfer.dart` exports all persisted application state as a consistent SQLite backup with the `.pkudata` extension. Import is bounded, validates database version, canonical schema definitions, SQLite integrity, foreign keys, and application-level decoding before acceptance, and keeps a rollback snapshot until the live data reloads. Android imports stream through a bounded app-cache file from a narrow `ACTION_GET_CONTENT` bridge with MIME `*/*`; other platforms use the existing native file interfaces.

Schema version `1` is the compatibility authority for the `0.1.x` release line. Valid schema-zero databases migrate automatically. Do not make breaking schema changes or advance `PRAGMA user_version` until the user manually authorizes the next minor release.

## External technical references

- Week Parity source: `https://github.com/parksnoopy-undergraduate/week-parity`
- Timetable behavior reference: `https://github.com/ParkSnoopy/pku-elective-prettify`

Reference code and fixtures are not copied without an approved compatible license. Pin exact revisions and record independently reimplemented behavior in `docs/REFERENCE_CASES.md`.

## License

Copyright (C) 2026 ParkSnoopy. PKU Manager is licensed under the GNU General Public License version 2 only (`GPL-2.0-only`). See `LICENSE`.