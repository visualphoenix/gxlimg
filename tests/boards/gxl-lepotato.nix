# Le Potato / Libre Computer AML-S905X-CC (S905X / GXL) — V2 AES encryption
#
# GXL uses AES-256-CBC encryption (amlcblk.c) instead of SHA256 signing.
# The AES key and IV come from /dev/urandom in both proprietary and gxlimg,
# so we can only do STRUCTURAL comparison (sizes, header layout, magic values),
# not byte-identical comparison.
#
# Preprocessing: acs_tool.py + bl21.bin (different from G12A's acs.bin)
{ pkgs, gxlimg }:

import ../compare-signing.nix {
  inherit pkgs gxlimg;

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

    # FIP assembly (V2, no --level, use bl31 as dummy bl33)
    run_prop --bootmk \
      --output $PROP/u-boot.bin \
      --bl2 $PROP/bl2.n.bin.sig \
      --bl30 $PROP/bl30_new.bin.enc \
      --bl31 $PROP/bl31.img.enc \
      --bl33 $PROP/bl31.img.enc
  '';

  openSignScript = ''
    # BL2 signing (same as V3)
    gxlimg -t bl2 -s $TMPDIR/bl2_new.bin $OPEN/bl2.n.bin.sig

    # BL3x encryption (-c, not -s)
    gxlimg -t bl3x -c $TMPDIR/bl30_new.bin $OPEN/bl30_new.bin.enc
    gxlimg -t bl3x -c $FIP/bl31.img $OPEN/bl31.img.enc

    # FIP assembly (V2, no --rev)
    gxlimg -t fip \
      --bl2 $OPEN/bl2.n.bin.sig \
      --bl30 $OPEN/bl30_new.bin.enc \
      --bl31 $OPEN/bl31.img.enc \
      --bl33 $OPEN/bl31.img.enc \
      $OPEN/u-boot.bin
  '';

  # BL2 uses nonce from srand(time()) — byte-identical via faketime.
  # BL3x and FIP use random AES keys — structural comparison only.
  compareFiles = [
    { name = "bl2.n.bin.sig"; prop = "$PROP/bl2.n.bin.sig"; open = "$OPEN/bl2.n.bin.sig"; }
  ];

  extraDiagnostics = ''
    echo "" >> $report
    echo "=== GXL structural comparison (AES-encrypted, not byte-identical) ===" >> $report

    structural_compare() {
      local name="$1"
      local prop="$2"
      local open="$3"

      if [ ! -f "$prop" ] || [ ! -f "$open" ]; then
        echo "MISSING: $name" >> $report
        return
      fi

      local prop_sz=$(stat -c%s "$prop")
      local open_sz=$(stat -c%s "$open")

      if [ "$prop_sz" = "$open_sz" ]; then
        echo "STRUCTURAL-OK: $name (size=$prop_sz)" >> $report
      else
        echo "STRUCTURAL-DIFFER: $name (prop=$prop_sz open=$open_sz)" >> $report
      fi

      # Check AMLC magic at offset 12 (0x0C) in encrypted files
      prop_magic=$(od -A n -t x4 -N 4 -j 12 "$prop" 2>/dev/null | tr -d ' ')
      open_magic=$(od -A n -t x4 -N 4 -j 12 "$open" 2>/dev/null | tr -d ' ')
      echo "  magic@0x0C: prop=$prop_magic open=$open_magic" >> $report

      # Dump first 32 bytes of header
      echo "  --- proprietary header (first 32 bytes) ---" >> $report
      od -A x -t x1z -N 32 "$prop" >> $report 2>&1
      echo "  --- opensource header (first 32 bytes) ---" >> $report
      od -A x -t x1z -N 32 "$open" >> $report 2>&1
    }

    structural_compare "bl30_new.bin.enc" "$PROP/bl30_new.bin.enc" "$OPEN/bl30_new.bin.enc"
    structural_compare "bl31.img.enc"     "$PROP/bl31.img.enc"     "$OPEN/bl31.img.enc"
    structural_compare "u-boot.bin"       "$PROP/u-boot.bin"       "$OPEN/u-boot.bin"
  '';
}
