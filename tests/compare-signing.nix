# Comparison test: gxlimg vs proprietary aml_encrypt_* reference.
#
# Takes a board config (from boards/*.nix) and runs both signing pipelines,
# then compares the outputs byte-for-byte.
{
  pkgs,
  gxlimg,
  uboot,
  board,
}:

let
  amlogic-boot-fip = pkgs.fetchFromGitHub {
    owner = "LibreELEC";
    repo = "amlogic-boot-fip";
    rev = "master";
    sha256 = "sha256-jKBym2QYeWpjFEHOSYprqG59zO/jZ7zUjfKWekf1MYw=";
  };

  extraPkgs =
    if board ? extraBuildInputs && board.extraBuildInputs == "python3"
    then [ pkgs.python3 ]
    else [];

  compareFilesBash = builtins.concatStringsSep "\n" (map (f:
    ''compare_file "${f.name}" "${f.prop}" "${f.open}"''
  ) board.compareFiles);

  # GXL needs faketime on the gxlimg side for byte-identical AES keys
  gxlFaketime = board.gxlFaketime or false;

  # For GXL, wrap gxlimg calls with faketime; for V3, use signScript as-is
  openSignScript =
    if gxlFaketime then ''
      run_open() {
        faketime "$FAKETIME_FMT" gxlimg "$@"
      }
      ${builtins.replaceStrings ["gxlimg "] ["run_open "] board.signScript}
    '' else board.signScript;
in
pkgs.runCommand "compare-gxlimg-${board.boardName}" {
  nativeBuildInputs = [
    gxlimg
    pkgs.qemu-user
    pkgs.libfaketime
  ] ++ extraPkgs;

  # The proprietary binaries read /dev/urandom for key/nonce generation.
  # Without sandbox access to /dev/urandom, qemu-x86_64 hangs.
  requiredSystemFeatures = [];
  __noChroot = true;
} ''
  set -euo pipefail

  FIP=${amlogic-boot-fip}/${board.fipSubdir}
  UBOOT=${uboot}/u-boot.bin
  PROP=$TMPDIR/proprietary
  OPEN=$TMPDIR/opensource
  mkdir -p $PROP $OPEN $out

  # Fixed epoch for byte-identical nonce comparison.
  # faketime makes the proprietary tool's time() return this value,
  # GXLIMG_COMPAT_NONCE makes gxlimg use srand(epoch)+rand() to match.
  COMPAT_EPOCH=315532800
  FAKETIME_FMT="1980-01-01 00:00:00"
  export GXLIMG_COMPAT_NONCE=$COMPAT_EPOCH

  # Helper: run proprietary tool via qemu with faketime
  run_prop() {
    faketime "$FAKETIME_FMT" qemu-x86_64 "$FIP/${board.propTool}" "$@"
  }

  #
  # === Preprocessing (shared — identical inputs for both pipelines) ===
  #
  ${board.preprocessScript}

  #
  # === Proprietary pipeline (${board.propTool} via qemu-x86_64) ===
  #
  BLD=$PROP
  ${board.propSignScript}

  #
  # === Open-source pipeline (gxlimg) ===
  #
  BLD=$OPEN
  ${openSignScript}

  #
  # === Compare outputs ===
  #
  report=$out/report.txt

  compare_file() {
    local name="$1"
    local prop="$2"
    local open="$3"

    if [ ! -f "$prop" ]; then
      echo "MISSING(prop): $name" >> $report
      return
    fi
    if [ ! -f "$open" ]; then
      echo "MISSING(open): $name" >> $report
      return
    fi

    local prop_sz=$(stat -c%s "$prop")
    local open_sz=$(stat -c%s "$open")
    local prop_sha=$(sha256sum "$prop" | cut -d' ' -f1)
    local open_sha=$(sha256sum "$open" | cut -d' ' -f1)

    if [ "$prop_sha" = "$open_sha" ]; then
      echo "MATCH: $name (size=$prop_sz sha256=$prop_sha)" >> $report
    else
      echo "DIFFER: $name" >> $report
      echo "  proprietary: size=$prop_sz sha256=$prop_sha" >> $report
      echo "  opensource:  size=$open_sz sha256=$open_sha" >> $report

      echo "  --- proprietary header (first 0x200 bytes) ---" >> $report
      od -A x -t x1z -N 512 "$prop" >> $report 2>&1
      echo "  --- opensource header (first 0x200 bytes) ---" >> $report
      od -A x -t x1z -N 512 "$open" >> $report 2>&1

      od -A x -t x1z "$prop" > "$out/''${name}.proprietary.hex"
      od -A x -t x1z "$open" > "$out/''${name}.opensource.hex"
    fi
  }

  echo "=== gxlimg vs ${board.propTool} comparison (${board.boardName} firmware) ===" > $report
  echo "" >> $report

  ${compareFilesBash}

  ${board.extraDiagnostics}

  echo "" >> $report
  echo "=== Summary ===" >> $report
  matches=$(grep -c "^MATCH:" $report || true)
  differs=$(grep -c "^DIFFER:" $report || true)
  echo "Matches: $matches  Differences: $differs" >> $report

  cat $report

  if [ "$differs" -gt 0 ]; then
    echo ""
    echo "FAILURE: $differs file(s) differ between proprietary and open-source output"
    exit 1
  fi
''
