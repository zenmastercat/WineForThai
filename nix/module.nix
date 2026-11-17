self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.wine-for-thai;
  system = pkgs.stdenv.hostPlatform.system;
  pkgs' = self.packages.${system};
in
{
  options.programs.wine-for-thai = {
    enable = lib.mkEnableOption "WineForThai: Wine with Thai support plus the wft helper";
    addThaiLocale = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add th_TH.UTF-8 to the system locales (Wine's Thai locale needs it).";
    };
    installFontsSystemwide = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the free Thai fonts system-wide as well as into prefixes.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs'.wft pkgs'.wine ];

    i18n.supportedLocales = lib.mkIf cfg.addThaiLocale
      (lib.mkAfter [ "th_TH.UTF-8/UTF-8" ]);

    fonts.packages = lib.mkIf cfg.installFontsSystemwide
      [ pkgs.noto-fonts pkgs.tlwg pkgs.sarabun-font pkgs.noto-fonts-monochrome-emoji ];
  };
}
