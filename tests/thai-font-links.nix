{ runCommand, binutils, wine, thai-fonts }:

# Verify the Thai font-link patch is actually compiled into win32u, and that
# the font set carries the filenames those links reference. This is a cheap
# build-time check; a full "does LINE show Thai" test needs a GUI and a login.
runCommand "wft-thai-font-links" { nativeBuildInputs = [ binutils ]; } ''
  set -e
  so=$(find ${wine} -name win32u.so | head -1)
  echo "checking $so"
  for s in "NotoSansThai.ttf,Noto Sans Thai" "Loma.otf,Loma" "Garuda.otf,Garuda" "LEELAWUI.TTF,Leelawadee UI"; do
    if ! strings "$so" | grep -qF "$s"; then
      echo "MISSING font link: $s"; exit 1
    fi
  done
  for f in NotoSansThai.ttf Loma.otf Garuda.otf Sarabun-Regular.ttf; do
    test -f ${thai-fonts}/share/wine-for-thai-fonts/$f || { echo "MISSING font file: $f"; exit 1; }
  done
  echo OK > $out
''
