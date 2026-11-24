# Software Compatibility List

The canonical compatibility table is maintained in [compatibility.csv](compatibility.csv), which GitHub renders as a searchable, filterable table.

## Reporting Issues on GitHub

Every tracked application has a unique lowercase kebab-case `id` in [compatibility.csv](compatibility.csv) (for example, `solidworks-2024`).

When opening an issue on GitHub:
1. Look up the `id` in [compatibility.csv](compatibility.csv).
2. Prefix the issue title with `[<software-id>]`, e.g. `[solidworks-2024] Crash when opening assembly`, or use the **Software Compatibility Issue** issue template and enter the ID in the **Software ID** field.
3. If the software is not listed yet, propose a `<software>-<major-version>` slug (for example, `appname-2025`) or submit a **Compatibility List Update / New Software Report**.

## Status Ratings

| Status | Meaning |
| --- | --- |
| `platinum` | Installs and runs out of the box with no manual tweaks or workarounds. |
| `gold` | Works well with a built-in profile and/or standard prerequisite installation. |
| `silver` | Launches and core workflows work, with minor known issues or workarounds. |
| `bronze` | Launches or shows partial functionality, with significant missing features or instability. |
| `borked` | Fails to install, fails to launch, or immediately crashes before usable. |
| `untested` | Entry tracked, not yet verified on current builds. |

## CSV Columns & Conventions

- `id`: Unique lowercase kebab-case identifier (`<software>-<major-version>`), aligned 1:1 with `SoftwareProfile.id` in `SoftwareProfileManager.swift` when a built-in profile exists.
- `name`: Display name of the application.
- `vendor`: Publisher / vendor name.
- `version`: Tested version, service pack, or build.
- `category`: Broad category (e.g. `CAD`, `CAM`, `CAE`, `EDA`, `3D`).
- `arch`: Windows architecture (`x86_64`, `x86`, `arm64ec`).
- `graphics_api`: Primary graphics API used (e.g. `OpenGL 4.6`, `Direct3D 11`, `Vulkan`).
- `status`: One of `platinum`, `gold`, `silver`, `bronze`, `borked`, `untested`.
- `profile_id`: Matching `SoftwareProfile.id` if a built-in ZinkKrisp profile exists (blank if none).
- `prerequisites`: `;`-separated prerequisite IDs (e.g. `dotnet48;mscoree_shim;vcredist_2022_x64;vcredist_2022_x86`).
- `tested_hardware`: Apple Silicon chip tested (e.g. `Apple M4`).
- `tested_macos`: macOS version tested (e.g. `macOS 27.2.1`).
- `last_tested`: ISO-8601 date (`YYYY-MM-DD`).
- `known_issues`: Short summary of known issues or limitations.
- `notes`: Additional runtime or configuration notes.

### Editing Rules

- **Multi-value cells** use `;` as the delimiter instead of `,` (avoid nested commas where practical, and use standard RFC-4180 double-quoting if a prose cell contains commas).
- **Keep each row single-line** (no embedded newlines inside cells) so `git diff` stays clean.
- **Adding fields later**: Append new columns to the end of the header row so existing column-header parsers remain backward-compatible.

## Trademark & Licensing Disclaimer

ZinkKrisp is an independent open-source project and is not affiliated with, sponsored by, or endorsed by Dassault Systèmes, Microsoft Corporation, Apple Inc., or any other listed software vendor. All product names, trademarks, and registered trademarks are the property of their respective owners. Users must supply their own valid licenses and official installers for any third-party software they choose to run.

