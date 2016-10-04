# Getting used to iscsi

**iscsi Newspeak: when iscsi folks talk about *target*, think *server*,
when they say *initiator*, think *client*.**

I will describe here the steps necessary to setup some minimal iscsi testing
environment.

Best seems to be to setup a dedicated vm to serve as target and to use another one
as initiator.

On the target, install `yast2-iscsi-lio-server` and `targetcli`.

The initiator needs `open-iscsi` (and `yast2-iscsi-client`); both should
be installed by default.

Read the SLES12 documentation on how to setup things
[Mass Storage over IP Networks: iSCSI](https://www.suse.com/documentation/sles-12/stor_admin/data/cha_iscsi.html)

*Note that you must know the initiator name when creating the target config.
You can't just connect 'something' to the target. So look it up on your
initiator first.*

## iscsi target setup

For first steps, use `yast2 iscsi-lio-server`.

*Disable firewall or open the iscsi port (3260).*

*When you setup a vm with dhcp, make sure you have a stable ip address, else it
will drive you mad, as the target ip is part of the config - see last step in the
`targetcli` example below.*

The iscsi target is handled by kernel modules. Config goes to `/sys/kernel/config/target/iscsi/`.
But `/etc/target/` holds generated scripts that take care of kernel space modifications. 

[*For me, `/etc/target/lio_setup.sh` always failed when run the very first time
(the initial `mkdir` in the script fails), restarting the `target` service helped.*]

Check that things work: `systemctl status target`.

Instead of yast: use `targetcli` for config. `targetcli` is a rather
peculiar tool. You basically navigate through a virtual filesystem (Use `ls` often!).
Basic syntax is `[RELATIVE_PATH] CMD`. Just watch examples below.

Here's how to setup a target with it. Run `targetcli`, then

```sh
# first, make the block device you want to export known
cd /backstores/iblock
create dev_sda1 /dev/sda1

# or use /backstores/fileio to export a file
/backstores/fileio create foo1 /tmp/foo1.img 1G

# then, create an iscsi target
cd /iscsi
create

# change into the newly created target portal group (Note the final '/tpg1'!)
# (the name is just an example)
cd iqn.2003-01.org.linux-iscsi.e111.x8664:sn.18436556ef11/tpg1

# add a lun
luns/ create /backstores/iblock/dev_sda1

# add an acl to make it accessible to your initiator
# (use your real iscsi initiator name here)
acls/ create iqn.1996-04.de.suse:01:ded3a83a491

# then, export it
# Note that this uses your current ip address!
portals/ create
```

At this point the iscsi initiator should see the device (check with `iscsiadm -m discovery ...`).

To make changes persistent, stop the `target` service. This will `update /etc/target/lio_setup.sh`.

``` sh
systemctl stop target
systemctl start target
```

## iscsi initiator setup

For first steps, use `yast2 iscsi-client`.

On the initiator, iscsid must be running: `systemctl status iscsi iscsid`.

The config is in `/etc/iscsi`. Important is `/etc/iscsi/iscsi.initiatorname`
which sets the initiator name (*client name* in the yast lio-server dialog).

Important commands:

- `iscsiadm -m discovery --type=st --portal=<target_server>`: list the available nodes.

- `iscsiadm -m node -n <node_name> --login`: use the nodes from the output of the command above
(2nd column) to connect to the target - this makes the device available

- `iscsiadm -m node -n <node_name> --logout`: disconnect the device

Connections (with config) you have made are stored (cached) in /etc/iscsi/{send_targets,nodes}.

`/etc/iscsi/iscsid.conf` is a red herring and not used for anything.

