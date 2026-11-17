# LINE on WineForThai — detail and sources

LINE for Windows (desktop) is a **Qt 6** application. `LineMediaPlayer.exe`
shows images and video in a separate process. This page explains each fix `wft`
applies. Findings are from WineHQ AppDB, bugs.winehq.org and community reports
(collected 2026-11-18), plus local testing on this machine.

## The signature check (the big blocker)

LINE 26.x verifies the Authenticode signature of the Windows system DLLs it
loads and refuses any that are unsigned, showing:

```
Security verification failed.
File : C:\windows\system32\CRYPT32.dll
Reason : NO_SIGNATURE
```

Wine's built-in DLLs are unsigned, so LINE stops at startup. This was confirmed
here by running LINE 26.6.0.4004 under Wine (the dialog appeared for
`crypt32.dll`). The matching Wine bug (54836, wintrust) is still open.

**Fix (`wft sign`):** generate a self-signed certificate whose subject is
`CN=Microsoft Windows, O=Microsoft Corporation` and sign every DLL in the
prefix's `system32` and `syswow64` with `osslsigncode`. LINE's check then
passes. The private key is generated locally and never leaves the prefix
(`<prefix>/.wft/ms.key`). **Re-run `wft sign` after every Wine upgrade**, because
`wineboot` restores the unsigned built-in DLLs.

Three approaches were reported working; `wft` uses self-signing because it needs
no Microsoft binaries and no pinned old build:

1. **Self-sign** the prefix DLLs (used here).
2. Keep Microsoft's own DLLs on disk and force Wine's builtin code via
   `WINEDLLOVERRIDES` — needs files from Microsoft's symbol server.
3. Pin the **legacy LINE 8.7.0** installer, which has no check — but you lose
   updates and features.

## The other fixes

| Area | Why | What `wft` sets |
|---|---|---|
| **Thai text** | Wine's Tahoma has no Thai glyphs and its default font links list no Thai font | The Thai font set is copied into the prefix; the win32u patch links Thai fonts to Tahoma / Microsoft Sans Serif / Lucida Sans Unicode; registry substitutes map Leelawadee UI, Angsana, Cordia, Browallia, TH Sarabun New to the free fonts |
| **Emoji crash** | LINE's Qt text engine reads unmapped memory when a colour-emoji font is installed (bug 53795) | A prefix `FONTCONFIG_FILE` rejects `color=true` fonts; `Segoe UI Emoji`/`Segoe UI Symbol` map to Noto Emoji (free), giving black-and-white emoji |
| **Media viewer** | `LineMediaPlayer.exe` exits on an unimplemented `msvcp140_2` export (bug 56999) | `msvcp140_2=native,builtin` under that program's AppDefaults |
| **Input / screenshots** | On Wayland, dev Wine drops Enter/Backspace with text-input-v3 (which Mango offers), and LINE's own screenshot is black (bug 60684) | Forces `Graphics=x11` and XIM input style; `wft run` clears inherited `QT_*` variables and unsets `WAYLAND_DISPLAY` |
| **Window disappears on maximise** | Wine remaps the window when decorations change | `Decorated=N` for `LINE.exe` |

## Locale

Wine's Thai locale wants `th_TH.UTF-8`, which was **not** present on this
machine. The NixOS module adds it (`programs.wine-for-thai.addThaiLocale`).
Without it, text still renders; some date/number formatting may differ.

## What was and wasn't tested here

- **Tested:** both installers run and are signed by LY Corporation; LINE 26.6
  and legacy 9.1.3 install; the patched Wine builds and carries the Thai links;
  the signature dialog reproduces without signing.
- **Not tested:** a full login (needs scanning a QR code with a phone), Thai
  **typing**, and voice/video calls (camera/microphone may hang, per reports).
