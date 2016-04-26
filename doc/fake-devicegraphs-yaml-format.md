# YAML File Format For Fake Device Graphs

This document describes the file format used to set up fake (mockup) device
trees for testing some of the functionality of YaST storage, in particular the
storage proposal.

Please notice that those fake device trees have limitations. They are meant for
creating unit tests, not for actually creating partitions etc. on a real hard
disk.


## File Structure

The device tree is specified in one YAML file. This YAML file might have
multiple documents, separated with "---" as specified by the YAML standard:

    ---
    disk:
      name: /dev/sda
      size: 1 TiB
    ---
    disk:
      name: /dev/sdb
      size: 800 GiB

Even if there is just one document in the file, the first "---" is still
required:

    ---
    disk:
      name: /dev/sda
      size: 1 TiB


There might be one or more toplevel items. If there is just one, the leading
dash "-" may be omitted for the toplevel item (see examples above). If there
are multiple toplevel items, they have to be specified as an array, i.e. with
leading "-":

    ---
    - disk:
        name: /dev/sda
        size: 1 TiB
    - disk:
        name: /dev/sdb
        size: 800 GiB

Remember to indent the next level (the parameters for each disk in this
example) one level. 2 spaces (no tabs!) are recommended for each indentation
level.


## Tree Structure

### Currently Implemented

    - disk:
        partition_table: <type>
        partitions:
          - partition:
              file_system: <type>
          - partition
          - free
          - partition


### For Future Use

    - lvm_logical_volume
    - lvm_volume_group
      - lvm_physical_volume

    - raid


## Parameters

### disk

Example:

    - disk:
        name: /dev/sda
        size: 1 TiB
        partition_table:  ms-dos
        partitions:
        - partition:
            ...
        - partition:
            ...

- name: Kernel device name of the disk, typically something like /dev/sda,
  /dev/sdb etc.


- size: Size of the disk specified as something the DiskSize class can parse:

  - nn KiB
  - nn MiB
  - nn GiB
  - nn TiB
  - ...
  i.e. binary-based sizes, but not kB, MB, GB or shortcuts (k, M, G, ...).


- partition_table: Type of the partition table to create.
  Omit if no partition table should be created.
  Permitted values (case-insensitive):
  - msdos, ms-dos
  - gpt
  - dasd
  - mac

- partitions: Specifies an array of partitions to create.
  Omit if no partitions should be created.


### partition

Example:

    - partition:
        size:         60 GiB
        name:         /dev/sda3
        type:         primary
        id:           Linux
        file_system:  ext4
        mount_point:  /
        label:        root

- size: Similar to disk.size: Size of the partition specified as something the
  DiskSize class can parse, including "unlimited". "unlimited" means "Use all
  the rest of the available space". This makes sense only for the last
  partition on a disk or for an extended partition on a disk with an MS-DOS
  partition table. Notice that subsequent logical partitions start at the
  beginning of that extended partition, so the last one of those logical
  partitions might have size "unlimited" again.


- name: Kernel device name of the partition, typically something like
  /dev/sda1, /dev/sda2, ...; as usual, the first logical partition in an
  extended partition is always /dev/sda5, no matter if /dev/sda4 and /dev/sda3
  actually exist.


- type: Partition type. Default if not specified: "primary".

  Permitted values (case insensitive):
  - primary
  - extended
  - logical

  "extended" and "logical" are supported only for MS-DOS partition tables.


- id: Partition ID, specified either numerical (0x82, 0x83) or as string.
  Default if not specified: linux (0x83)

  Permitted values (case insensitive):

  - linux
  - swap
  - extended
  - lvm
  - raid
  - ppc_prep
  - ntfs
  - gpt_bios
  - gpt_boot
  - gpt_prep
  - dos12
  - dos16
  - dos32
  - apple_other
  - apple_hfs
  - apple_ufs
  - gpt_service
  - gpt_msftres


- file_system: This is really a separate tree level, but it would be awkward to
  write it in the YAML file as such. "mount_point" and "label" really belong to
  the file system, too. As used here, "file_system" specifies the type of file
  system to create. Omit this parameter if no file system should be created.

  Permitted values (case insensitive):

  - ext2
  - ext3
  - ext4
  - btrfs
  - vfat
  - xfs
  - jfs
  - hfs
  - ntfs
  - swap
  - hfsplus
  - nfs
  - nfs4
  - tmpfs
  - iso9660
  - reiserfs
  - udf


- mount_point: The mount point of the file system of this partition.
  Omit if the file system should not be mounted.
  Permitted values: Any valid Linux path (case sensitive)


- label: The label of the file system of this partition.
  Omit if there should be no label.


### free

Example:

    - free:
        size: 300 GiB

This indicates a slot of free space (space that does not belong to any
partition) on the disk between partitions.

- size: Size of the free slot (DiskSize compatible).


## Complete Example

This setup will create 3 disks (/dev/sda, /dev/sdb/, /dev/sdc) with partitions
on the first one (/dev/sda). On /dev/sda, there will be 4 primary partitions,
the last one of which is an extended partition with 2 logical partitions in it
that have a slot of free space between them.

(4 spaces indented to conform with markdown formatting standards)

    ---
    - disk:
        name: /dev/sda
        size: 1 TiB
        partition_table:  ms-dos
        partitions:

        - partition:
            size:         2 GiB
            name:         /dev/sda1
            type:         primary
            id:           0x82
            file_system:  swap
            mount_point:  swap
            label:        swap

        - partition:
            size:         100 GiB
            name:         /dev/sda2
            type:         primary
            id:           0x7
            file_system:  ntfs
            label:        windows

        - partition:
            size:         60 GiB
            name:         /dev/sda3
            type:         primary
            id:           Linux
            file_system:  ext4
            mount_point:  /
            label:        root

        - partition:
            size:         unlimited
            name:         /dev/sda4
            type:         extended

        - partition:
            size:         200 GiB
            name:         /dev/sda5
            type:         logical
            id:           0x83
            file_system:  xfs
            mount_point:  /home
            label:        home

        - free:
            size:         300 GiB

        - partition:
            size:         362 GiB
            name:         /dev/sda6
            type:         logical
            id:           0x83
            file_system:  xfs
            mount_point:  /data
            label:        data

    - disk:
        name: /dev/sdb
        size: 160 GiB
    ---
    disk:
      name: /dev/sdc
      size: 500 GiB

