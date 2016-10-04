# Testing iBFT setups with qemu

iBFT stands for iSCSI Boot Firmware Table;
if you are curious check out the
[iBFT Spec](ftp://ftp.software.ibm.com/systems/support/bladecenter/iscsi_boot_firmware_table_v1.03.pdf).

You need to be able to set up an iSCSI target ('server').
See [iscsi-for-beginners](iscsi-for-beginners.md) for how to do this.

Also, you will need the [iPXE](http://ipxe.org) sources. Get them and build iPXE:

```sh
git clone git://git.ipxe.org/ipxe.git
cd ipxe/src
make
```

iPXE is a firmware that can do lots of cool stuff. We are only interested in the iSCSI part here.

It comes with some integrated help function which will refer you to
[ipxe.org/cmd](http://ipxe.org/cmd) for details, so you might want to go there directly.

## Connect iPXE with qemu

The `make` command above builds various firmware images. We'll rebuild one of them
later but for first experiments, pick the one for your qemu network device and copy to `/usr/share/qemu`:

```sh
cp bin/rtl8139.rom /usr/share/qemu/ipxe-rtl8139.rom
```

Or, if you prefer to work with virtio

```sh
cp bin/1af41000.rom /usr/share/qemu/ipxe-virtio.rom
```

When you run qemu, tell it to pick up the these alternative firmware files using the `romfile` option:

```sh
qemu ... -device rtl8139,romfile=ipxe-rtl8139.rom ...
# or
qemu ... -device virtio-net-pci,romfile=ipxe-virtio.rom ...
```

This new firmware prompts you to press Ctrl-B to enter setup.

Do so.

## Network and basic iSCSI setup

Configure your network:

```sh
dhcp
# or static
set net0/ip 192.168.0.2
set net0/netmask 255.255.255.0
set net0/gateway 192.168.0.1
```

You can print your current network config:

```sh
show net0/ip
route
```

Print your iSCSI initiator name:

```sh
show initiator-iqn
```

The default will look something like `iqn.2010-04.org.ipxe:<HOSTNAME>`.

Use the `targetcli` command on your iSCSI target to allow access to this initiator (create an `acl`).

To stay sane during testing it's probably a good idea to set the initiator name to some fixed value.
This way you don't have to worry about adjusting the target setup; e.g.:

```sh
set initiator-iqn iqn.2010-04.org.ipxe:foobar
```

Now connect to your target machine using the `sanhook` command.
Syntax of the URI is basically `iscsi:<IP>::::<TARGET_IQN>`, for more details look at
[ipxe.org/sanuri](http://ipxe.org/sanuri).


```sh
sanhook iscsi:10.42.0.11::::iqn.2003-01.org.linux-iscsi.f43.x8664:sn.f1eec5c8304a
```

If that fails, check your iSCSI target logs.

Now you can exit the iPXE shell and continue the usual boot process. The firmware
will provide an iBFT record with the current iSCSI setup.

## Automate iSCSI setup

While that's all nice it's a bit tedious for repeated testing. Fortunately iPXE allows you to integrate
a setup script that's automatically run; see [ipxe.org/scripting](http://ipxe.org/scripting) for details.

Here's the one I used:

```sh
#!ipxe

dhcp
set initiator-iqn iqn.2010-04.org.ipxe:foobar
sanhook iscsi:10.42.0.11::::iqn.2003-01.org.linux-iscsi.f43.x8664:sn.f1eec5c8304a ||
show net0/ip
route
echo == config done ==
echo
prompt --key 0x02 --timeout 8000 Press Ctrl-B for the iPXE command line... && shell ||
```

Some notes:

- The script terminates on every command with a non-zero exit
status; the appended '`||`' prevents this.

- When you use a script, you don't
get a prompt during boot. If you want one, you have to program it yourself.
That's what the `prompt` line at the end is for.

- **You still have to press `Ctrl-B` initially to run the script!**

Put this script into a file, say `foo.ipxe` and compile it into your firmware:

```sh
make bin/rtl8139.rom EMBED=foo.ipxe
# or
make bin/1af41000.rom EMBED=foo.ipxe
```

Copy these firmware file into the qemu directory as described above and
you'll automatically get an iSCSI setup via iBFT at each boot.
