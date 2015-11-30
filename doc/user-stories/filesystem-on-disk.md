
fate #316251

Disks in a SAN can be enlarged.

When a disk contains partitions in order to use new space after enlarging it
is required to either resize the last partition or create new ones. Resizing
active partitions is problematic. Simple adding new once does not allow to
make filesystem larger unless some volume manager is used (LVM or btrfs).

By placing a filesystem directly on the disk handling of partitions is avoided
and the filesystem can be resized right away.

