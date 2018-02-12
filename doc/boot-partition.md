Boot Partition Layout / Restrictions For Storage Proposal
=========================================================

[Revision 2018-02-12]

#### Notes:

- outright uncertain issues are tagged with '???', please try to clear them up
- partition sizes are given as triples: [minimal, optimal, maximal]

### Relevant bugs during SLE15 beta phase

- In [bsc#1068772](https://bugzilla.suse.com/show_bug.cgi?id=1068772) and
  [bsc#1076851](https://bugzilla.suse.com/show_bug.cgi?id=1076851) it has been
  pointed that the PReP partition likely MUST be the first partition in the
  disk.
- In [bsc#1073680](https://bugzilla.suse.com/show_bug.cgi?id=1073680) the
  reporter points that `/boot/efi` should be also the first partition in the
  disk to please some buggy EFI implementations.
- At the time of writing, there is nothing implemented in the proposal to ensure
  a given partition is located at the beginning of its disk.

### Grub2 and disk abstractions

- Grub natively suppors lvm raid 0/1/4/5/6, encryption with or without lvm
- The problem with disk abstractions like lvm or raid is not exactly about
  booting. The system will boot fine but some features have an additional
  requirement - having a pre-boot environment block writable by grub-once.
  Without that, the following functions will not work reliably ("reliably"
  is the key word here)
  * 1. bootcycle detection
  * 2. resume from hibernation image 
  * 3. kde start menu could "boot once the selected entry directly"
- We actually carried patches to workaround #2 #3, but in some cases it
 may still fail.
- So far the solution has been to use a separate `/boot` partition. With our
  current approach to Grub2, that's the only way.
- Michael Chang suggested a different approach, placing `/boot/grub2/grubenv` in
  a raw system sector that is writable by grub-once. That sector can be in the
  EFI partition, in a bios_grub partition or in the MBR gap (provided the gap is
  big enough to host both grub and the pre-boot environment block).
- Michael Chang said that for yast-storage-ng we can assume the described new
  approach will be available. It will be for sure ready in time for SLE12-SP3.
- note: encryption password will be queried twice without separate `/boot` (grub
  doesn't pass on the password to user space)
- `/boot` partition (for cases in which is still needed)
 * grub config + stage2 in arch specific subdir
 * kernel, firmware, initrd
 * size: [100MB, 200MB, 500MB]
- ideal partition order: /boot, swap, /

### x86-legacy

- dos/gpt, default: gpt
- install all grub parts onto a single disk (not spread over several disks), use the disk on which we install the system
- user is responsible to make the BIOS boot from this disk
- ??? 2 variants (which one will we use):
- **(A)**
 * generic boot loader installed into mbr
 * we have generic boot code for both dos/gpt partition table
 * stage1 installed into /boot or / partition (if possible, note: not on xfs)
 * **OR** separate grub boot partition for embdding stage1 (like prep on ppc)

     > *[mchang]* gpt has bios_grub partition but only if you instruct grub2-install to
install stage1 on mbr then it will search bios_grub to embed stage2
(core.img) on it. It seems to contradict with 'generic boot loader
installed into mbr' because it's required place to put grub2 stage1 if
we want to use grub2-install.

 * partition with stage1 must be plain (no lvm, raid, encryption) and be flagged as bootable (active)
 * note: with dos partition table, one primary partition must be flagged as bootable (active)
- **(B)**
 * grub installed into mbr
 * stage1 embedded after partition table, provided there is enough space (about 64k should be ok) - usually there is, as partitions are 1MB-aligned
 * **OR** separate grub boot partition for embedding stage1 (like prep on ppc)

     > *[mchang]* Therefore I support for plan (B), and also upstream recommends mbr with
embedded core.img in a partition or mbr gap. It is also to prevent from
using static block lists to read core.img in file system, as it's
fragile and file system dependent.

 * partition with stage1 must be plain (no lvm, raid, encryption)
 * even if technicaly not needed, exactly one (any) primary partition must be flagged as bootable, else some BIOSes will complain
- grub boot partition size: [64k, 1MB, Inf]
- co-existence with other Linux systems problematic if grub boot partition is shared with them
- ideally grub stage1 + stage2 + /boot below 2TB

     > *[mchang]* To be on safe side, yes. But I think stage1 should be able to reach
stage2 beyond 2 TB limit when using gpt table.


### x86-efi

- gpt
- efi system partition
 * dos type 0xef, gpt type c12a7328-f81f-11d2-ba4b-00a0c93ec93b 
 * fat32, size: [33MB, 200MB, Inf]
 * will be mounted at /boot/efi
 * may be shared with other systems (re-use existing one)
 * contains shim and grub stage1 + basic config + basic stage2 (real config and full stage2 on /boot) in EFI/{boot,<product>} subdir

### s390x

- ??? dos/gpt - something else?

    > [hare] dos/gpt is only used for zfcp and FBA DASD

    >> [mpost] FBA (and it's cousin DIAG) DASD are "special" because of a design decision IBM made way back in the early days.  The dasd_fba_mod driver fakes a partition table which does not actually exist on the disk.  That fake partition table contains a single partition spanning the whole disk.  It was a really bad choice which has caused more than its share of problems over the years.  (For some reason, people think they should be able to modify the partition table to do what they want.  Who would ever have imagined that?)  This is the reason why the tools that IBM created, dasdfmt and fdasd, refuse to work on FBA, DIAG, or LDL formatted disks.  For me, this means that we should refuse to do much with any of these types of devices other than put file systems/swap signatures on them.  Well, making LVM PVs out of them will also work as long as the partition is used and not the whole device

- DASD - ??? up to 4 (3?) partitions

	> [hare] ECKD DASD is using either
	> CDL (Compatible Disk Layout)
	> which is written by tools like 'fdasd'; supports up to 4 partitions.

	> or

	> LDL (Linux Disk Layout)
	> which is the assumed disk layout (1 partition,
	> spanning the entire disk) if nothing can be detected on that disk.
	> LDL is strongly deprecated and only mentioned here for completeness.

- kvm

	> [hare] KVM does _not_ use DASD emulations, but rather virtio disks.
	> So for KVM you'll be seeing /dev/vdaX instead of /dev/dasdX

- zipl partition
 * mounted at /boot/zipl
 * ext2
 * ??? size [100MB, ?, Inf] (enough for 2 kernel/initrd copies)

	> [hare] No size limitations, can be any DASD or zfcp partition.

 * ??? why has /boot/zipl a copy of kernel+initrd, isn't /boot on same disk enough to get a block map

	> [hare] That's due to the 'peculiar' boot setup.
There is no native grub2 implementation for zSeries, rather we
use zipl/zfcp to boot up a kernel & grub2 shell, which then
loads the 'real' kernel.
So initially we'll end up with two identical kernels, but this might change during a kernel
update.

    >> [ihno] No. It is due to the requirement to have btrfs as the root filesystem
zipl has a lilo like boot mechanism and btrfs may relocate blocks.
So we need a filesystem which can be booted by zipl (-> ext2).
   >>> [mpost] Oh, you're both right.

   >> The next requirement was to have grub2 as a bootloader.
   >> The kernel in /boot/zipl is only updated if it is needed for the boot process.

   >>> [mpost] To be clear, what's in /boot/zipl only gets updated when grub2-install, etc. are run.
   >>> Since it's only task is to get the kernel up and grub2 examining what's in /boot it hopefully doesn't change very often.
   >>>  The exception to this is /boot/zip/active_devices.txt which gets updated whenever ctc_configure, dasd_configure, qeth_configure, zfcp_host_configure add or remove devices from the system.


### ppc64

- dos/gpt

- KVM/LPAR

- prep partition, if dos partition table, flag as bootable (active)
 * dos type 0x41, gpt type 9e1a2d38-c612-4316-aa26-8b49521e5a8b
 * used to embed grub2 stage1 + basic stage2 (slightly below 256k, atm)
 * size [256k, 1MB, 8MB]
- prep partition must be on same disk we install the system ([bsc \#970152](https://bugzilla.suse.com/show_bug.cgi?id=970152))

> dvaleev: 8 MB PReP

> dvaleev: PReP must be one of the first 4 partitions, ideally the first one [citation needed]

- OPAL/PowerNV/Bare metal

> dvaleev:
> OPAL/PowerNV/Bare metal (PowerNV in /proc/cpuinfo)
>        no PReP is required. There is no stage1, grub2-mkconfig is sufficient.
>        Firmware itself just creates a bootmenu based on grub2.cfg parse.
>        no grub2-install


### aarch64

- gpt
- efi system partition, cf. **x86-efi**


Summary
=======

## General

- boot loader, /boot (/boot/zipl) and / should be on same disk
- order: /boot, swap, /

valid for all architectures, except s390 (see below)

- when using gpt, never use gpt-sync-mbr / hybrid mbr; only standard protective mbr.
- Only create a `/boot` partition when both conditions are met:
 * Using raid, encrytpted LVM, LVM
 * There is no EFI, bios_grub or big-enough MBR gap
- When creating a `/boot` partition:
 * size: [100MB, 200MB, 500MB]
 * ext4

Note: boot loader is grub2 (refered as grub in this document)

## x86-legacy

*[this assumes grub will be installed into mbr]*

- required size for grub embedding (currently): 84 kB; to be safe, check for >= 256 kB
- required size for grubenv (currently): 1 kB
- if dos partition table
    - embed in unused space before 1st partition (mbr gap)
    - fail if not enough space
    - note: grub-install may later fail if it detects the area is used by some other weird software
- if gpt partition table
    - BIOS boot partition must exist (gpt type 21686148-6449-6e6f-744e-656564454649); parted: set flag `bios_grub` to `on`
    - if it doesn't exist, create:
        - size: [1MB, 2MB, 100MB]
        - no fs
        - no mount point
    - if existing BIOS boot partition is too small, ~~delete and re-create~~ cross your fingers
    - grub will use 1st BIOS boot partition it finds, co-op with other grub instances on same disk not possible
- note: `yast bootloader` will be responsible for boot flag handling, if necessary
    - ensure exactly one partition entry (for gpt: in protective mbr) is tagged as `active`

## x86-efi

- efi system partition required; dos type 0xef, gpt type c12a7328-f81f-11d2-ba4b-00a0c93ec93b
- reuse existing partition
- if it doesn't exist, create:
    - size: [33MB, 200MB, 1GB]
    - fat32
    - mount at /boot/efi
- if existing efi system partition is too small, ~~delete and re-create~~ cross your fingers

## ppc

KVM/LPAR
- PReP partition
   - dos type 0x41, flag as bootable
   - gpt type 9e1a2d38-c612-4316-aa26-8b49521e5a8b
   - must be one of the first 4 partitions (we have no evidence of this)

OPAL/PowerNV/Bare metal
- no PReP is required

## s390x/zSeries (64 bit)

- any DASD or zfcp partition, **except** LDL, FBA and DIAG formatted disks
- from SLES12 on 'zipl' is used:
    - create /boot/zipl (just a regular linux partition)
    - ext2 (has to be booted by zipl)
    - size: [100 MB, 200 MB, 1GB]
- no /boot partition is required
- partitioning on DASD: minor number 0 is for complete disk, 1 - 3 are for partitions (only 2 bit available)

AI Ihno:

- provide a script to detect DASD type (FBA, DIAG...), is it allowed to create a partition table?

## aarch64 (Raspberry Pi 3)

- see also fate #323484, bsc #1041475

- RPi boots from sdcard, must have a msdos partition table

- first, a firmware blob is read; this has to be on a dedicated
  vfat partition that must not be deleted, this partition need not be the
  first partition

- the partition type of this partition is fixed (0xc?)

- this firmware then loads a bootloader (u-boot)

- u-boot then does the typical UEFI boot procedure (loading grub2, etc)

- EFI system partition (ESP) must be marked as active

- the special RPi partition contains some firmware blob (file name?),
  u-boot, and a lot of RPi config files

- the special RPi partition could be treated very similar to PReP on ppc

- apart from this, it's a typical UEFI setup (with separate ESP) but with
  msdos partition table on the sdcard (there's no restriction for the usb
  disk) and ESP must be marked as active

- installation can be via network or from usb-stick, selectable in u-boot (somehow?)

# Summary of discussion

[2016-03-23]

- provide information about /boot, PReP... for yast-bootloader
  -> stored in/available from BootRequirementsChecker
- DiskAnalyzer to be run before checking boot requirements to have info about existing partitions
  -> param for BootRequirementsChecker

## External References

- [UEFI Spec Version 2.6](http://www.uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf)
- [Microsoft EFI FAT32 Spec](http://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/fatgen103.doc)
- [CHRP Revision 1.7](https://stuff.mit.edu/afs/sipb/contrib/doc/specs/protocol/chrp/chrp1_7a.pdf)
- [LoPAPR - Linux on Power Architecture Platform Reference](https://members.openpowerfoundation.org/document/dl/469)
- [PowerLinux Boot howto](https://www.ibm.com/developerworks/community/wikis/home?lang=en#!/wiki/W51a7ffcf4dfd_4b40_9d82_446ebc23c550/page/PowerLinux%20Boot%20howto)
- [SLOF - Slimline Open Firmware](https://github.com/aik/SLOF/blob/master/slof/fs/packages/disk-label.fs)
- [GRUB Documentation](https://www.gnu.org/software/grub/grub-documentation.html)
- [GRUB wikipedia](https://de.wikipedia.org/wiki/Grand_Unified_Bootloader)
- [U-Boot](http://elinux.org/RPi_U-Boot)
- [Raspberry Pi boot modes](https://github.com/raspberrypi/documentation/tree/master/hardware/raspberrypi/bootmodes)

## Internal Documentation

- [YaST2 libstorage](https://github.com/openSUSE/libstorage/blob/master/doc/yast-storage-requirements.md)
- [StorageNG meeting](https://etherpad.nue.suse.com/p/StorageNG-20160210)
- [libstorage-booting](https://etherpad.nue.suse.com/p/new-libstorage-booting)

