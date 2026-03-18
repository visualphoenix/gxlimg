# ODROID-C4 (S905X3 / SM1) — G12A family, V3 signing
#
# Two-step BL30, BL3X-HDR for BL31, DDR firmware in FIP.
# Uses mainline U-Boot (odroid-c4_defconfig) as BL33 payload.
{ pkgs, gxlimg, uboot }:

import ../compare-signing.nix {
  inherit pkgs gxlimg uboot;

  boardName = "odroid-c4";
  fipSubdir = "odroid-c4";
  propTool = "aml_encrypt_g12a";

  preprocessScript = ''
    # blx_fix.sh: pad and concatenate bl30 + bl301
    bash $FIP/blx_fix.sh \
      $FIP/bl30.bin $TMPDIR/zero_tmp $TMPDIR/bl30_zero.bin \
      $FIP/bl301.bin $TMPDIR/bl301_zero.bin \
      $TMPDIR/bl30_new.bin bl30
    rm -f $TMPDIR/zero_tmp $TMPDIR/bl30_zero.bin $TMPDIR/bl301_zero.bin

    # blx_fix.sh: pad and concatenate bl2 + acs
    bash $FIP/blx_fix.sh \
      $FIP/bl2.bin $TMPDIR/zero_tmp $TMPDIR/bl2_zero.bin \
      $FIP/acs.bin $TMPDIR/bl21_zero.bin \
      $TMPDIR/bl2_new.bin bl2
    rm -f $TMPDIR/zero_tmp $TMPDIR/bl2_zero.bin $TMPDIR/bl21_zero.bin
  '';

  propSignScript = ''
    # BL30: two-step (bl30sig then bl3sig)
    run_prop --bl30sig \
      --input $TMPDIR/bl30_new.bin \
      --output $PROP/bl30_new.bin.g12a.enc \
      --level v3

    run_prop --bl3sig \
      --input $PROP/bl30_new.bin.g12a.enc \
      --output $PROP/bl30_new.bin.enc \
      --level v3 --type bl30

    # BL31
    run_prop --bl3sig \
      --input $FIP/bl31.img \
      --output $PROP/bl31.img.enc \
      --level v3 --type bl31

    # BL33 (mainline U-Boot)
    run_prop --bl3sig \
      --input $UBOOT \
      --output $PROP/bl33.bin.enc \
      --level v3 --type bl33

    # BL2
    run_prop --bl2sig \
      --input $TMPDIR/bl2_new.bin \
      --output $PROP/bl2.n.bin.sig

    # FIP assembly
    run_prop --bootmk \
      --output $PROP/u-boot.bin --level v3 \
      --bl2 $PROP/bl2.n.bin.sig \
      --bl30 $PROP/bl30_new.bin.enc \
      --bl31 $PROP/bl31.img.enc \
      --bl33 $PROP/bl33.bin.enc \
      --ddrfw1 $FIP/ddr4_1d.fw --ddrfw2 $FIP/ddr4_2d.fw \
      --ddrfw3 $FIP/ddr3_1d.fw --ddrfw4 $FIP/piei.fw \
      --ddrfw5 $FIP/lpddr4_1d.fw --ddrfw6 $FIP/lpddr4_2d.fw \
      --ddrfw7 $FIP/diag_lpddr4.fw --ddrfw8 $FIP/aml_ddr.fw \
      --ddrfw9 $FIP/lpddr3_1d.fw
  '';

  openSignScript = ''
    # BL30 (two-step)
    gxlimg -t bl30 -s $TMPDIR/bl30_new.bin $OPEN/bl30_new.bin.enc

    # BL31
    gxlimg -t bl3x -s $FIP/bl31.img $OPEN/bl31.img.enc

    # BL33 (mainline U-Boot)
    gxlimg -t bl3x -s $UBOOT $OPEN/bl33.bin.enc

    # BL2
    gxlimg -t bl2 -s $TMPDIR/bl2_new.bin $OPEN/bl2.n.bin.sig

    # FIP assembly
    gxlimg -t fip --rev v3 \
      --bl2 $OPEN/bl2.n.bin.sig \
      --bl30 $OPEN/bl30_new.bin.enc \
      --bl31 $OPEN/bl31.img.enc \
      --bl33 $OPEN/bl33.bin.enc \
      --ddrfw $FIP/ddr4_1d.fw --ddrfw $FIP/ddr4_2d.fw \
      --ddrfw $FIP/ddr3_1d.fw --ddrfw $FIP/piei.fw \
      --ddrfw $FIP/lpddr4_1d.fw --ddrfw $FIP/lpddr4_2d.fw \
      --ddrfw $FIP/diag_lpddr4.fw --ddrfw $FIP/aml_ddr.fw \
      --ddrfw $FIP/lpddr3_1d.fw \
      $OPEN/u-boot.bin
  '';

  compareFiles = [
    { name = "bl30_new.bin.enc"; prop = "$PROP/bl30_new.bin.enc"; open = "$OPEN/bl30_new.bin.enc"; }
    { name = "bl31.img.enc";     prop = "$PROP/bl31.img.enc";     open = "$OPEN/bl31.img.enc"; }
    { name = "bl33.bin.enc";     prop = "$PROP/bl33.bin.enc";     open = "$OPEN/bl33.bin.enc"; }
    { name = "bl2.n.bin.sig";    prop = "$PROP/bl2.n.bin.sig";    open = "$OPEN/bl2.n.bin.sig"; }
    { name = "u-boot.bin";       prop = "$PROP/u-boot.bin";       open = "$OPEN/u-boot.bin"; }
  ];

  extraDiagnostics = ''
    # BL30 intermediate from proprietary two-step process
    echo "" >> $report
    echo "=== BL30 intermediate (proprietary bl30sig step) ===" >> $report
    sz=$(stat -c%s "$PROP/bl30_new.bin.g12a.enc")
    echo "  bl30_new.bin.g12a.enc: size=$sz" >> $report

    # Check for BL3X-HDR presence in bl31 outputs
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
