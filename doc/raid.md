# RAID setups - what works?

## General considerations

- All tests were run with tw-20180925 + libstorage-ng-4.1.37, yast2-storage-ng-4.1.19.

- Not checked: How much stacking of multipath+raid+enc+lvm is allowed for /boot?

## Terminology

- raid1: raid level 1 with metadata format <= 1.0 (metadata at the end of the device)

- raidX: any raid with any metadata format

- bootloader_partition: partition containing the initial part of the bootloader (loaded by the system's firmware)

    - x86, gpt: bios_grub partition

    - x86, msdos: mbr gap (free space before the 1st partition)

    - efi (x86, aarch64): esp (efi system partition)

    - ppc64 (gpt, msdos): prep partition

- not working setups or strange issues are marked with an ✘

## Results

- raid1 over full disk, partitioned, bootloader_partition on this disk

    - non-efi: works, grub_installdevice contains N physical disks (constituting the raid1)

    - ✘ non-efi: pointing grub_installdevice to the raid1 device directly results in this error:
      ```sh
      grub2-install: error: diskfilter writes are not supported.
      ```

    - ✘ x86, msdos: wrong warning about missing bios_grub partition

    - ✘ efi: (incorrect) warning about esp on software raid; the warning is (a) wrong as grub2
      doesn't support this setup (see below) - so it's an error atm and (b) again wrong as
      **if** grub2 would be fixed this should work fine; note that this is different from the
      seemingly similar case in 'raidX over partitions' below

    - ✘ efi: not working; `shim-install --config-file=/boot/grub2/grub.cfg` fails with
      ```sh
      Standard output: copying /usr/lib64/efi/grub.efi to /boot/efi/EFI/opensuse/grub.efi
      Error output: Installing for x86_64-efi platform.
      Error output: Installation finished. No error reported.
      Error output: invalid numeric value
      Error output:
      Status: 37
      ```

    - ✘ efi: the above error results in no boot manager entry (in firmware) being created
      (because the raid device is unknown to the firmware)

- raidX over partitions, /boot on raidX, bootloader_partition not on raid

    - works, grub_installdevice contains N physical disks (constituting the raidX)

    - efi: we use only one esp; in theory, grub2-install has an `--efi-directory` option so
      more than one esp could be supported (as in the non-efi case)

    - ✘ non-efi: currently yast-bootloader expects a bootloader_partition
      on every disk constituting the raidX; either add a check for this in
      the partitioner or change yast-bootloader to only install on those that have
      it (add a check that there is at least 1)

- raidX over partitions, /boot on raidX, bootloader_partition on raid1

    - efi: works, grub2-install creates N firmware bootloader entries (constituting the raid1)

    - ✘ efi: the raid setup enforces partition type linux_raid for the esp; it seems to be ok (strictly
      type esp would be required); we do it this way since at least sle12;
      see [fate\#314829](https://fate.suse.com/314829) and
      [bsc\#1024409](https://bugzilla.suse.com/1024409)

    - ✘ efi: (incorrect?) warning about esp on software raid; there's the partition type issue
      mentioned above - maybe the warning could be more specific?

    - ✘ non-efi: bootloader_partition could theoretically be on raid1 but this is not advisable;
      you would have to force the partition type from linux_raid to bios_grub/prep (not
      possible in partitioner; plus this might run into isses with raid management) - and
      there's really no advantage over using several partitions directly

- raidX over full disk, unpartitioned, /boot directly on this raid (not in a partition)

    - ✘ does not work: bootloader_partition needs to be on a separate disk; yast-bootloader
      tries to install grub2 on the disks constituting the raid and fails

- bios raid (= raidX over full disk, partitioned)

    - in theory, should be treated like the 'raidX over full disk, partitioned' case above

    - ✘ in theory, raid is firmware readable and grub2 should be installable
      into the raid directly; but this would run into the 'diskfilter
      writes are not supported' issue described above

    - ✘ the [Dell PowerEdge S140](https://topics-cdn.dell.com/pdf/poweredge-rc-s140_users-guide_en-us.pdf)
      user manual specifically mentions to use raid level 1 for bootable devices on linux

- s390x

    - keep zipl on plain partition

    - with raidX setups using several zipl partitions would be possible via
      the `--zipl-directory` option of grub2-install (similar to the efi case)
