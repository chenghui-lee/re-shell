---
name: linux-re
user-invocable: false
description: >
  Reverse engineer Linux ELF executables, shared libraries, core dumps, and
  embedded Linux userland using GDB, qemu-user, and syscall tracing. Applies to
  foreign-architecture ELF execution, target sysroots, and remote Linux debugging.
---

# Linux Reverse Engineering

Use the general static tools from `CLAUDE.md`; this skill covers Linux execution
and debugging. GDB, qemu-user, and strace are installed only on Linux. On Darwin,
use the [analysis VM](../../../docs/analysis-vm.md); LLDB handles native Mach-O.
Keep extracted root filesystems, logs, and core dumps under `tmp/` and final
deliverables under `artifacts/<identifier>/`.

## Triage before execution

```sh
file ./sample
readelf -hW ./sample
readelf -lW ./sample  # PT_INTERP identifies the required dynamic loader
readelf -dW ./sample  # NEEDED, RPATH, RUNPATH
```

Determine the CPU, endianness, ABI, static/dynamic linkage, and PIE status. For
untrusted ELF files, inspect dependencies with `readelf` rather than running
`ldd`. Match the emulator to the ABI: `qemu-arm` versus `qemu-armeb`,
`qemu-mips` versus `qemu-mipsel`, or `qemu-aarch64`, `qemu-riscv64`, etc.

For dynamic executables, extract the matching loader and libraries from the
firmware or distribution into `tmp/rootfs`, preserving symlinks and paths such
as `lib/ld-linux-armhf.so.3`. Do not mix host libc with target libraries.
qemu-user is for supported Linux userland ABIs; raw MCU images need an actual
device, instruction emulation, or a matching system emulator/board model.

## Execute and debug a foreign Linux ELF

Inside Linux, for an ARM little-endian example:

```sh
qemu-arm -L "$PWD/tmp/rootfs" ./tmp/rootfs/usr/bin/target argument

# Terminal 1: wait for the debugger before executing guest instructions
qemu-arm -L "$PWD/tmp/rootfs" -g 1234 ./tmp/rootfs/usr/bin/target argument

# Terminal 2
gdb -nx ./tmp/rootfs/usr/bin/target
```

```gdb
set sysroot ./tmp/rootfs
target remote localhost:1234
info files
info registers
x/12i $pc
break main
continue
```

Use `continue` after connecting; `run` is for launching a native inferior.
Stripped files may have no `main` symbol: start from the current PC and ELF entry
point, inspect code, and set address breakpoints. For PIE/shared objects, translate
static addresses using the runtime load bias from loaded sections/mappings; do
not use raw Ghidra addresses without checking the image base. `set sysroot`
controls GDB's library lookup, while QEMU `-L` selects target interpreter/library
paths. Neither is a chroot: absolute file accesses and external resources still
depend on the execution environment. Device-specific ioctls and firmware services
may be unsupported; use a fuller guest or hardware when those dependencies matter.

QEMU's GDB listener should remain inside the analysis VM or a trusted local
environment; it is not an authenticated remote debugging service.

## Trace execution

```sh
# Native Linux process
strace -f -s 256 -o tmp/native.strace ./native-target argument

# Guest syscalls: strace cannot use ptrace to trace the emulated process
QEMU_STRACE=1 qemu-arm -L "$PWD/tmp/rootfs" \
  ./tmp/rootfs/usr/bin/target argument 2>tmp/guest.strace
```

QEMU's syscall decoding is incomplete. For instruction logs, inspect
`qemu-arm -d help` and select a bounded run with `-D tmp/qemu.log`.

## Native debugging and core dumps

```sh
gdb --args ./native-target argument
# break main; run; bt; info registers; x/16gx $sp

gdb ./matching-executable ./tmp/core
# set sysroot ./tmp/rootfs
# info sharedlibrary
# thread apply all bt
```

Core analysis needs the exact executable and corresponding libraries/debug
symbols. For live remote hardware or a real Linux target, connect to its GDB
server using `target remote host:port` and use matching local symbols/sysroot.
Do not assume qemu-user implements every native ptrace/debugging feature.

## Validate the toolchain

On Linux, `nix build .#checks.x86_64-linux.debug-smoke` (or `aarch64-linux`)
assembles a foreign RISC-V ELF and verifies QEMU execution, a GDB breakpoint,
register contents, and normal exit. See `nix/debug-smoke.*`. This check has no
firmware dependency and does not prove a particular extracted program can run.
