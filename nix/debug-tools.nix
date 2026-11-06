{ pkgs }:
let
  inherit (pkgs) lib;
in
[ pkgs.openocd ] # JTAG/SWD GDB server on both hosts
++ lib.optionals pkgs.stdenv.isLinux [
  pkgs.gdb # nixpkgs enables all target architectures by default
  pkgs.qemu-user # Foreign Linux processes require a Linux host kernel
  pkgs.strace # Native syscalls; QEMU guest syscalls use QEMU_STRACE
]
++ lib.optionals pkgs.stdenv.isDarwin [
  # Use Apple's LLDB/debugserver pair. The pinned LLVM LLDB crashes while
  # opening Mach-O files on the current macOS; Apple's debugserver is signed.
  # Requires Xcode or Command Line Tools on the host (not a Nix dependency).
  (pkgs.writeShellScriptBin "lldb" ''
    exec /usr/bin/xcrun lldb "$@"
  '')
]
