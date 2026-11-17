{ lib, stdenvNoCC, makeWrapper, writeShellScriptBin, bash, coreutils, curl
, osslsigncode, openssl, findutils, gnused, wine, thai-fonts
, noto-fonts-monochrome-emoji }:

# The `wft` command: wraps scripts/wft.sh with Wine, osslsigncode, the Thai
# font set and a free black-and-white emoji font wired in.
let
  runtimeInputs = [ bash coreutils curl osslsigncode openssl findutils gnused wine ];
in
stdenvNoCC.mkDerivation {
  pname = "wine-for-thai";
  version = "0.1.0";
  src = ../scripts;
  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 wft.sh $out/libexec/wft.sh
    makeWrapper ${bash}/bin/bash $out/bin/wft \
      --add-flags $out/libexec/wft.sh \
      --prefix PATH : ${lib.makeBinPath runtimeInputs} \
      --set WFT_WINE          ${wine}/bin/wine \
      --set WFT_WINESERVER    ${wine}/bin/wineserver \
      --set WFT_WINEBOOT      ${wine}/bin/wineboot \
      --set WFT_OSSLSIGNCODE  ${osslsigncode}/bin/osslsigncode \
      --set WFT_FONTS_DIR     ${thai-fonts}/share/wine-for-thai-fonts \
      --set WFT_EMOJI_DIR     ${noto-fonts-monochrome-emoji}/share/fonts/noto
    runHook postInstall
  '';
  meta = {
    description = "Set up Wine prefixes tuned for LINE and SOLIDWORKS with Thai support";
    license = lib.licenses.mit; # the wft scripts; Wine itself is LGPL-2.1+
    mainProgram = "wft";
    platforms = lib.platforms.linux;
  };
}
