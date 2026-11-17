{ lib, runCommand, noto-fonts, tlwg, sarabun-font }:

# A small font tree with the exact filenames WineForThai's win32u font-link
# patch and its registry FontSubstitutes expect. Copied into a prefix's
# drive_c/windows/Fonts so LINE and other GDI apps find Thai glyphs.
#
# These are free fonts and stand in for the Windows Thai fonts:
#   Noto Sans Thai        -> general Thai UI text (Tahoma / Leelawadee UI fallback)
#   Noto Sans Thai Looped -> looped Thai style
#   Loma, Garuda (TLWG)   -> classic free Thai fonts
#   Sarabun               -> Thai body text, close to TH Sarabun New
runCommand "wine-for-thai-fonts" { } ''
  mkdir -p $out/share/wine-for-thai-fonts
  cp ${noto-fonts}/share/fonts/noto/NotoSansThai.ttf        $out/share/wine-for-thai-fonts/
  cp ${noto-fonts}/share/fonts/noto/NotoSansThaiLooped.ttf  $out/share/wine-for-thai-fonts/
  cp ${noto-fonts}/share/fonts/noto/NotoSerifThai.ttf       $out/share/wine-for-thai-fonts/
  cp ${tlwg}/share/fonts/opentype/thai/Loma.otf             $out/share/wine-for-thai-fonts/
  cp ${tlwg}/share/fonts/opentype/thai/Loma-Bold.otf        $out/share/wine-for-thai-fonts/
  cp ${tlwg}/share/fonts/opentype/thai/Garuda.otf           $out/share/wine-for-thai-fonts/
  cp ${tlwg}/share/fonts/opentype/thai/Garuda-Bold.otf      $out/share/wine-for-thai-fonts/
  cp ${sarabun-font}/share/fonts/truetype/Sarabun-Regular.ttf $out/share/wine-for-thai-fonts/
  cp ${sarabun-font}/share/fonts/truetype/Sarabun-Bold.ttf    $out/share/wine-for-thai-fonts/
''
