# Khadas VIM3L (S905D3 / SM1) — G12A family, V3 signing
let base = import ./g12a-odroid-c4.nix; in
base // {
  boardName = "khadas-vim3l";
  boardDescription = "Khadas VIM3L (S905D3 / SM1)";
  fipSubdir = "khadas-vim3l";
  defconfig = "khadas-vim3l_defconfig";
  extraDiagnostics = "";
}
