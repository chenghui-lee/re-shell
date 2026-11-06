# Linux analysis VM

`packages.<host-system>.analysis-vm` builds a headless NixOS VM runner using the
flake's pinned nixpkgs. The guest CPU matches the host (aarch64 or x86_64), and
the runner uses host QEMU with HVF/KVM where available, falling back to TCG.
Guest tools include multi-architecture GDB, qemu-user, strace, all-target binutils,
file, OpenOCD, GCC, Python, and Git. The full static toolchain stays in the host
dev shell. OpenOCD in the guest requires separately configured device access;
use host OpenOCD for a probe attached to macOS.

## Build

On Linux:

```sh
nix build .#analysis-vm
```

On macOS, the runner is a Darwin derivation but its NixOS guest contains Linux
derivations. Configure a working **same-architecture Linux builder** before
building, for example Nix's `linux-builder` or an existing remote Nix builder.
A configured remote builder needs the relevant `aarch64-linux` or `x86_64-linux`
system and enough disk space for the guest closure. Building this VM does not
bootstrap that builder. Once it is configured, use the same build command.

Keep `flake.lock` to reproduce the guest configuration; no lock update is needed.
The build may download a substantial kernel/tool closure. See the pinned
[NixOS QEMU VM module](https://github.com/NixOS/nixpkgs/blob/a82ccc39b39b621151d6732718e3e250109076fa/nixos/modules/virtualisation/qemu-vm.nix)
for runner options and host/guest package handling.

## Run and exchange files

From the repo root:

```sh
mkdir -p tmp/vm-share tmp/analysis-vm
cp ./sample tmp/vm-share/
SHARED_DIR="$PWD/tmp/vm-share" NIX_DISK_IMAGE="$PWD/tmp/analysis-vm/disk.qcow2" \
  ./result/bin/run-re-analysis-vm
```

The console logs in automatically as `analyst`, with passwordless sudo. There
is no SSH service or forwarded debugger port. The guest has 2 CPUs, 4 GiB RAM,
and a persistent 16 GiB virtual disk. `SHARED_DIR` appears at `/tmp/shared` in the
guest and is writable from both sides. Copy a sample into the guest home before
working, and copy reports back into the exchange directory. If host file
ownership prevents a guest copy, use sudo for that copy. Move final deliverables
from `tmp/vm-share` into `artifacts/<identifier>/` on the host.

Do not point `SHARED_DIR` at the repo or home directory. The runner also exposes
the host Nix store read-only, plus its temporary exchange directories. The VM
restricts guest-initiated networking using QEMU user networking; it is intended
for local analysis, with no outbound package downloads. It is not a hardened
malware sandbox. The normal `nix develop` workflow and network-dependent Nix
builds belong on the host or a separately configured Linux machine.

Run QEMU and GDB together **inside** the VM, following the
[Linux RE skill](../.claude/skills/linux/SKILL.md). qemu-user needs matching target
loaders/libraries for dynamic ELF files; the VM's native libraries are not a
sysroot for every foreign ABI.

Shut down with `sudo poweroff`. QEMU's serial-console escape is Ctrl-a then x
for forced termination. The disk persists at `tmp/analysis-vm/disk.qcow2`; use a
new disk filename for a fresh guest, particularly after changing VM configuration.

## Validate

On a Linux build host, run the cross-architecture debugging check independently:

```sh
nix build .#checks.x86_64-linux.debug-smoke  # aarch64-linux on ARM Linux
cat result/result.txt
```

This uses a static RISC-V executable and verifies remote debugging without a
downloaded sample/rootfs. On macOS, it can be built with a configured Linux
builder by selecting the corresponding Linux check explicitly. VM booting and
physical debug probe access require separate runtime verification.
