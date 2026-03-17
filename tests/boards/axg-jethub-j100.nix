# JetHub J100 (A113X / AXG) — V3 signing, no DDR firmware
#
# AXG uses V3 signing (amlsblk.c) like G12A, but:
#   - BL30 is single-step signed (--bl3sig), not two-step (--bl30sig + --bl3sig)
#   - No DDR firmware in FIP assembly
#   - BL2 preprocessing uses acs_tool.py + bl21.bin (like GXL, not acs.bin)
#
# Note: jethub-j80 is actually GXL, not AXG. The AXG boards in amlogic-boot-fip
# are jethub-j100 and amper-gz80x.
{ pkgs, gxlimg }:

import ../compare-signing.nix {
  inherit pkgs gxlimg;

  boardName = "jethub-j100";
  fipSubdir = "jethub-j100";
  propTool = "aml_encrypt_axg";

  extraBuildInputs = [ pkgs.python3 ];

  preprocessScript = ''
    # AXG preprocessing: acs_tool.py + blx_fix.sh with bl21.bin
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

  propSignScript = ''
    # AXG: BL30 single-step signing (--bl3sig, NOT --bl30sig)
    run_prop --bl3sig \
      --input $TMPDIR/bl30_new.bin \
      --output $PROP/bl30_new.bin.enc \
      --level 3 --type bl30

    # BL31
    run_prop --bl3sig \
      --input $FIP/bl31.img \
      --output $PROP/bl31.img.enc \
      --level 3 --type bl31

    # BL2
    run_prop --bl2sig \
      --input $TMPDIR/bl2_new.bin \
      --output $PROP/bl2.n.bin.sig

    # FIP assembly (V3, no DDR firmware, bl31 as dummy bl33)
    run_prop --bootmk \
      --output $PROP/u-boot.bin --level v3 \
      --bl2 $PROP/bl2.n.bin.sig \
      --bl30 $PROP/bl30_new.bin.enc \
      --bl31 $PROP/bl31.img.enc \
      --bl33 $PROP/bl31.img.enc
  '';

  openSignScript = ''
    # BL30: single-step signing (use -t bl3x, NOT -t bl30)
    gxlimg -t bl3x -s $TMPDIR/bl30_new.bin $OPEN/bl30_new.bin.enc

    # BL31
    gxlimg -t bl3x -s $FIP/bl31.img $OPEN/bl31.img.enc

    # BL2
    gxlimg -t bl2 -s $TMPDIR/bl2_new.bin $OPEN/bl2.n.bin.sig

    # FIP assembly (AXG V3, no DDR firmware — preserves @AML in FIP)
    gxlimg -t fip --rev axg \
      --bl2 $OPEN/bl2.n.bin.sig \
      --bl30 $OPEN/bl30_new.bin.enc \
      --bl31 $OPEN/bl31.img.enc \
      --bl33 $OPEN/bl31.img.enc \
      $OPEN/u-boot.bin
  '';

  compareFiles = [
    { name = "bl30_new.bin.enc"; prop = "$PROP/bl30_new.bin.enc"; open = "$OPEN/bl30_new.bin.enc"; }
    { name = "bl31.img.enc";     prop = "$PROP/bl31.img.enc";     open = "$OPEN/bl31.img.enc"; }
    { name = "bl2.n.bin.sig";    prop = "$PROP/bl2.n.bin.sig";    open = "$OPEN/bl2.n.bin.sig"; }
    { name = "u-boot.bin";       prop = "$PROP/u-boot.bin";       open = "$OPEN/u-boot.bin"; }
  ];
}
