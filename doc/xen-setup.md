# Setting up XEN for testing

This document describes how to setup a XEN vm within a QEMU vm to test
special XEN block devices (that are named like partitions but are in fact
disks).

For this document the XEN host (= QEMU guest) system uses Leap 15.0, the XEN guest uses SLE 15. But it
whould work similar with other SUSE releases.

## Preparing the QEMU guest (XEN host) vm

If you already have a Leap 15.0 vm, use it.

Else create a new QEMU vm and install Leap 15.0, but:

- add the Leap online repositories (the DVD image does not have XEN tools)
- select `server` role
- in the software selection, add the `XEN Virtualization Host and tools` pattern

**Note**

> It should be sufficient to add the `xen` and `xen-tools` packages to a standard Leap.

Now reboot the QEMU vm and select `openSUSE Leap 15.0, with Xen hypervisor` at the boot menu.

To communicate with the XEN vm you'll need a bridge device. Create a config like this in your QEMU vm

```sh
vm8101:/etc/sysconfig/network # cat ifcfg-br0
STARTMODE='auto'
BOOTPROTO='dhcp'
BRIDGE='yes'
BRIDGE_PORTS='eth0'
```

and run

```sh
wicked ifup br0
```

## Preparing the XEN guest vm

> All the commands below are run inside the QEMU host vm.

We'll need something to run inside the XEN vm. For this document SLE 15 is used (because it's comparatively small).

Get `SLE-15-Installer-DVD-x86_64-GMC-DVD1.iso` and put it inside the QEMU vm, say as `/data/sle15.iso`

```sh
vm8101:/data # ls -l
total 650240
-rw-r--r-- 1 root root 665845760 Jul 19 14:25 sle15.iso
```

Mount it and extract kernel and initrd

```sh
vm8101:/data # mount -oloop,ro sle15.iso /mnt/
vm8101:/data # cp /mnt/boot/x86_64/loader/{linux,initrd} .
vm8101:/data # ls -l
total 731160
-r--r--r-- 1 root root  75971284 Jul 19 14:26 initrd
-r--r--r-- 1 root root   6885728 Jul 19 14:26 linux
-rw-r--r-- 1 root root 665845760 Jul 19 14:25 sle15.iso
vm8101:/data # umount /mnt
```

You can use real devices or plain files to map into the XEN guest. For our example we'll try both.
Let's get an empty file

```sh
vm8101:/data # dd if=/dev/zero of=disk1 bs=1G count=0 seek=60
```

The QEMU vm has a disk device for tests with two partitions

```sh
vm8101:~ # lsblk /dev/sdb
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sdb      8:16   0  60G  0 disk
|-sdb1   8:17   0   6G  0 part
`-sdb2   8:18   0   6G  0 part
```

A XEN guest vm is defined with a simple config file. For our guest it looks like

```sh
vm8101:/data # cat sle15.cfg
name = "sle15"
type = "pv"
kernel = "/data/linux"
ramdisk = "/data/initrd"
cmdline = "startshell=1 sshd=1 password=xxxxx vnc=1 vncpassword=xxxxxxxx"
memory = 512
vif = [ '' ]
disk = [ '/data/sle15.iso,,xvda,cdrom', '/dev/sdb2,,xvdb', '/data/disk1,,xvdc3' ]
```

This is a paravirtualized guest (full virtualization within another vm is a bit problematic) with
our SLE 15 iso as CD-ROM and two disk devices. One maps `/dev/sdb2` as full disk device to `/dev/xvdb`.
The other maps `/data/disk1` to `/dev/xvdc3`.

Note that you are relatively free to name the device you map to (it doesn't have to start with `xvdc1`, for example).
If the device name ends with a number the guest kernel will not try to read the partition table of the device.

The `vif` line will create a network interface (`eth0`) for us.

There are several options on how to interact with yast during the installation

1. Run yast in ncurses mode. For this use
  ```sh
  cmdline = "startshell=1 sshd=1 password=xxxxx"
  ```

2. Run yast via VNC. For this use
  ```sh
  cmdline = "startshell=1 sshd=1 password=xxxxx vnc=1 vncpassword=xxxxxxxx"
  ```
  Note: the VNC password must be at least 8 chars long.

3. Run yast via SSH. For this use

  ```sh
  cmdline = "startshell=1 ssh=1 password=xxxxx"
  ```

## Starting the XEN guest

Let's get going

```sh
xl create -c /data/sle15.cfg
```

With the config above this gets the installation system up and running and leaves you at a shell prompt

```sh
Starting SSH daemon... ok
IP addresses:
  10.0.2.18
  fec0::216:3eff:fe58:3f40

ATTENTION: Starting shell... (use 'exit' to proceed with installation)
console:vm9650:/ #
```

There you can run yast (option 1. above) repeatedly in ncurses mode.

With option 2. after running `yast`, connect to the VNC server. E.g.:

```sh
vncviewer 10.0.2.18:1
```

With option 3., connect to the XEN guest vm to run the installation

```sh
ssh -X 10.0.2.18
```

and run `yast` there.

The disk layout of our XEN guest looks like this:

```sh
console:vm9650:/ # lsblk -e 7
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
xvda    202:0    0   635M  1 disk
|-xvda1 202:1    0   3.8M  1 part
`-xvda2 202:2    0 630.9M  1 part /var/adm/mount
xvdb    202:16   0     6G  0 disk
xvdc3   202:35   0    60G  0 disk
console:vm9650:/ # cat /sys/block/xvdb/range
16
console:vm9650:/ # cat /sys/block/xvdc3/range
1
```

Note that `parted` works just fine with `/dev/xvdc3`.
And if `/dev/xvdc3` happens to contain a partition table (here it does) you can run `kpartx` to access them

```sh
console:vm9650:/ # kpartx -a /dev/xvdc3
console:vm9650:/ # lsblk -e 7
NAME      MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
xvda      202:0    0   635M  1 disk
|-xvda1   202:1    0   3.8M  1 part
`-xvda2   202:2    0 630.9M  1 part /var/adm/mount
xvdb      202:16   0     6G  0 disk
xvdc3     202:35   0    60G  0 disk
|-xvdc3p1 254:0    0     6G  0 part
`-xvdc3p2 254:1    0     6G  0 part
```


## Stopping the XEN guest

Either do `halt -fp` within the XEN guest or `xl destroy sle15` on the XEN host.


## Further reading

If you want to extend the XEN configuration have a look at the man pages in the `xen-tools` package.
For example `xl.cfg(5)` and `xl-disk-configuration(5)`.
