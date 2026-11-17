#!/usr/bin/env bash
# WineForThai (wft): set up Wine prefixes tuned for apps used in Thailand.
#
# Subcommands:
#   wft prefix  <dir>            Create/repair a Thai-ready prefix (fonts + registry).
#   wft line    <dir>            Install and configure LINE (desktop) in <dir>.
#   wft sign    <dir>            (Re)sign the prefix DLLs so LINE accepts them.
#                               Run this again after every Wine upgrade.
#   wft run     <dir> <exe> ...  Run a Windows program with the LINE-friendly
#                               environment (X11+XIM, Qt vars cleared, B/W emoji).
#   wft solidworks <dir> <installer>   Prepare a SOLIDWORKS prefix (EXPERIMENTAL,
#                               untested; see docs/SOLIDWORKS.md).
#
# Tools (wine, osslsigncode, fonts, ...) are injected by the Nix wrapper via
# the WFT_* environment variables; the raw script expects them on PATH.
set -euo pipefail

: "${WFT_WINE:=wine}"
: "${WFT_WINESERVER:=wineserver}"
: "${WFT_WINEBOOT:=wineboot}"
: "${WFT_OSSLSIGNCODE:=osslsigncode}"
: "${WFT_FONTS_DIR:=}"            # dir holding NotoSansThai.ttf, Loma.otf, ...
: "${WFT_EMOJI_DIR:=}"          # dir holding a monochrome emoji font (NotoEmoji.ttf), optional
: "${WFT_LINE_URL:=https://desktop.line-scdn.net/win/bin/real/installer/LineInst.exe}"

msg()  { printf '\033[1;34m[wft]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[wft] warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[wft] error:\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

# Absolute prefix path; Wine refuses a relative WINEPREFIX.
prefix_path() {
    local d="$1"
    mkdir -p "$d"
    (cd "$d" && pwd)
}

wine_in() { WINEPREFIX="$1" WINEDEBUG="${WINEDEBUG:-err+all,fixme-all}" "$WFT_WINE" "${@:2}"; }

boot_prefix() {
    local pfx="$1"
    msg "initialising prefix at $pfx"
    WINEPREFIX="$pfx" WINEDLLOVERRIDES="mscoree=d;mshtml=d" "$WFT_WINEBOOT" -u >/dev/null 2>&1 || true
    WINEPREFIX="$pfx" "$WFT_WINESERVER" -w
}

install_fonts() {
    local pfx="$1"
    [ -n "$WFT_FONTS_DIR" ] && [ -d "$WFT_FONTS_DIR" ] || { warn "no Thai font dir; skipping fonts"; return; }
    local dest="$pfx/drive_c/windows/Fonts"
    mkdir -p "$dest"
    msg "installing Thai fonts"
    cp -f "$WFT_FONTS_DIR"/*.ttf "$WFT_FONTS_DIR"/*.otf "$dest"/ 2>/dev/null || true
    if [ -n "$WFT_EMOJI_DIR" ] && [ -d "$WFT_EMOJI_DIR" ]; then
        cp -f "$WFT_EMOJI_DIR"/*.ttf "$dest"/ 2>/dev/null || true
    fi
}

# Registry: Thai font substitutes, black-and-white emoji, and the LINE fixes.
apply_registry() {
    local pfx="$1" reg
    reg="$(mktemp --suffix=.reg)"
    cat > "$reg" <<'REG'
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements]
"Leelawadee UI"="Noto Sans Thai"
"Leelawadee"="Noto Sans Thai"
"LilyUPC"="Noto Sans Thai"
"Angsana New"="Sarabun"
"AngsanaUPC"="Sarabun"
"Cordia New"="Noto Sans Thai"
"CordiaUPC"="Noto Sans Thai"
"Browallia New"="Noto Sans Thai"
"BrowalliaUPC"="Noto Sans Thai"
"TH Sarabun New"="Sarabun"
"Segoe UI Emoji"="Noto Emoji"
"Segoe UI Symbol"="Noto Emoji"

[HKEY_CURRENT_USER\Software\Wine\Drivers]
"Graphics"="x11"

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"InputStyle"="root"

[HKEY_CURRENT_USER\Software\Wine\AppDefaults\LINE.exe\X11 Driver]
"Decorated"="N"

[HKEY_CURRENT_USER\Software\Wine\AppDefaults\LineMediaPlayer.exe\DllOverrides]
"msvcp140_2"="native,builtin"
REG
    msg "applying registry fixes (Thai fonts, B/W emoji, X11, media player)"
    wine_in "$pfx" regedit /S "$reg"
    WINEPREFIX="$pfx" "$WFT_WINESERVER" -w
    rm -f "$reg"
}

# Self-sign the prefix's Windows DLLs with a certificate named "Microsoft
# Windows", so LINE's Authenticode check (which rejects Wine's unsigned DLLs
# with NO_SIGNATURE) passes. The key never leaves this prefix.
# Set of DLL basenames that Wine itself ships. We only sign these, so a DLL an
# installer dropped into the prefix (a third party's own file) never receives
# our "Microsoft Windows" signature.
wine_builtin_dlls() {
    local winedir; winedir="$(dirname "$(command -v "$WFT_WINE")")/.."
    find "$winedir/lib" -name '*.dll' -printf '%f\n' 2>/dev/null \
        | tr '[:upper:]' '[:lower:]' | sort -u
}

sign_dlls() {
    local pfx="$1"
    need "$WFT_OSSLSIGNCODE"
    local cdir="$pfx/.wft"
    ( umask 077; mkdir -p "$cdir" )
    local key="$cdir/ms.key" crt="$cdir/ms.crt"
    if [ ! -f "$crt" ]; then
        # LINE accepts only DLLs signed under a Microsoft signer name, so the
        # certificate must carry one. This self-signed cert never leaves this
        # prefix and is not trusted by anything outside it; see docs/LINE.md.
        msg "generating a local, prefix-only code-signing certificate"
        ( umask 077
          openssl req -x509 -newkey rsa:2048 -keyout "$key" -out "$crt" \
            -days 3650 -nodes -sha256 \
            -subj "/C=US/ST=Washington/L=Redmond/O=Microsoft Corporation/CN=Microsoft Windows" \
            >/dev/null 2>&1 )
        chmod 600 "$key"
    fi
    local allow; allow="$(wine_builtin_dlls)"
    local n=0 ok=0 skipped=0
    msg "signing Wine's builtin DLLs (one-time, ~30s); re-run 'wft sign' after a Wine upgrade"
    while IFS= read -r -d '' dll; do
        local base; base="$(basename "$dll" | tr '[:upper:]' '[:lower:]')"
        # Only sign DLLs that Wine itself ships; leave third-party files alone.
        if ! printf '%s\n' "$allow" | grep -qxF "$base"; then skipped=$((skipped + 1)); continue; fi
        n=$((n + 1))
        # Skip anything we already signed (our cert's CN appears in the output).
        # Capture first: osslsigncode exits non-zero (no trust chain) under pipefail.
        local vout; vout="$("$WFT_OSSLSIGNCODE" verify -ignore-timestamp "$dll" 2>/dev/null || true)"
        if printf '%s\n' "$vout" | grep -q "CN=Microsoft Windows"; then ok=$((ok + 1)); continue; fi
        local tmp="$dll.wftsig"
        if "$WFT_OSSLSIGNCODE" sign -certs "$crt" -key "$key" -h sha256 \
                -n "Microsoft Windows" -in "$dll" -out "$tmp" >/dev/null 2>&1; then
            mv -f "$tmp" "$dll"; ok=$((ok + 1))
        else
            rm -f "$tmp"
        fi
    done < <(find "$pfx/drive_c/windows/system32" "$pfx/drive_c/windows/syswow64" \
                -maxdepth 1 -type f -iname '*.dll' -print0 2>/dev/null)
    msg "signed/verified $ok of $n Wine DLLs (left $skipped non-Wine DLLs untouched)"
    [ "$ok" -gt 0 ] || die "signing failed for every DLL; is osslsigncode working?"
}

cmd_prefix() {
    local pfx; pfx="$(prefix_path "$1")"
    boot_prefix "$pfx"
    install_fonts "$pfx"
    apply_registry "$pfx"
    msg "Thai-ready prefix ready at $pfx"
}

cmd_sign() { local pfx; pfx="$(prefix_path "$1")"; sign_dlls "$pfx"; }

# Confirm a downloaded installer is signed by LINE's publisher before running
# it. Avoids running a tampered or man-in-the-middled binary.
: "${WFT_LINE_SIGNER:=LY Corporation}"
verify_line_installer() {
    local inst="$1" out
    # osslsigncode exits non-zero because this self-contained check has no CA to
    # build a trust chain; we only need the embedded signer name, so capture the
    # output (|| true keeps pipefail happy) and look for the publisher there.
    out="$("$WFT_OSSLSIGNCODE" verify -ignore-timestamp "$inst" 2>/dev/null || true)"
    if ! printf '%s\n' "$out" | grep -q "O=$WFT_LINE_SIGNER"; then
        die "installer signature check failed (expected signer '$WFT_LINE_SIGNER'); refusing to run $inst"
    fi
    msg "installer verified: signed by $WFT_LINE_SIGNER"
}

cmd_line() {
    local pfx; pfx="$(prefix_path "$1")"
    need curl
    need "$WFT_OSSLSIGNCODE"
    cmd_prefix "$pfx" >/dev/null
    local inst="$pfx/.wft/LineInst.exe"
    if [ ! -s "$inst" ]; then
        msg "downloading the official LINE installer"
        curl -fsSL --proto '=https' --tlsv1.2 "$WFT_LINE_URL" -o "$inst"
    fi
    # Verify every time, including a cached or pre-placed file.
    verify_line_installer "$inst"
    msg "running the LINE installer (silent)"
    wft_env "$pfx" "$WFT_WINE" "$inst" /S || warn "installer returned non-zero; continuing"
    WINEPREFIX="$pfx" "$WFT_WINESERVER" -w
    sign_dlls "$pfx"
    local exe
    exe="$(find "$pfx/drive_c" -name LINE.exe 2>/dev/null | sort | tail -1 || true)"
    [ -n "$exe" ] || { warn "LINE.exe not found; install may have failed"; return; }
    msg "LINE installed: $exe"
    msg "start it with:  wft run \"$pfx\" \"$exe\""
}

# The environment LINE needs: X11 (not Wayland), XIM input, no inherited Qt
# platform/style variables, and fontconfig with color emoji fonts hidden
# (works around the color-emoji crash).
wft_env() {
    local pfx="$1"; shift
    local fcfile="$pfx/.wft/fonts.conf"
    if [ ! -f "$fcfile" ]; then
        mkdir -p "$pfx/.wft"
        cat > "$fcfile" <<FC
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <!-- Hide colour (bitmap/COLR) emoji fonts: they crash LINE's Qt text engine. -->
  <selectfont><rejectfont><pattern>
    <patelt name="color"><bool>true</bool></patelt>
  </pattern></rejectfont></selectfont>
</fontconfig>
FC
    fi
    env -u WAYLAND_DISPLAY \
        -u QT_QPA_PLATFORM -u QT_QPA_PLATFORMTHEME -u QT_STYLE_OVERRIDE \
        -u QT_SCALE_FACTOR -u QT_SCREEN_SCALE_FACTORS -u QT_AUTO_SCREEN_SCALE_FACTOR \
        -u QT_PLUGIN_PATH -u QML2_IMPORT_PATH \
        WINEPREFIX="$pfx" \
        WINEDEBUG="${WINEDEBUG:-err+all,fixme-all}" \
        FONTCONFIG_FILE="$fcfile" \
        XMODIFIERS="${XMODIFIERS:-@im=none}" \
        LANG="${LANG:-th_TH.UTF-8}" \
        "$@"
}

cmd_run() {
    local pfx; pfx="$(prefix_path "$1")"; shift
    [ "$#" -ge 1 ] || die "usage: wft run <dir> <program.exe> [args...]"
    wft_env "$pfx" "$WFT_WINE" "$@"
}

cmd_solidworks() {
    local pfx; pfx="$(prefix_path "$1")"; shift
    local installer="${1:-}"
    warn "SOLIDWORKS support is EXPERIMENTAL and untested. See docs/SOLIDWORKS.md."
    cmd_prefix "$pfx" >/dev/null
    msg "enabling runtimes SOLIDWORKS needs (.NET, VC++, MSXML) via registry overrides"
    local reg; reg="$(mktemp --suffix=.reg)"
    cat > "$reg" <<'REG'
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"renderer"="vulkan"

[HKEY_CURRENT_USER\Software\Wine\AppDefaults\sldworks.exe\X11 Driver]
"Decorated"="N"
REG
    wine_in "$pfx" regedit /S "$reg"; rm -f "$reg"
    WINEPREFIX="$pfx" "$WFT_WINESERVER" -w
    if [ -n "$installer" ] && [ -f "$installer" ]; then
        msg "launching the SOLIDWORKS installer (expect manual steps)"
        wft_env "$pfx" "$WFT_WINE" "$installer" || warn "installer returned non-zero"
    else
        warn "no installer given; prefix prepared but SOLIDWORKS not installed"
    fi
    msg "SOLIDWORKS prefix prepared (untested) at $pfx"
}

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

main() {
    [ "$#" -ge 1 ] || usage 1
    local sub="$1"; shift
    case "$sub" in
        prefix)     [ "$#" -ge 1 ] || usage 1; cmd_prefix "$1" ;;
        line)       [ "$#" -ge 1 ] || usage 1; cmd_line "$1" ;;
        sign)       [ "$#" -ge 1 ] || usage 1; cmd_sign "$1" ;;
        run)        cmd_run "$@" ;;
        solidworks) [ "$#" -ge 1 ] || usage 1; cmd_solidworks "$@" ;;
        -h|--help|help) usage 0 ;;
        *) die "unknown subcommand: $sub (try 'wft --help')" ;;
    esac
}

main "$@"
