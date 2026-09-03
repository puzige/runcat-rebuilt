# RunCat Classic 12.8 parity ledger

The preservation target is **RunCat Classic 12.8 on macOS 15**. RunCat Neo is
used only as an Apache-2.0 implementation reference for shared concepts; its
macOS 26 deployment target and product UI are not inherited.

## Evidence hierarchy

1. Live behavior and Retina captures from the archived App Store 12.8 bundle.
2. Geometry reported by WindowServer and localized strings/resources in that
   bundle.
3. Public Apache-2.0 code from `Kyome22/menubar_runcat`, `SystemInfoKit`,
   `RunCatLocalization`, and `runcat-dev/RunCatNeo`.
4. Binary metadata and targeted disassembly where behavior remains ambiguous.

## Current parity

| Surface | State | Evidence / remaining work |
| --- | --- | --- |
| Menu-bar runner | Functional | CPU-driven speed and all archived frames; settings for invert, flip, accent, random selection, and stop are wired. |
| Dashboard | Visual baseline matched | 292 x 440 pt; 8 pt outer padding; 196 x 424 pt info card; four available 72 x 64 pt actions top-packed at 8 pt spacing with unused space below; Classic line/bar graphs and dynamic popover material. |
| System metrics | Functional | CPU, memory, storage, battery (when installed), and network are fed by the official SystemInfoKit data layer. |
| Runners list | In progress | Classic single-column popover and exact default set/name mapping implemented; final size and scroll behavior still need a live reference capture. |
| General Settings | In progress | Classic icon-and-label tab bar restored with reference-measured light colors; the 490 pt-wide window now matches the original 472/390 pt adaptive heights for General/System Info, while the dark selection background still needs screenshot calibration. |
| Runners Store | Not accepted | Original 450 x 450 pt window and archived catalog remain to be rebuilt without pretending StoreKit purchases still work. |
| Self-Made Runners | Not accepted | PNG validation, frame editor, preview, and persistence remain. |
| System Info Bar | Partial | Monitoring switches now control dashboard visibility and repository activation, including the unavailable-battery state; Classic secondary status items and confirmation flow remain. |
| More / help / about | Functional | Classic 292 x 216 pt compact in-popover More page, About, Help, legacy mail report, and Quit actions are wired; acknowledgement details remain. |

`scripts/verify.sh` is the executable acceptance gate. It rebuilds from source,
checks the signed bundle/resources, and locally keeps the live dashboard open
long enough to catch startup and monitoring crashes.

Deterministic visual entry points are `--preview-dashboard`,
`--preview-runners`, `--preview-settings`, and
`--preview-system-info-settings`, and `--preview-more`. They do not alter
production launch behavior.
