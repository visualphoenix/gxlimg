# Le Potato / Libre Computer AML-S905X-CC (S905X / GXL) — V2 AES encryption
#
# GXL uses AES-256-CBC encryption (amlcblk.c) instead of SHA256 signing.
# The proprietary tool generates AES keys via srand(time())+rand(), which
# GXLIMG_COMPAT_NONCE matches via the same PRNG sequence.  With faketime
# pinning time(), BL2, BL3x, and FIP encryption are all byte-identical.
#
# Uses mainline U-Boot (libretech-cc_defconfig) as BL33 payload.
{ pkgs, gxlimg, uboot }:

import ../compare-signing.nix {
  inherit pkgs gxlimg uboot;

  boardName = "lepotato";
  fipSubdir = "lepotato";
  propTool = "aml_encrypt_gxl";

  extraBuildInputs = [ pkgs.python3 ];

  preprocessScript = ''
    # GXL preprocessing: acs_tool.py + blx_fix.sh with bl21.bin
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
    # GXL: BL2 signing
    run_prop --bl2sig \
      --input $TMPDIR/bl2_new.bin \
      --output $PROP/bl2.n.bin.sig

    # GXL: BL3x AES encryption (--bl3enc, not --bl3sig)
    run_prop --bl3enc \
      --input $TMPDIR/bl30_new.bin \
      --output $PROP/bl30_new.bin.enc

    run_prop --bl3enc \
      --input $FIP/bl31.img \
      --output $PROP/bl31.img.enc

    # BL33 (mainline U-Boot)
    run_prop --bl3enc \
      --input $UBOOT \
      --output $PROP/bl33.bin.enc

    # FIP assembly (V2, no --level)
    run_prop --bootmk \
      --output $PROP/u-boot.bin \
      --bl2 $PROP/bl2.n.bin.sig \
      --bl30 $PROP/bl30_new.bin.enc \
      --bl31 $PROP/bl31.img.enc \
      --bl33 $PROP/bl33.bin.enc
  '';

  openSignScript = ''
    # Helper: run gxlimg under faketime to match proprietary timestamp
    run_open() {
      faketime "$FAKETIME_FMT" gxlimg "$@"
    }

    # BL2 signing (same as V3)
    run_open -t bl2 -s $TMPDIR/bl2_new.bin $OPEN/bl2.n.bin.sig

    # BL3x encryption (-c, not -s)
    run_open -t bl3x -c $TMPDIR/bl30_new.bin $OPEN/bl30_new.bin.enc
    run_open -t bl3x -c $FIP/bl31.img $OPEN/bl31.img.enc

    # BL33 (mainline U-Boot)
    run_open -t bl3x -c $UBOOT $OPEN/bl33.bin.enc

    # FIP assembly (V2, no --rev)
    run_open -t fip \
      --bl2 $OPEN/bl2.n.bin.sig \
      --bl30 $OPEN/bl30_new.bin.enc \
      --bl31 $OPEN/bl31.img.enc \
      --bl33 $OPEN/bl33.bin.enc \
      $OPEN/u-boot.bin
  '';

  # With GXLIMG_COMPAT_NONCE + faketime, all outputs are byte-identical:
  # BL2 nonce, BL3x AES keys/IVs, and FIP encryption all use the same
  # srand(time())+rand() PRNG sequence as the proprietary tool.
  compareFiles = [
    { name = "bl2.n.bin.sig";     prop = "$PROP/bl2.n.bin.sig";     open = "$OPEN/bl2.n.bin.sig"; }
    { name = "bl30_new.bin.enc";  prop = "$PROP/bl30_new.bin.enc";  open = "$OPEN/bl30_new.bin.enc"; }
    { name = "bl31.img.enc";      prop = "$PROP/bl31.img.enc";      open = "$OPEN/bl31.img.enc"; }
    { name = "bl33.bin.enc";      prop = "$PROP/bl33.bin.enc";      open = "$OPEN/bl33.bin.enc"; }
    { name = "u-boot.bin";        prop = "$PROP/u-boot.bin";        open = "$OPEN/u-boot.bin"; }
  ];
}
