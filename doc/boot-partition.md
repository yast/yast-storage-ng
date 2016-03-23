# Boot Partition Layout / Restrictions For Storage Proposal

[Revision 2016-03-14]

#### Notes:

- outright uncertain issues are tagged with '???', please try to clear them up
- partition sizes are given as triples: [minimal, optimal, maximal]


### general

- natively supported by grub: lvm raid 0/1/4/5/6, encryption with or without lvm
- ??? propose separate /boot only if technically necessary or if we have lvm,raid,etc

 > *[mchang]* Well, the problem seems to be not about booting the lvm or raid setups as
 grub2 can boot most of them directly. The problem is that both can't
 provide the pre-boot environment blocks that is writable for grub-once
 for which some function accounts to work reliably.
 >
 > 1. bootcycle detection
 > 2. resume from hibernation image 
 > 3. kde start menu could "boot once the selected entry directly"
 >
 > We actually carried patches to workaround #2 #3, but in some cases it
 may still fail. Sadly no solution has been found yet and that makes
 ditching /boot hader than expected.

- note: encryption password will be queried twice without separate /boot (grub doesn't pass on the password to user space)
- /boot partition
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

	> [hare] dos/gpt is only used for zfcp and FBA DASD.

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

	>> [ihno] No. It is due to the requirement to have btrfs as the root filesystem.
zipl has a lilo like boot mechanism and btrfs may relocate blocks.
So we need a filesystem which can be booted by zipl (-> ext2).

	>> The next requirement was to have grub2 as a bootloader.

	>> The kernel in /boot/zipl is only updated if it is needed for the boot process.


### ppc64

- dos/gpt

KVM/LPAR
- prep partition, if dos partition table, flag as bootable (active)
 * dos type 0x41, gpt type 9e1a2d38-c612-4316-aa26-8b49521e5a8b
 * used to embed grub2 stage1 + basic stage2 (slightly below 256k, atm)
 * size [256k, 1MB, 8MB]
- prep partition must be on same disk we install the system ([bsc \#970152](https://bugzilla.suse.com/show_bug.cgi?id=970152))

> dvaleev: 8 MB PReP

OPAL/PowerNV/Bare metal
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
General
=======
i.e. valid for all architectures (s390, see below)

- create a /boot partition on raid, encrytpted LVM, LVM
- size: [100MB, 200MB, 500MB]
- order: /boot, swap, /
- ext4

x86-legacy
----------
- grub boot.img (stage 1) in MBR
- install core.img (stage 1.5) in free space between partition table and 1. partition
- if there isn't enough free space -> create additional partition
- install all grub parts on same disk

x86-efi
-------
if system efi partition is already there -> reuse it
if not create:
- /boot/efi
- fat32
- size: 33 MB, 200MB
- limit: below 2TB

ppc
---
KVM/LPAR
- PreP partition dos type 0x41, flag as bootable
                 gpt type 9e1a2d38-c612-4316-aa26-8b49521e5a8b

OPAL/PowerNV/Bare metal
- no PreP is required

s390
----
- needs clarification


## External References

- [UEFI Spec Version 2.6](http://www.uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf)
- [Microsoft EFI FAT32 Spec](http://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/fatgen103.doc)
- [CHRP Revision 1.7](https://stuff.mit.edu/afs/sipb/contrib/doc/specs/protocol/chrp/chrp1_7a.pdf)
- [PowerLinux Boot howto](https://www.ibm.com/developerworks/community/wikis/home?lang=en#!/wiki/W51a7ffcf4dfd_4b40_9d82_446ebc23c550/page/PowerLinux%20Boot%20howto)
- [SLOF - Slimline Open Firmware](https://github.com/aik/SLOF/blob/master/slof/fs/packages/disk-label.fs)
- [GRUB Documentation](https://www.gnu.org/software/grub/grub-documentation.html)
- [GRUB wikipedia] (https://de.wikipedia.org/wiki/Grand_Unified_Bootloader)

## Internal Documentation

- [YaST2 libstorage](https://github.com/openSUSE/libstorage/blob/master/doc/yast-storage-requirements.md)
- [StorageNG meeting](https://etherpad.nue.suse.com/p/StorageNG-20160210)
- [libstorage-booting](https://etherpad.nue.suse.com/p/new-libstorage-booting)

