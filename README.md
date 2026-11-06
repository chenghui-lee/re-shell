# re-shell

A Nix flake-based reverse engineering environment designed for use with [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drop in a binary, capture, or archive and ask Claude to analyze it -- the right tools and context activate automatically.

## Quick start

Make sure `flakes` and `nix-command` experimental features are on. If not, add to your nix config file:

```sh
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
```

```sh
# Enter the environment (or use direnv)
nix develop

# Drop a file into the repo root and start Claude Code
cp ~/Downloads/suspicious.exe .
claude

# Then just ask:
#   "Reverse engineer suspicious.exe"
#   "Decompile this APK and find hardcoded API keys"
#   "Analyze this HAR file for undocumented API endpoints"
```

## How it works

The environment bundles a full reverse engineering toolchain (Ghidra, radare2, Frida, mitmproxy, YARA, and more) into a reproducible Nix dev shell. Claude Code is configured via `CLAUDE.md` with discipline-specific **skills** that auto-activate based on file type and context:

| Skill | Activates on | Example files |
|-------|-------------|---------------|
| Windows RE | PE binaries, .NET assemblies, drivers | `.exe`, `.dll`, `.sys` |
| Linux RE | ELF binaries, core dumps, embedded Linux executables | ELF, `core` |
| Android RE | Android packages, DEX bytecode | `.apk`, `.xapk` |
| Web RE | HTTP captures, API traffic, protobufs | `.har`, `.proto` |

## Debugging and emulation

Linux shells include multi-architecture GDB, qemu-user, and strace. Darwin shells
include an `lldb` wrapper for Apple's native Mach-O debugger (requires Xcode or
Command Line Tools). OpenOCD is available on both for
JTAG/SWD debugging. Use `nix shell .#debug-tools` for just these debugger tools
without the full static/Android toolchain. See the [Linux RE skill](.claude/skills/linux/SKILL.md) for
ELF triage, target sysroots, QEMU/GDB, PIE addresses, core dumps, and tracing;
see [CLAUDE.md](CLAUDE.md#debuggers-and-hardware-debugging) for LLDB and OpenOCD.

qemu-user runs foreign Linux processes on a Linux host. On macOS, use the
[NixOS analysis VM](docs/analysis-vm.md), which provides the Linux runtime tools
from the same nixpkgs pin:

```sh
# On Darwin, configure a same-architecture Linux builder first (see VM guide).
nix build .#analysis-vm
mkdir -p tmp/vm-share tmp/analysis-vm
SHARED_DIR="$PWD/tmp/vm-share" NIX_DISK_IMAGE="$PWD/tmp/analysis-vm/disk.qcow2" \
  ./result/bin/run-re-analysis-vm
```

The VM logs into a local `analyst` console, shares only the selected exchange
folder at `/tmp/shared`, and restricts guest-initiated networking. It is a
focused runtime environment; the full static toolchain remains in `nix develop`.

On Linux, verify foreign execution and debugging with:

```sh
# Substitute aarch64-linux on ARM Linux.
nix build .#checks.x86_64-linux.debug-smoke
cat result/result.txt
```

This check assembles a static RISC-V ELF, runs it under QEMU, connects GDB,
checks a breakpoint and register value, and verifies a successful exit.
`nix flake check` also runs it on Linux, alongside formatting.

When Claude detects relevant context, the matching skill loads specialized tool documentation and workflows -- no manual configuration needed.

## Adding tools

The environment is self-modifying. If an analysis needs a tool that isn't installed, Claude can add it:

- **Python packages:** `uv add <pkg>` then `direnv reload`
- **Node.js packages:** `npm install <pkg>` then `direnv reload`
- **System tools:** add to `flake.nix` then `direnv reload`

## Output directories

- **`tmp/`** -- Intermediate work products (gitignored)
- **`artifacts/`** -- Final deliverables like reports and analysis notes (gitignored)
