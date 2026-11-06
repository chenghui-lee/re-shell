"""Verify foreign ELF execution, remote breakpoints, registers, and clean exit."""

import pathlib
import subprocess
import sys
import tempfile
import time


def main():
    qemu, gdb, target = sys.argv[1:]
    with tempfile.TemporaryDirectory(prefix="re-debug-", dir=".") as work:
        endpoint = pathlib.Path(work).resolve() / "gdb.sock"
        with subprocess.Popen([qemu, "-g", str(endpoint), target]) as guest:
            try:
                deadline = time.monotonic() + 10
                while not endpoint.exists():
                    if guest.poll() is not None:
                        raise RuntimeError(f"QEMU exited before listening: {guest.returncode}")
                    if time.monotonic() >= deadline:
                        raise TimeoutError("QEMU did not create its GDB socket")
                    time.sleep(0.05)
                commands = [
                    "set pagination off",
                    "set confirm off",
                    f"file {target}",
                    f"target remote {endpoint}",
                    "break checkpoint",
                    "continue",
                    "python assert int(gdb.parse_and_eval('$pc')) == int(gdb.parse_and_eval('&checkpoint'))",
                    "python assert int(gdb.parse_and_eval('$a0')) == 37",
                    "continue",
                    "python assert int(gdb.parse_and_eval('$_exitcode')) == 0",
                ]
                # A command file stops on the first failed assertion/command;
                # later successful commands must not mask an earlier failure.
                script = pathlib.Path(work) / "check.gdb"
                script.write_text("\n".join(commands) + "\n")
                subprocess.run(
                    [gdb, "-nx", "-nh", "-batch", "-x", str(script)],
                    check=True,
                    timeout=30,
                )
                if guest.wait(timeout=5) != 0:
                    raise RuntimeError("QEMU exited unsuccessfully")
                print("PASS: RISC-V ELF, remote breakpoint, a0=37, exit=0")
            finally:
                if guest.poll() is None:
                    guest.terminate()
                    try:
                        guest.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        guest.kill()
                        guest.wait()


if __name__ == "__main__":
    main()
