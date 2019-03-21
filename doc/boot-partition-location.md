## Boot loader partitions in the Guided Proposal

This document describes the locations of the separate `/boot` partition (if needed) and
the boot loader partition (ESP, grub2 or zipl) the Guided Proposal assumes.

This does not imply that it is technically required to follow the Guided
Proposal. Users can in fact use the Expert Partitioner to do as they please
(but may get warnings).

### The `/boot` partition

The proposal will always create the `/boot` partition (if one is needed) on
the disk containing the root ('/') file system.

It will never use an existing one.

### Boot loader partition (ESP, grub2, zipl)

The boot loader is usually installed into its own partition. Except on
x86-legacy with msdos partition table that uses the mbr gap.

This means

- BIOS GRUB partition (x86-legacy, GPT partition table)
- EFI System Partition (EFI systems: x86, aarch64)
- PReP (ppc)
- ZIPL partition (s390)

These partitions are expected to be on the boot disk (disk containing the
`/boot` file system). Note that this is identical to the disk containing the
root file system (see previous chapter) as far as the Guided Proposal is
concerned.

An existing suitable partition will be reused. If none is found a new one
is proposed on the boot disk.

### Rationale

The goal here is to keep the core operating system on a single disk if at
all possible. Having the boot loader elsewhere would be technically possible
but is impractical.

#### Pro

Experience shows that setups with operating system and boot loader on
different disks tend to run into trouble as identifying the correct disk is
a weak spot in boot loaders.

Also, there might be unwanted interaction with other operating systems
installed on the same machine.

And, finally, the user might take 'the operating system disk' to another
machine and have good chances it will simply 'just work'.

ESPs could be shared but as they typically are of limited size having you
'own' ESP looks better.

#### Con

There is the rumor that Windows expects a single ESP for the whole system.
The impact would be that you run into difficulties configuring grub to be
added to the Windows loader in a multi boot setup.
