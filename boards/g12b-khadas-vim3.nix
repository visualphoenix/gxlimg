# Khadas VIM3 (A311D / G12B) — G12B family, V3 signing
#
# Same signing flow and DDR firmware as G12A, different propTool binary.
let base = import ./g12a-odroid-c4.nix; in
base // {
  boardName = "khadas-vim3";
  boardDescription = "Khadas VIM3 (A311D / G12B)";
  fipSubdir = "khadas-vim3";
  socFamily = "g12b";
  defconfig = "khadas-vim3_defconfig";
  propTool = "aml_encrypt_g12b";
  extraDiagnostics = "";
}
