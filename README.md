# linux-fixes

*AI-generated (Claude, Anthropic) together with the maintainer; tested on one Jet75-II (firmware V116) on
Linux 6.18 only. Use at your own risk and report problems via issues.*

Linux fixes for MCHOSE magnetic (Hall-effect) keyboards. Nothing here is written to the keyboard: the fix
changes how the kernel reads the keyboard's USB descriptor, and removing it restores the original state.

| Part | What it does |
|---|---|
| `nkro-fix/` | **HID-BPF fix for the broken NKRO descriptor**: makes Snap Tap / SOCD, macros and more than 6 simultaneous keys work |
| `udev/70-mchose-hidraw.rules` | Lets the logged-in user (and the `plugdev` group) use the keyboard's raw HID interfaces, so configuration tools run without root |
| `udev/71-mchose-nkro-fix.rules` | Attaches the fix automatically whenever the keyboard is plugged in |
| `systemd/` | Optional boot-time service, a fallback for the udev rule |

## The problem

The keyboard's NKRO report (interface 2, report ID 1, a 120-bit bitmap) is declared `Input(Data,Array)`
instead of `Input(Data,Variable)`. Linux reads the set bits as "ErrorRollOver" and drops them. The
firmware sends some keys **only** through this report, so on an unpatched system:

- **Snap Tap / SOCD keys never arrive**;
- **macros type nothing** (only their modifiers arrive);
- **keys beyond the first six held at once are lost**.

All Jet75-II firmware versions known (V111–V116) have this bug. Windows is not affected in practice: macros and
Snap Tap were reported working there without a fix. Details:
[known issues](https://open-he-mchose.github.io/keyboards/jet75-ii/known-issues/).

Measured on a Jet75-II with the fix (Linux): Snap Tap A/D produced 366 key events instead of 0, never
both down; up to 19 keys held at once were reported instead of 6; all test macros typed correctly.

## Which keyboards

The fix attaches to any device with USB vendor ID `0x41E4` whose report descriptor starts **byte for byte**
with the known broken layout, and changes exactly one byte. Other devices are left alone.

| Keyboard | Status |
|---|---|
| Jet75-II, firmware V116 | **verified** |
| Jet75-II, V111–V115 | same descriptor (firmware analysis) |
| Ace 60 Pro v1.07 | same descriptor (firmware analysis), not tested |
| other MCHOSE models | patched only if their descriptor is identical; reports welcome |

`mchose-nkro-fix status` shows whether a connected keyboard was recognised.

## Requirements

- Linux with HID-BPF as `struct_ops` (`CONFIG_HID_BPF=y`, Linux 6.11 or newer) and BTF
  (`/sys/kernel/btf/vmlinux`). Most current distribution kernels have both.
- Build tools: `make`, `clang`, `bpftool`, libbpf headers, a C compiler.

| Distribution | Packages |
|---|---|
| Arch | `clang bpf libbpf` |
| Debian / Ubuntu | `clang bpftool libbpf-dev make` (`bpftool` may be in `linux-tools-common` / `linux-tools-$(uname -r)` on Ubuntu) |
| Fedora | `clang bpftool libbpf-devel make` |
| Void | `clang bpftool libbpf-devel make` |

## Install

```sh
make                      # as a normal user
sudo make install         # installs to /usr/local/sbin and /etc/udev/rules.d, reloads udev, attaches the fix
mchose-nkro-fix status    # should say FIXED
```

On systemd distributions you can add a boot-time fallback in case the udev rule does not fire early
enough:

```sh
sudo make install-systemd
```

On other init systems, add `/usr/local/sbin/mchose-nkro-fix load` to a boot script that runs after udev,
for example `/etc/rc.local` (Void runs it at the start of stage 2).

### Check that it works

- `mchose-nkro-fix status` — descriptor state, pinned BPF link, installed files and the last log lines.
- `mchose-nkro-fix log` — every load / unload run since boot (`/run/mchose-nkro-fix.log`), including runs
  started by udev. If the fix is missing after a reboot, this log shows why.
- With `evtest`, hold more than six keys: all of them should be reported.

### Uninstall

```sh
sudo make uninstall       # removes the files and restores the original descriptor
```

Upgrading from the earlier Jet75-only version (`jet75-hid-fix`): `sudo make install` removes its files. A
link it attached stays active until the keyboard is unplugged and is shown by `status`.

## ⚠️ Before you install

With the fix, **settings that silently did nothing start working**. Check all profiles for forgotten
Snap Tap / SOCD bindings and macros, for example with the official driver, before relying on the keyboard
in games.

## How it works

`nkro-fix/mchose_nkro_fix.bpf.c` is a HID-BPF `hid_rdesc_fixup` program. When the kernel probes the
keyboard's interface 2, the program checks the first 24 descriptor bytes and changes byte 23 from `0x00`
to `0x02`. The loader attaches it to one HID device and pins the link under `/sys/fs/bpf/mchose-nkro-fix/`.
Deleting the pin (`mchose-nkro-fix unload`) or unplugging the keyboard removes it. The udev rule runs the
loader again on every plug-in.

A firmware update from MCHOSE that declares the report correctly would make this fix unnecessary.
Windows and macOS have no comparable user-side fix.

## License

- `nkro-fix/mchose_nkro_fix.bpf.c` and `nkro-fix/loader.c`: GPL-2.0-only (the kernel requires a
  GPL-compatible licence for HID-BPF programs), see `LICENSES/GPL-2.0-only.txt`.
- Everything else: MIT, see `LICENSE`.

Part of [open-he-mchose](https://github.com/open-he-mchose): unofficial documentation and tools for MCHOSE
magnetic keyboards. Not affiliated with MCHOSE.
