{
  description = "WineForThai: Wine (staging) with Thai font fixes, a Thai font set, and helper setups for Windows apps used in Thailand";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = rec {
        # Wine staging + the WineForThai patches in ./patches
        wine = pkgs.callPackage ./nix/wine.nix { };
        # Free Thai fonts that stand in for Windows' Tahoma / Leelawadee UI / Angsana / Cordia / Browallia / TH Sarabun
        thai-fonts = pkgs.callPackage ./nix/thai-fonts.nix { };
        # `wft` command: Thai-ready prefixes, LINE and SolidWorks helpers
        wft = pkgs.callPackage ./nix/wft.nix { inherit wine thai-fonts; };
        default = wft;
      };

      nixosModules.default = import ./nix/module.nix self;

      checks.${system} = {
        wft-shellcheck = pkgs.runCommand "wft-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
          shellcheck -x ${./scripts/wft.sh}
          touch $out
        '';
        thai-font-links = pkgs.callPackage ./tests/thai-font-links.nix { inherit (self.packages.${system}) wine thai-fonts; };
      };
    };
}
