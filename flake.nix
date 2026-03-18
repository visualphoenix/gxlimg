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
          gxlimg-static = pkgs.pkgsStatic.callPackage ./package.nix { };
          default = self.packages.${system}.gxlimg;
        }
      );

      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          gxlimg = self.packages.${system}.gxlimg;

          # Per-board mainline U-Boot builds.
          # Each board gets its correct defconfig so we produce a real,
          # board-specific u-boot.bin to use as the BL33 payload.
          mkUBoot = defconfig: pkgs.buildUBoot {
            inherit defconfig;
            extraMeta.platforms = [ "aarch64-linux" ];
            filesToInstall = [ "u-boot.bin" ];
          };

          uboot = {
            # G12A / SM1
            odroid-c4    = mkUBoot "odroid-c4_defconfig";
            khadas-vim3l = mkUBoot "khadas-vim3l_defconfig";
            bananapi-m5  = mkUBoot "bananapi-m5_defconfig";
            # G12B
            odroid-n2    = mkUBoot "odroid-n2_defconfig";
            radxa-zero2  = mkUBoot "radxa-zero2_defconfig";
            khadas-vim3  = mkUBoot "khadas-vim3_defconfig";
            # AXG
            jethub-j100  = mkUBoot "jethub_j100_defconfig";
            # GXL
            lepotato     = mkUBoot "libretech-cc_defconfig";
          };

          boardTest = path: boardUBoot: import path { inherit pkgs gxlimg; uboot = boardUBoot; };
        in {
          # G12A family (V3 signing, two-step BL30, DDR firmware)
          compare-g12a-odroid-c4   = boardTest ./tests/boards/g12a-odroid-c4.nix   uboot.odroid-c4;
          compare-g12a-vim3l       = boardTest ./tests/boards/g12a-vim3l.nix       uboot.khadas-vim3l;
          compare-g12a-bananapi-m5 = boardTest ./tests/boards/g12a-bananapi-m5.nix uboot.bananapi-m5;

          # G12B family (V3 signing, same flow as G12A)
          compare-g12b-odroid-n2   = boardTest ./tests/boards/g12b-odroid-n2.nix   uboot.odroid-n2;
          compare-g12b-radxa-zero2 = boardTest ./tests/boards/g12b-radxa-zero2.nix uboot.radxa-zero2;
          compare-g12b-khadas-vim3 = boardTest ./tests/boards/g12b-khadas-vim3.nix uboot.khadas-vim3;

          # AXG family (V3 signing, single-step BL30, no DDR firmware)
          compare-axg-jethub-j100 = boardTest ./tests/boards/axg-jethub-j100.nix uboot.jethub-j100;

          # GXL family (V2 AES encryption, structural comparison only)
          compare-gxl-lepotato = boardTest ./tests/boards/gxl-lepotato.nix uboot.lepotato;
        }
      );
    };
}
