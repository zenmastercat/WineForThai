# SOLIDWORKS on WineForThai — experimental and untested

**Status: experimental. Not tested on this machine. Do not expect it to work.**

SOLIDWORKS is a large, DRM-protected CAD suite. Running it under Wine is, at
best, partial. This page records what is known (collected 2026-11-18) so you can
try, but WineForThai makes no promise that SOLIDWORKS runs.

## Best known result

- **SOLIDWORKS 2026 SP4.1** on **Wine 11.18** on one NixOS / AMD machine, using
  five Wine patches and hand-edited MSI installer tables. The author rates it
  **"barely usable"** (github `Gandhuttt/solidworks-nix`).
- WineHQ AppDB rates SOLIDWORKS 2020–2023 **"Garbage"**, with one 2024 **Silver**.

## Known blockers

- PropertyManager **buttons ignore mouse clicks** (bug 59478); pressing **Enter**
  often works instead.
- On **NVIDIA** (this machine), sketch geometry **ghosts/smears** (bug 59909);
  the proposed Wine patches are unmerged. An untested idea is `UseEGL=N`.
- No community reports found for **SolidNetWork license manager**, **Toolbox/PDM**
  (needs SQL Server Express), or **3DEXPERIENCE** login — treat these as unknown.

## What `wft solidworks` does

```sh
wft solidworks ~/.solidworks /path/to/SOLIDWORKS_installer.exe
```

It creates a Thai-ready prefix, sets the Direct3D renderer to Vulkan and
`Decorated=N` for `sldworks.exe`, then launches the installer if you pass one.
You will still need to supply the installer and a licence, install the required
runtimes (.NET 4.8, Visual C++ runtimes, MSXML), and work through installer
steps by hand. Expect failures.

This is provided as a starting point, not a working configuration.
