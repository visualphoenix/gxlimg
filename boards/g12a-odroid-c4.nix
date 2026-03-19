# ODROID-C4 (S905X3 / SM1) — G12A family, V3 signing
#
# Two-step BL30, BL3X-HDR for BL31, 9 DDR firmware files.
{
  boardName = "odroid-c4";
  boardDescription = "ODROID-C4 (S905X3 / SM1)";
  fipSubdir = "odroid-c4";
  socFamily = "g12a";
  defconfig = "odroid-c4_defconfig";

  propTool = "aml_encrypt_g12a";

  preprocessScript = ''
    bash $FIP/blx_fix.sh \
      $FIP/bl30.bin $TMPDIR/zero_tmp $TMPDIR/bl30_zero.bin \
      $FIP/bl301.bin $TMPDIR/bl301_zero.bin \
      $TMPDIR/bl30_new.bin bl30
    rm -f $TMPDIR/zero_tmp $TMPDIR/bl30_zero.bin $TMPDIR/bl301_zero.bin

    bash $FIP/blx_fix.sh \
      $FIP/bl2.bin $TMPDIR/zero_tmp $TMPDIR/bl2_zero.bin \
      $FIP/acs.bin $TMPDIR/bl21_zero.bin \
      $TMPDIR/bl2_new.bin bl2
    rm -f $TMPDIR/zero_tmp $TMPDIR/bl2_zero.bin $TMPDIR/bl21_zero.bin
  '';

  signScript = ''
    gxlimg -t bl30 -s $TMPDIR/bl30_new.bin $BLD/bl30_new.bin.enc
    gxlimg -t bl3x -s $FIP/bl31.img $BLD/bl31.img.enc
    gxlimg -t bl3x -s $UBOOT $BLD/bl33.bin.enc
    gxlimg -t bl2 -s $TMPDIR/bl2_new.bin $BLD/bl2.n.bin.sig

    gxlimg -t fip --rev v3 \
      --bl2 $BLD/bl2.n.bin.sig \
      --bl30 $BLD/bl30_new.bin.enc \
      --bl31 $BLD/bl31.img.enc \
      --bl33 $BLD/bl33.bin.enc \
      --ddrfw $FIP/ddr4_1d.fw --ddrfw $FIP/ddr4_2d.fw \
      --ddrfw $FIP/ddr3_1d.fw --ddrfw $FIP/piei.fw \
      --ddrfw $FIP/lpddr4_1d.fw --ddrfw $FIP/lpddr4_2d.fw \
      --ddrfw $FIP/diag_lpddr4.fw --ddrfw $FIP/aml_ddr.fw \
      --ddrfw $FIP/lpddr3_1d.fw \
      $BLD/u-boot.bin
  '';

  propSignScript = ''
    run_prop --bl30sig \
      --input $TMPDIR/bl30_new.bin \
      --output $BLD/bl30_new.bin.g12a.enc \
      --level v3

    run_prop --bl3sig \
      --input $BLD/bl30_new.bin.g12a.enc \
      --output $BLD/bl30_new.bin.enc \
      --level v3 --type bl30

    run_prop --bl3sig \
      --input $FIP/bl31.img \
      --output $BLD/bl31.img.enc \
      --level v3 --type bl31

    run_prop --bl3sig \
      --input $UBOOT \
      --output $BLD/bl33.bin.enc \
      --level v3 --type bl33

    run_prop --bl2sig \
      --input $TMPDIR/bl2_new.bin \
      --output $BLD/bl2.n.bin.sig

    run_prop --bootmk \
      --output $BLD/u-boot.bin --level v3 \
      --bl2 $BLD/bl2.n.bin.sig \
      --bl30 $BLD/bl30_new.bin.enc \
      --bl31 $BLD/bl31.img.enc \
      --bl33 $BLD/bl33.bin.enc \
      --ddrfw1 $FIP/ddr4_1d.fw --ddrfw2 $FIP/ddr4_2d.fw \
      --ddrfw3 $FIP/ddr3_1d.fw --ddrfw4 $FIP/piei.fw \
      --ddrfw5 $FIP/lpddr4_1d.fw --ddrfw6 $FIP/lpddr4_2d.fw \
      --ddrfw7 $FIP/diag_lpddr4.fw --ddrfw8 $FIP/aml_ddr.fw \
      --ddrfw9 $FIP/lpddr3_1d.fw
  '';

  compareFiles = [
    { name = "bl30_new.bin.enc"; prop = "$PROP/bl30_new.bin.enc"; open = "$OPEN/bl30_new.bin.enc"; }
    { name = "bl31.img.enc";     prop = "$PROP/bl31.img.enc";     open = "$OPEN/bl31.img.enc"; }
    { name = "bl33.bin.enc";     prop = "$PROP/bl33.bin.enc";     open = "$OPEN/bl33.bin.enc"; }
    { name = "bl2.n.bin.sig";    prop = "$PROP/bl2.n.bin.sig";    open = "$OPEN/bl2.n.bin.sig"; }
    { name = "u-boot.bin";       prop = "$PROP/u-boot.bin";       open = "$OPEN/u-boot.bin"; }
  ];

  extraDiagnostics = ''
    echo "" >> $report
    echo "=== BL30 intermediate (proprietary bl30sig step) ===" >> $report
    sz=$(stat -c%s "$PROP/bl30_new.bin.g12a.enc")
    echo "  bl30_new.bin.g12a.enc: size=$sz" >> $report

    echo "" >> $report
    echo "=== BL3X-HDR presence check ===" >> $report
    for label_path in "proprietary:$PROP/bl31.img.enc" "opensource:$OPEN/bl31.img.enc"; do
      label="''${label_path%%:*}"
      path="''${label_path#*:}"
      if od -A x -t x1z -N 16 "$path" | grep -q "BL3X"; then
        echo "$label bl31.img.enc: HAS BL3X-HDR at offset 0" >> $report
      else
        echo "$label bl31.img.enc: NO BL3X-HDR at offset 0" >> $report
      fi
    done
  '';
}
