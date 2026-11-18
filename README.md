# WineForThai

A [Wine](https://www.winehq.org/) build and setup helper tuned for Windows apps
used in Thailand — first **LINE** (desktop), and an **experimental** start on
**SOLIDWORKS** — with Thai text and fonts working out of the box.

> WineForThai is **not affiliated with or endorsed by the Wine project, LY
> Corporation (LINE) or Dassault Systèmes (SOLIDWORKS)**. It only packages Wine
> with small patches and setup scripts. Wine is the work of the Wine project and
> its contributors; see **[credit](#credit)**.

## What's inside

- **Patched Wine (staging 11.18).** Adds Thai fonts to Wine's default font-link
  lists so GDI apps render Thai (`patches/0001-…`). Everything else is stock
  Wine staging.
- **A Thai font set** (`nix/thai-fonts.nix`): free fonts (Noto Sans Thai, TLWG
  Loma/Garuda, Sarabun) named so Wine's font links and substitutes find them.
- **`wft`** — one command to create a Thai-ready prefix and install/run LINE
  with the fixes below applied automatically.
- **A NixOS module** that installs `wft`, adds the `th_TH.UTF-8` locale, and
  installs the Thai fonts system-wide.

## Install / try it

```sh
# Run the helper without installing:
nix run github:zenmastercat/WineForThai -- --help

# Install and set up LINE in a dedicated prefix:
nix run github:zenmastercat/WineForThai -- line ~/.line
nix run github:zenmastercat/WineForThai -- run  ~/.line \
    ~/.line/drive_c/users/$USER/AppData/Local/LINE/bin/LineLauncher.exe
```

`wft line` prints this exact command when it finishes. Use **LineLauncher.exe**
(not a versioned `LINE.exe` path) — LINE's self-updater moves the app into
`bin/current`, so the launcher is the one path that keeps working after updates.

Or add the NixOS module:

```nix
{
  inputs.wine-for-thai.url = "github:zenmastercat/WineForThai";
  # in your configuration:
  imports = [ inputs.wine-for-thai.nixosModules.default ];
  programs.wine-for-thai.enable = true;
}
```

## LINE: what works and the fixes applied

LINE 26.x is a Qt 6 app. It installs and runs under Wine, but needs several
fixes, which `wft` applies for you (see `docs/LINE.md` for detail and sources):

| Problem | Fix `wft` applies |
|---|---|
| LINE rejects Wine's unsigned Windows DLLs (`NO_SIGNATURE`) and won't start | Self-signs the prefix DLLs with a local certificate named "Microsoft Windows" (`wft sign`; re-run after a Wine upgrade). The key stays in the prefix. |
| Thai text shows as boxes | Thai font set + font-link patch + font substitutes |
| Crash when rendering emoji | Hides colour-emoji fonts from Wine and maps emoji to Noto Emoji (free, black-and-white) |
| Image/video viewer closes | `msvcp140_2=native,builtin` for `LineMediaPlayer.exe` |
| Dropped keys / black screenshots on Wayland | Forces the X11 driver with XIM input |
| Window vanishes when maximised | `Decorated=N` for `LINE.exe` |

**Tested here:** `wft line` installs LINE 26.6.0.4004 (verified signed by LY
Corporation), signs Wine's DLLs, and LINE **reaches its login screen** — the
email/password fields and the QR code for "Log in with my smartphone" all
render. The patched Wine builds and carries the Thai font links. **Not tested
here:** completing a login (needs you to scan the QR with your phone) and Thai
typing — reported working by others, unconfirmed on this exact setup.

## SOLIDWORKS: experimental

`wft solidworks` prepares a prefix, but SOLIDWORKS is **not** expected to work
reliably and is **untested** here. The best community result is SOLIDWORKS 2026
on Wine 11.18 on one machine, rated "barely usable". See `docs/SOLIDWORKS.md`.

## Credit

Wine is developed by the **Wine project and its contributors**
(<https://www.winehq.org/>). WineForThai builds on Wine staging and would not
exist without that work. The full contributor list is in **`AUTHORS.wine`**.

- **Wine** is licensed under the **GNU LGPL v2.1 or later** — see `LICENSE.wine`
  and `COPYING.LIB`. WineForThai's patch carries a dated change notice in its
  header, and the full source (this repo + the pinned nixpkgs Wine source) is
  available so you can rebuild it.
- The WineForThai scripts, Nix packaging and patches are under the **MIT
  license** (`LICENSE`).
- The Wine patch here is AI-assisted and is **deliberately not submitted
  upstream**, because the Wine project does not accept AI-generated patches.

"Wine" is a trademark; WineForThai uses the name only to describe what this is.
