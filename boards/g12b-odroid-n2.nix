# ODROID-N2 (S922X / G12B) — G12B family, V3 signing
#
# 8 DDR firmware files (no lpddr3_1d.fw), otherwise same as other G12B boards.
let base = import ./g12b-khadas-vim3.nix; in
base // {
  boardName = "odroid-n2";
  boardDescription = "ODROID-N2 (S922X / G12B)";
  fipSubdir = "odroid-n2";
  defconfig = "odroid-n2_defconfig";

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
      --ddrfw7 $FIP/diag_lpddr4.fw --ddrfw8 $FIP/aml_ddr.fw
  '';
}
