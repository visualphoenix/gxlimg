# Khadas VIM3 (A311D / G12B) — G12B family, V3 signing
#
# Uses mainline U-Boot (khadas-vim3_defconfig) as BL33 payload.
{ pkgs, gxlimg, uboot }:

import ../compare-signing.nix {
  inherit pkgs gxlimg uboot;

  boardName = "khadas-vim3";
  fipSubdir = "khadas-vim3";
  propTool = "aml_encrypt_g12b";

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

  propSignScript = ''
    run_prop --bl30sig \
      --input $TMPDIR/bl30_new.bin \
      --output $PROP/bl30_new.bin.g12a.enc \
      --level v3

    run_prop --bl3sig \
      --input $PROP/bl30_new.bin.g12a.enc \
      --output $PROP/bl30_new.bin.enc \
      --level v3 --type bl30

    run_prop --bl3sig \
      --input $FIP/bl31.img \
      --output $PROP/bl31.img.enc \
      --level v3 --type bl31

    # BL33 (mainline U-Boot)
    run_prop --bl3sig \
      --input $UBOOT \
      --output $PROP/bl33.bin.enc \
      --level v3 --type bl33

    run_prop --bl2sig \
      --input $TMPDIR/bl2_new.bin \
      --output $PROP/bl2.n.bin.sig

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
    gxlimg -t bl30 -s $TMPDIR/bl30_new.bin $OPEN/bl30_new.bin.enc
    gxlimg -t bl3x -s $FIP/bl31.img $OPEN/bl31.img.enc

    # BL33 (mainline U-Boot)
    gxlimg -t bl3x -s $UBOOT $OPEN/bl33.bin.enc

    gxlimg -t bl2 -s $TMPDIR/bl2_new.bin $OPEN/bl2.n.bin.sig

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
}
