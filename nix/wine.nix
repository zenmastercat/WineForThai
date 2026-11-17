{ lib, wineWow64Packages }:

# Wine staging (WoW64 build: one 64-bit Wine that also runs 32-bit programs)
# with the WineForThai patches applied on top of the staging patch set.
(wineWow64Packages.staging.overrideAttrs (old: {
  pname = "wine-for-thai";
  patches = (old.patches or [ ]) ++ [
    ../patches/0001-win32u-Link-Thai-fonts-to-Tahoma-and-UI-fonts.patch
  ];
  meta = (old.meta or { }) // {
    description = "Wine staging with Thai font fixes (WineForThai)";
    longDescription = ''
      Wine is developed by the Wine project and its contributors
      (https://www.winehq.org, see AUTHORS.wine in WineForThai).
      WineForThai only adds small patches; it is not affiliated with
      or endorsed by the Wine project.
    '';
    license = lib.licenses.lgpl21Plus;
  };
}))
