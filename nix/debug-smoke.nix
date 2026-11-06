{
  pkgs,
  runCommand,
  gdb,
  qemu-user,
  python3,
}:
let
  # RISC-V is foreign to both supported Linux hosts (x86_64 and aarch64).
  binutils = pkgs.pkgsCross.riscv64.buildPackages.binutils;
  fixture = runCommand "re-debug-fixture" { nativeBuildInputs = [ binutils ]; } ''
    mkdir -p $out
    ${binutils.targetPrefix}as -g ${./debug-smoke.S} -o target.o
    ${binutils.targetPrefix}ld -static -e _start target.o -o $out/target
  '';
in
runCommand "re-debug-smoke" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out
  python ${./debug-smoke.py} ${qemu-user}/bin/qemu-riscv64 ${gdb}/bin/gdb ${fixture}/target > $out/result.txt
  cat $out/result.txt
''
