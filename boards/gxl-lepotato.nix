# Le Potato / Libre Computer AML-S905X-CC (S905X / GXL) — V2 AES encryption
#
# GXL uses AES-256-CBC encryption (amlcblk.c) instead of SHA256 signing.
# The proprietary tool generates AES keys via srand(time())+rand(), which
# GXLIMG_COMPAT_NONCE matches via the same PRNG sequence.  With faketime
# pinning time(), BL2, BL3x, and FIP encryption are all byte-identical.
{
  boardName = "lepotato";
  boardDescription = "Le Potato / Libre Computer AML-S905X-CC (S905X / GXL)";
  fipSubdir = "lepotato";
  socFamily = "gxl";
  defconfig = "libretech-cc_defconfig";

  propTool = "aml_encrypt_gxl";
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
    gxlimg -t bl2 -s $TMPDIR/bl2_new.bin $BLD/bl2.n.bin.sig
    gxlimg -t bl3x -c $TMPDIR/bl30_new.bin $BLD/bl30_new.bin.enc
    gxlimg -t bl3x -c $FIP/bl31.img $BLD/bl31.img.enc
    gxlimg -t bl3x -c $UBOOT $BLD/bl33.bin.enc

    gxlimg -t fip \
      --bl2 $BLD/bl2.n.bin.sig \
      --bl30 $BLD/bl30_new.bin.enc \
      --bl31 $BLD/bl31.img.enc \
      --bl33 $BLD/bl33.bin.enc \
      $BLD/u-boot.bin
  '';

  # GXL comparison requires faketime on the gxlimg side too (run_open wrapper).
  # The test builder handles this via GXLIMG_COMPAT_NONCE + faketime.
  propSignScript = ''
    run_prop --bl2sig \
      --input $TMPDIR/bl2_new.bin \
      --output $BLD/bl2.n.bin.sig

    run_prop --bl3enc \
      --input $TMPDIR/bl30_new.bin \
      --output $BLD/bl30_new.bin.enc

    run_prop --bl3enc \
      --input $FIP/bl31.img \
      --output $BLD/bl31.img.enc

    run_prop --bl3enc \
      --input $UBOOT \
      --output $BLD/bl33.bin.enc

    run_prop --bootmk \
      --output $BLD/u-boot.bin \
      --bl2 $BLD/bl2.n.bin.sig \
      --bl30 $BLD/bl30_new.bin.enc \
      --bl31 $BLD/bl31.img.enc \
      --bl33 $BLD/bl33.bin.enc
  '';

  # GXL comparison test needs faketime on gxlimg side
  gxlFaketime = true;

  compareFiles = [
    { name = "bl2.n.bin.sig";     prop = "$PROP/bl2.n.bin.sig";     open = "$OPEN/bl2.n.bin.sig"; }
    { name = "bl30_new.bin.enc";  prop = "$PROP/bl30_new.bin.enc";  open = "$OPEN/bl30_new.bin.enc"; }
    { name = "bl31.img.enc";      prop = "$PROP/bl31.img.enc";      open = "$OPEN/bl31.img.enc"; }
    { name = "bl33.bin.enc";      prop = "$PROP/bl33.bin.enc";      open = "$OPEN/bl33.bin.enc"; }
    { name = "u-boot.bin";        prop = "$PROP/u-boot.bin";        open = "$OPEN/u-boot.bin"; }
  ];

  extraDiagnostics = "";
}
