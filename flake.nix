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
          # Board-specific comparison tests are added in subsequent patches.
          # Each test uses tests/compare-signing.nix as the parameterized
          # framework and lives in tests/boards/<soc>-<board>.nix.
        }
      );
    };
}
