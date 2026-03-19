# BananaPi M5 (S905X3 / SM1) — G12A family, V3 signing
let base = import ./g12a-odroid-c4.nix; in
base // {
  boardName = "bananapi-m5";
  boardDescription = "BananaPi M5 (S905X3 / SM1)";
  fipSubdir = "bananapi-m5";
  defconfig = "bananapi-m5_defconfig";
  extraDiagnostics = "";
}
