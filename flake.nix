{
  description = "Open-source Amlogic GXL/G12A boot image signing tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in {
          gxlimg = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.gxlimg;
        }
      );

      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          gxlimg = self.packages.${system}.gxlimg;
          boardTest = path: import path { inherit pkgs gxlimg; };
        in {
          # G12A family (V3 signing, two-step BL30, DDR firmware)
          compare-g12a-odroid-c4   = boardTest ./tests/boards/g12a-odroid-c4.nix;
          compare-g12a-vim3l       = boardTest ./tests/boards/g12a-vim3l.nix;
          compare-g12a-bananapi-m5 = boardTest ./tests/boards/g12a-bananapi-m5.nix;

          # G12B family (V3 signing, same flow as G12A)
          compare-g12b-odroid-n2   = boardTest ./tests/boards/g12b-odroid-n2.nix;
          compare-g12b-radxa-zero2 = boardTest ./tests/boards/g12b-radxa-zero2.nix;
          compare-g12b-khadas-vim3 = boardTest ./tests/boards/g12b-khadas-vim3.nix;

          # AXG family (V3 signing, single-step BL30, no DDR firmware)
          compare-axg-jethub-j100 = boardTest ./tests/boards/axg-jethub-j100.nix;

          # GXL family (V2 AES encryption, structural comparison only)
          compare-gxl-lepotato = boardTest ./tests/boards/gxl-lepotato.nix;
        }
      );
    };
}
