# Booting a XEN guest

According to the [guest boot
process](https://wiki.xen.org/wiki/Booting_Overview), it is not needed a BIOS
Boot Partition to boot a `XEN domU` (_the guest_) unless using Grub2 for booting
its own kernel instead of the one provided by the `XEN dom0` (_the host_).

However, taking into account that

* it is not possible to know in advance which kind of boot the guest will use,
  and
* the boot process is defined in the XEN domU configuration file, which could be
  changed at any time

the partitioner still proposing, if possible, the BIOS Boot partition even when
running a XEN installation. On the other hand, it does not warn the user about a
missing partition if it is not present.

For its part, AutoYaST [keep trying on adding a boot
device](https://github.com/yast/yast-storage-ng/blob/af944283d0fd2220973c8d51452365c040d684ba/doc/autoyast.md#phase-six-adding-boot-devices-if-needed).
Fortunately, this is not a problem because that attempt is just complementary
and the installation will continue regardless of whether it succeeds.
