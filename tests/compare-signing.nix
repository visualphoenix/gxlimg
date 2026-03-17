# Parameterized comparison test: gxlimg vs proprietary aml_encrypt_* reference.
#
# Each board config provides preprocessing, signing commands, and file lists.
# The proprietary binary is a statically-linked x86_64 ELF run via qemu-user.
#
# Board configs are in tests/boards/*.nix and call this with their parameters.
{
  pkgs,
  gxlimg,

  # Board identification
  boardName,           # e.g. "odroid-c4"
  fipSubdir,           # directory in amlogic-boot-fip repo
  propTool,            # e.g. "aml_encrypt_g12a"

  # Extra nativeBuildInputs (e.g. python3 for acs_tool.py)
  extraBuildInputs ? [],

  # Shell script fragments (each is a string)
  preprocessScript,    # shared preprocessing for both pipelines
  propSignScript,      # proprietary signing commands
  openSignScript,      # gxlimg signing commands

  # List of { name, prop, open } for file comparison
  # Each entry: { name = "bl30.bin.enc"; prop = "$PROP/bl30.bin.enc"; open = "$OPEN/bl30.bin.enc"; }
  compareFiles,

  # Extra diagnostic script (optional, appended to report)
  extraDiagnostics ? "",
}:

let
  amlogic-boot-fip = pkgs.fetchFromGitHub {
    owner = "LibreELEC";
    repo = "amlogic-boot-fip";
    rev = "master";
    sha256 = "sha256-jKBym2QYeWpjFEHOSYprqG59zO/jZ7zUjfKWekf1MYw=";
  };

  compareFilesBash = builtins.concatStringsSep "\n" (map (f:
    ''compare_file "${f.name}" "${f.prop}" "${f.open}"''
  ) compareFiles);
in
pkgs.runCommand "compare-gxlimg-${boardName}" {
  nativeBuildInputs = [
    gxlimg
    pkgs.qemu-user
    pkgs.libfaketime
  ] ++ extraBuildInputs;

  # The proprietary binaries read /dev/urandom for key/nonce generation.
  # Without sandbox access to /dev/urandom, qemu-x86_64 hangs.
  requiredSystemFeatures = [];
  __noChroot = true;
} ''
  set -euo pipefail

  FIP=${amlogic-boot-fip}/${fipSubdir}
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
    faketime "$FAKETIME_FMT" qemu-x86_64 "$FIP/${propTool}" "$@"
  }

  #
  # === Preprocessing (shared — identical inputs for both pipelines) ===
  #
  ${preprocessScript}

  #
  # === Proprietary pipeline (${propTool} via qemu-x86_64) ===
  #
  ${propSignScript}

  #
  # === Open-source pipeline (gxlimg) ===
  #
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

      # Dump first 512 bytes of each for header comparison
      echo "  --- proprietary header (first 0x200 bytes) ---" >> $report
      od -A x -t x1z -N 512 "$prop" >> $report 2>&1
      echo "  --- opensource header (first 0x200 bytes) ---" >> $report
      od -A x -t x1z -N 512 "$open" >> $report 2>&1

      # Save full hex dumps for detailed analysis
      od -A x -t x1z "$prop" > "$out/''${name}.proprietary.hex"
      od -A x -t x1z "$open" > "$out/''${name}.opensource.hex"
    fi
  }

  echo "=== gxlimg vs ${propTool} comparison (${boardName} firmware) ===" > $report
  echo "" >> $report

  ${compareFilesBash}

  ${extraDiagnostics}

  echo "" >> $report
  echo "=== Summary ===" >> $report
  matches=$(grep -c "^MATCH:" $report || true)
  differs=$(grep -c "^DIFFER:" $report || true)
  echo "Matches: $matches  Differences: $differs" >> $report

  cat $report

  # Fail the build if any files differ
  if [ "$differs" -gt 0 ]; then
    echo ""
    echo "FAILURE: $differs file(s) differ between proprietary and open-source output"
    exit 1
  fi
''
