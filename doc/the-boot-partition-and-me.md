## What is the boot partition used for and why would I need one?


> #### Notes
> - In this document only file systems supported by `storage-ng` are considered: btrfs, extX (ext2, ext3, ext4), xfs.
> - With 'boot partition' a partition mounted at `/boot` (or containing the `/boot` directory directly) is meant.
>   It is not to be confused with the BIOS GRUB partition, EFI System Partition, or PReP partition.
> - While this document is basically valid for all architectures (points 1 and 3 in the below list) the focus here is on clarifying the situation
>   on x86 with legacy BIOS and msdos partition table.

A boot partition is used for three different purposes

1. to hold kernel and initrd using a file system that can be read by grub
2. to install grub into
3. to hold the grub environment block (accessible as `/boot/grub2/grubenv` in the file system)

There are different file system requirements for each use case

1. extX, xfs, btrfs
2. extX, btrfs
3. readable in grub: extX, xfs, btrfs; writable in grub: extX, xfs

So if you ever need a boot partition, extX would be the file system of choice.

Let's get into detail.

### 1. To hold kernel and initrd

This would be needed in a complex setup where grub otherwise would not be
able to read the kernel. As grub supports basically everything the only
reason left would be to avoid entering the decryption key in grub for an
encrypted boot partition.

### 2. To install grub into

On x86 with a legacy BIOS setup and using a msdos partition table grub
would normally be installed into free space before the first partition ('mbr gap').

But if the mbr gap is too small grub can alternatively be installed into the
boot partition and a generic boot loader be put into the mbr to chainload
grub from the boot partition.

This is a setup discouraged by grub as this embedding of grub into a file
system via block maps has the drawback that if the grub image files are
inadvertently moved this would invalidate the block map and break
grub until `grub2-install` is re-run.

The mbr gap is considered large enough by `storage-ng` if it's at least
256 KiB. This limit cannot be given exactly as it depends on the number of modules
grub needs to boot (lvm, raid, encryption, file systems, ...).

The chosen value is comfortably larger than the current real grub
requirements (around 100 KiB) and much smaller than typical real mbr gap
values of 1 MiB. Only older disks might have been partitioned with the obsolete
chs (cylinder) layout in mind and only reserved one track (31.5 KiB) - which is too small for
our purposes and is caught by our limit.

### 3. To hold the grub environment block

The [grub environment block](https://www.gnu.org/software/grub/manual/grub/grub.html#Environment-block)
is a 1 KiB block reserved to store environment
variables to be read and written by grub during the boot process. The block
is visible as `/boot/grub2/grubenv` in the file system but should be
accessed only via the `grub2-editenv` command.

Entries can be read and written with `load_env` and `save_env` from grub. The catch
here is that it can basically always be read but writing is limited to a few file systems
as grub just does not want to get into trouble accidentally destroying data. Also, writing is
not supported via lvm, raid, and encryption modules.

The main usage of this block is `grub2-once` that sets a `next_entry`
variable (boot entry to be used for the next boot). This variable is unset
during the next boot by systemd in `grub2-once.service`.

`save_env` is **not** used for this and we can live fine with a setup that
does not allow writing the environment block from grub.

### Conclusion

A boot partition is not needed unless the mbr gap is too small. Because

- we consciously live with the fact that you have to enter the decryption key in grub
- write access in grub to the environment block is not needed in a typical setup
