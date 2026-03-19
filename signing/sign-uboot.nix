# Build a signed mainline U-Boot FIP image using gxlimg.
#
# Takes a board config (from boards/*.nix) and produces $out/u-boot.bin
# ready to flash. Uses only open-source tools — no proprietary binaries.
{
  lib,
  pkgs,
  gxlimg,
  uboot,
  board,
}:

let
  amlogic-boot-fip = pkgs.fetchFromGitHub {
    owner = "LibreELEC";
    repo = "amlogic-boot-fip";
    rev = "master";
    sha256 = "sha256-jKBym2QYeWpjFEHOSYprqG59zO/jZ7zUjfKWekf1MYw=";
  };

  extraPkgs =
    if board ? extraBuildInputs && board.extraBuildInputs == "python3"
    then [ pkgs.python3 ]
    else [];
in
pkgs.runCommand "uboot-signed-${board.boardName}" {
  nativeBuildInputs = [ gxlimg ] ++ extraPkgs;

  passthru = {
    inherit (board) boardName socFamily;
    inherit uboot gxlimg;
  };

  meta = {
    description = "Signed mainline U-Boot for ${board.boardDescription}";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
} ''
  set -euo pipefail

  FIP=${amlogic-boot-fip}/${board.fipSubdir}
  UBOOT=${uboot}/u-boot.bin
  BLD=$out

  mkdir -p $out

  ${board.preprocessScript}
  ${board.signScript}
''
