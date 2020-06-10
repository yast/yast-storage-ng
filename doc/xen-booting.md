# Booting a XEN guest

According to the [guest boot
process](https://wiki.xen.org/wiki/Booting_Overview), a BIOS Boot Partition is
not needed to boot a XEN domU (the guest) unless using Grub2 for booting its own
kernel instead of the one provided by the XEN dom0 (the host).

Since the boot process for a XEN domU is defined in its configuration file, it's
not possible to know it during the installation. For that reason, although the
partitioner still proposing the BIOS Boot partition when possible, it will not
warn the user when it is missing in a XEN guest.

For its part, AutoYaST will [keep trying to add a boot
device](https://github.com/yast/yast-storage-ng/blob/af944283d0fd2220973c8d51452365c040d684ba/doc/autoyast.md#phase-six-adding-boot-devices-if-needed).,
which is not a problem because such attempt is just complementary and the
installation will continue regardless of whether it succeeds or not.
