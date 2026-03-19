# JetHub J100 (A113X / AXG) — V3 signing, no DDR firmware
#
# AXG uses V3 signing like G12A, but:
#   - BL30 is single-step signed (not two-step)
#   - No DDR firmware in FIP assembly
#   - BL2 preprocessing uses acs_tool.py + bl21.bin (like GXL)
{
  boardName = "jethub-j100";
  boardDescription = "JetHub J100 (A113X / AXG)";
  fipSubdir = "jethub-j100";
  socFamily = "axg";
  defconfig = "jethub_j100_defconfig";

  propTool = "aml_encrypt_axg";
  extraBuildInputs = "python3";

  preprocessScript = ''
    python3 $FIP/acs_tool.py $FIP/bl2.bin $TMPDIR/bl2_acs.bin $FIP/acs.bin 0

    bash $FIP/blx_fix.sh \
      $TMPDIR/bl2_acs.bin $TMPDIR/zero_tmp $TMPDIR/bl2_zero.bin \
      $FIP/bl21.bin $TMPDIR/bl21_zero.bin \
      $TMPDIR/bl2_new.bin bl2
    rm -f $TMPDIR/zero_tmp $TMPDIR/bl2_zero.bin $TMPDIR/bl21_zero.bin

    bash $FIP/blx_fix.sh \
      $FIP/bl30.bin $TMPDIR/zero_tmp $TMPDIR/bl30_zero.bin \
      $FIP/bl301.bin $TMPDIR/bl301_zero.bin \
      $TMPDIR/bl30_new.bin bl30
    rm -f $TMPDIR/zero_tmp $TMPDIR/bl30_zero.bin $TMPDIR/bl301_zero.bin
  '';

  signScript = ''
    gxlimg -t bl3x -s $TMPDIR/bl30_new.bin $BLD/bl30_new.bin.enc
    gxlimg -t bl3x -s $FIP/bl31.img $BLD/bl31.img.enc
    gxlimg -t bl3x -s $UBOOT $BLD/bl33.bin.enc
    gxlimg -t bl2 -s $TMPDIR/bl2_new.bin $BLD/bl2.n.bin.sig

    gxlimg -t fip --rev axg \
      --bl2 $BLD/bl2.n.bin.sig \
      --bl30 $BLD/bl30_new.bin.enc \
      --bl31 $BLD/bl31.img.enc \
      --bl33 $BLD/bl33.bin.enc \
      $BLD/u-boot.bin
  '';

  propSignScript = ''
    run_prop --bl3sig \
      --input $TMPDIR/bl30_new.bin \
      --output $BLD/bl30_new.bin.enc \
      --level 3 --type bl30

    run_prop --bl3sig \
      --input $FIP/bl31.img \
      --output $BLD/bl31.img.enc \
      --level 3 --type bl31

    run_prop --bl3sig \
      --input $UBOOT \
      --output $BLD/bl33.bin.enc \
      --level 3 --type bl33

    run_prop --bl2sig \
      --input $TMPDIR/bl2_new.bin \
      --output $BLD/bl2.n.bin.sig

    run_prop --bootmk \
      --output $BLD/u-boot.bin --level v3 \
      --bl2 $BLD/bl2.n.bin.sig \
      --bl30 $BLD/bl30_new.bin.enc \
      --bl31 $BLD/bl31.img.enc \
      --bl33 $BLD/bl33.bin.enc
  '';

  compareFiles = [
    { name = "bl30_new.bin.enc"; prop = "$PROP/bl30_new.bin.enc"; open = "$OPEN/bl30_new.bin.enc"; }
    { name = "bl31.img.enc";     prop = "$PROP/bl31.img.enc";     open = "$OPEN/bl31.img.enc"; }
    { name = "bl33.bin.enc";     prop = "$PROP/bl33.bin.enc";     open = "$OPEN/bl33.bin.enc"; }
    { name = "bl2.n.bin.sig";    prop = "$PROP/bl2.n.bin.sig";    open = "$OPEN/bl2.n.bin.sig"; }
    { name = "u-boot.bin";       prop = "$PROP/u-boot.bin";       open = "$OPEN/u-boot.bin"; }
  ];

  extraDiagnostics = "";
}
