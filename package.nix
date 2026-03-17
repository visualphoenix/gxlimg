{
  lib,
  stdenv,
  openssl,
  reproducible ? true,
}:

stdenv.mkDerivation {
  pname = "gxlimg";
  version = "unstable-2025-11-10";

  src = lib.cleanSource ./.;

  buildInputs = [ openssl ];

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
    "LD=${stdenv.cc.targetPrefix}cc"
  ] ++ lib.optional reproducible "REPRODUCIBLE=1";

  installPhase = ''
    runHook preInstall
    install -Dm755 gxlimg $out/bin/gxlimg
    install -Dm755 acs_tool.py $out/bin/acs_tool.py
    runHook postInstall
  '';

  meta = {
    description = "Open-source Amlogic GXL/G12A boot image signing tool";
    longDescription = ''
      Reverse-engineered replacement for Amlogic's proprietary aml_encrypt_gxl.
      Creates signed/encrypted boot images for GXL (S905X) and G12A/G12B/SM1
      (S905X2/S905X3/S922X) SoCs. Handles BL2, BL30, BL31, BL33 signing and
      FIP image assembly.
    '';
    license = lib.licenses.bsd2;
    platforms = lib.platforms.linux;
    mainProgram = "gxlimg";
  };
}
