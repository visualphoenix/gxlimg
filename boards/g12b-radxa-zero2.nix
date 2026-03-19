# Radxa Zero 2 (A311D / G12B) — G12B family, V3 signing
let base = import ./g12b-khadas-vim3.nix; in
base // {
  boardName = "radxa-zero2";
  boardDescription = "Radxa Zero 2 (A311D / G12B)";
  fipSubdir = "radxa-zero2";
  defconfig = "radxa-zero2_defconfig";
}
