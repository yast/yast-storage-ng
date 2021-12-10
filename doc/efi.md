# UEFI firmware handling

A lot of modern systems use UEFI firmware for booting. On x86_64 systems this
is optional; on aarch64 or riscv64 this is the standard way for booting.

The interface to the firmware is exposed via files in
`/sys/firmware/efivars` - which (may) represent settings in the system's NVRAM.

From the installer's perspective the main difference is whether these
settings are writable or not. If they are, `efibootmgr` can be used to create or modify boot entries.

## Detecting UEFI capabilities

1. UEFI is supported in general if the directory `/sys/firmware/efivars` exists

2. UEFI settings can be changed (and `efibootmgr` be used) if
    1. the directory `/sys/firmware/efivars` is writable and
    2. not empty

Particularly for embedded systems, 2. is typically not the case.

Use `Y2Storage::Arch#efiboot?` for 1. and `Y2Storage::Arch#efibootmgr?` for 2.

## Overriding UEFI detection

There are two equivalent ways to override the detection to assume the system **is** UEFI capable:

1. set the `LIBSTORAGE_EFI` environment variable to `yes` or
2. (during installation) set the boot option `efi` to `1`

To override the detection to assume the system **is not** UEFI capable:

1. set the `LIBSTORAGE_EFI` environment variable to anything but `yes`
2. (during installation) set the boot option `efi` to `0`

## On x86_64: legacy vs. UEFI booting

### 1. Enforce legacy booting

If you boot via UEFI but want to install a system that is expected to boot
via legacy BIOS, install with boot option`efi=0`.

### 2. Enforce UEFI booting

If you boot via legacy BIOS but want to install a system that is expected to
boot via UEFI, install with boot option `efi=1`.

Since `efibootmgr` cannot be used to create boot entries, this will install
the boot loader in a way that it can be found via UEFI's fallback boot path
(basically, looking for `/EFI/BOOT/BOOT<ARCH>.EFI` on a VFAT partition).

After rebooting via UEFI, the boot config can be adjusted and the missing boot
entries be created by running `pbl --install`.
