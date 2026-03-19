{
  description = "Open-source Amlogic GXL/G12A boot image signing tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      # Board configs — single source of truth for all signing parameters.
      # Each file returns an attrset with: boardName, defconfig, fipSubdir,
      # preprocessScript, signScript, propSignScript, compareFiles, etc.
      boards = {
        odroid-c4    = import ./boards/g12a-odroid-c4.nix;
        khadas-vim3l = import ./boards/g12a-vim3l.nix;
        bananapi-m5  = import ./boards/g12a-bananapi-m5.nix;
        odroid-n2    = import ./boards/g12b-odroid-n2.nix;
        radxa-zero2  = import ./boards/g12b-radxa-zero2.nix;
        khadas-vim3  = import ./boards/g12b-khadas-vim3.nix;
        jethub-j100  = import ./boards/axg-jethub-j100.nix;
        lepotato     = import ./boards/gxl-lepotato.nix;
      };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          gxlimg = self.packages.${system}.gxlimg;

          # Cross-compile U-Boot for aarch64 when building on x86_64.
          ubootPkgs = if system == "aarch64-linux"
            then pkgs
            else pkgs.pkgsCross.aarch64-multiplatform;

          mkUBoot = defconfig: ubootPkgs.buildUBoot {
            inherit defconfig;
            extraMeta.platforms = [ "aarch64-linux" "x86_64-linux" ];
            filesToInstall = [ "u-boot.bin" ];
          };
        in {
          gxlimg = pkgs.callPackage ./package.nix { };
          gxlimg-static = pkgs.pkgsStatic.callPackage ./package.nix { };
          default = self.packages.${system}.gxlimg;
        }
        # Signed U-Boot packages — one per board
        // lib.mapAttrs' (name: board:
          lib.nameValuePair "uboot-${name}" (import ./signing/sign-uboot.nix {
            inherit lib pkgs gxlimg board;
            uboot = mkUBoot board.defconfig;
          })
        ) boards
      );

      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          gxlimg = self.packages.${system}.gxlimg;

          ubootPkgs = if system == "aarch64-linux"
            then pkgs
            else pkgs.pkgsCross.aarch64-multiplatform;

          mkUBoot = defconfig: ubootPkgs.buildUBoot {
            inherit defconfig;
            extraMeta.platforms = [ "aarch64-linux" "x86_64-linux" ];
            filesToInstall = [ "u-boot.bin" ];
          };
        in
        lib.mapAttrs' (name: board:
          lib.nameValuePair "compare-${name}" (import ./tests/compare-signing.nix {
            inherit pkgs gxlimg board;
            uboot = mkUBoot board.defconfig;
          })
        ) boards
      );
    };
}
