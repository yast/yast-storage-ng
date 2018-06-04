# Introduction

This document describes the expert partitioner behavior using specs. The idea is to document all the functionalities of the expert partitioner with a similar format that we would obtain as rspec output. Note: these specs have been done manually, they are not the result of a real rspec test.

The specs are based on current version of expert partitioner for TW. The goal is to know and understand the gap between old and new expert partitioners. Missing parts in the new expert partitioner are marked as *pending* along the document.

## Expert partitioner specs

### When 'Hard Disks' is selected in the tree view
  * shows a table with the columns: Device, Size, F, Enc, Type, FS Type, Label, Mount Point, Start, End
    * and the table is filled out with info of all disks and partitions
  * shows the actions: 'Add Partition', 'Edit', 'Move', 'Resize' and 'Delete'
    * and action 'Add Partition' is selected
      * and the current selected row in the table is a disk
        * starts wizard to add a new partition to the disk
      * and the current selected row in the table is a partition
        * starts wizard to add a new partition to the disk that the partition belongs to.
    * and action 'Edit' is selected
      * and the current selected row in the table is a disk
        * shows the disk view for that specific disk
      * and the current selected row in the table is a partition
        * and the partition is extended
          * shows an error popup
        * and the partition is not extended
          * shows the edition dialog for that partition
    * and action 'Move' is selected
      * and the current selected row in the table is a disk
        * shows an error popup
      * and the current selected row in the table is a partition
        * and it is possible to move the partition (forward or backward)
          * shows a confirm popup to move the partition
          * moves the partition
        * and it is not possible to move the partition
          * shows an error popup
    * and action 'Resize' is selected
      * and the current selected row in the table is a disk
        * shows an error popup
      * and the current selected row in the table is a partition
        * shows the resize dialog
    * and action 'Delete' is selected
      * and the current selected row in the table is a disk
        * shows a confirm popup to delete all partitions of the disk
        * removes all disk partitions
      * and the current selected row in the table is a partition
        * shows a confirm popup to delete the partition
        * removes the partition

### When a 'disk' is selected in the tree view
  * shows a view with two tabs: 'Overview' and 'Partitions'
  * and tab 'Overview' is selected
    * shows a report with two sections: 'Device' and 'Hard Disk'
      * where 'Device' section contains the folling disk info
        * device name
        * device size
        * device path
        * device id
      * where 'Hard Disk' section contains the following disk info
        * vendor
        * model
        * number of cylinders (replaced by number of sectors)
        * cylinder size (not apply anymore)
        * bus
        * sector size
        * disk label
    * *(pending) shows a button for 'Health Test (SMART)'*
  * and tab 'Partitions' is selected
    * shows a bar image with the disk partitions
    * shows a table filled out with disk partitions info (same columns than before)
    * shows the actions: 'Expert', 'Add', 'Edit', 'Move'
      * and action 'Expert' is selected
        * shows two options: 'Create New Partition Table' and 'Clone this Disk'
          * and 'Create New Partition Table' is selected
            * shows a popup to select a partition table type: MSDOS, GPT, DASD
            * DASD is only showed for s390 arch
            * and 'Ok' is selected
              * asks for confirmation
              * removes existing partition table
              * creates a new partition table into the disk
          * and 'Clone this Disk' is selected
            * shows a popup dialog to select the disk where to clone
            * and 'Ok' is selected
              * shows a popup to confirm partitions deleting
              * clones the disk partitions
      * and action 'Add' is selected
        * shows wizard to add a new partition
      * and action 'Edit' is selected
        * and the partition is extended
          * shows an error popup
        * and the partition is not extended
          * shows dialog to edit the current selected partition in the table
      * and action 'Move' is selected
        * and it is possible to move the partition (forward or backward)
          * shows a confirm popup to move the partition
          * moves the partition
        * and it is not possible to move the partition
          * shows an error popup
      * and action 'Resize' is selected
        * shows the resize dialog
      * and action 'Delete' is selected
        * shows a confirm popup to delete the partition
        * deletes the partition

### When a 'partition' is selected in the tree view
* shows a report with two sections: 'Device' and 'File System'
  * where 'Device' section contains the folling info
    * Device
    * Size
    * Encrypted
    * Device path
    * Device id
    * Fs id
  * where 'File system' section contains the folling info
    * File system
    * Mount point
    * Label
* shows the actions: 'Edit', 'Move', 'Resize' and 'Delete'
  * and action 'Edit' is selected
    * the same than in the "disk view"
  * and action 'Move' is selected
    * the same than in the "disk view"
  * and action 'Resize' is selected
    * the same than in the "disk view"
  * and action 'Delete' is selected
    * the same than in the "disk view"

### When 'Resize' is selected
* and selected partition is extended
  * shows an error popup
* and selected partition is not extended
  * shows a dialog with the following fields
    * Maximum size (default)
    * Minimum size
    * Custom size
  * and 'Ok' is selected
    * and entered custom sized is not valid
      * shows an error popup
    * resizes the partition

### When 'Add partition' is selected
* and there is not space enough
  * shows an error popup
* and it is not possible to create more partitions (max number of primary reached)
  * shows an error popup
* and it is possible to create a new partition
  * shows a wizard with 5 steps
    * select partition type
    * select partition size
    * select partition role
    * set partition attributes (fs, mount point, etc)
    * set encrypt password (optional)

#### When we are in wizard step to select the partition type
* and partition table is not MSDOS
  * the step is skipped
* and partition table is MSDOS
  * and only it is possible to create primary partitions
    * the step is skipped
  * and only it is possible to create logical partitions
    * the step is skipped
  * and there is space for a primary partition
    * and the max of primary partitions is not reached
      * shows option 'Primary partition'
  * and there is not an extended partition
    * shows option 'Extended partition'
  * and there is an extended partition with free space
    * shows option 'Logical partition'

#### When we are in wizard step to select the partition size
* shows three options
  * Maximun size
  * Custom size
    * with maximum size by default
  * Custom region
    * with start and end cylinders of the free region by default
* *(pending) and partition is primary*
  * custom size is selected by default
* and partition is extended
  * maximum size is selected by default
* *(pending) and partition is logical*
  * custom region is selected by default
* and 'Next' is selected
  * and partition is extended
    * finishes wizard
    * creates the partition

#### When we are in wizard step to select the role of the partition
* shows the following options
  * operating system (i.e. root)
  * data and ISV applications (any other mount point)
  * swap
  * raw volume (unformatted)
* option 'data and ISV applications' is selected by default

#### When we are in wizard step for partition attributes
* shows two sets of options: 'Formatting options' and 'Mounting options'
  * where 'Formatting options' contains
    * Format partition
    * Do not format partition
    * Encrypt device
  * where 'Mounting options' contains
    * Mount partition
    * Do not mount partition
* and partition role is 'Operating system'
  * sets the following 'Formatting options' by default
    * Format partition: true
      * File System: Btrfs
      * Enable snapshots: true
    * Do not format partition: false
      * File System Id: 0x83 Linux
    * Encrypt: false
  * sets the following options for 'Mounting options'
    * Mount partition: true
      * Mount point: first free of /, /home, /var
    * Do not mount partition: false
* and partition role is 'Data and ISV applications'
  * sets the following 'Formatting options' by default
    * Format partition: true
      * File System: XFS
    * Do not format partition: false
      * File System Id: 0x83 Linux
    * Encrypt: false
  * sets the following options for 'Mounting options'
    * Mount partition: true
      * Mount point: first free of /, /home, /var
    * Do not mount partition: false
* and partition role is 'Swap'
  * sets the following 'Formatting options' by default
    * Format partition: true
      * File System: Swap
    * Do not format partition: false
      * File System Id: 0x82 Linux Swap
    * Encrypt: false
  * sets the following options for 'Mounting options'
    * Mount partition: true
      * Mount point: swap
    * Do not mount partition: false
* and partition role is 'Raw volume'
  * sets the following 'Formatting options' by default
    * Format partition: false
    * Do not format partition: true
      * File System Id: 0x8E Linux LVM
    * Encrypt: false
  * sets the following options for 'Mounting options'
    * Mount partition: false
    * Do not mount partition: true
* and 'Finish' button is selected
  * and 'Mount partition' is true
    * and 'Format partition' is false
      * and partition is not formatted
        * shows an error popup
    * and mount point does not start by /
      * shows an error popup
    * and filesystem is swap
      * and mount point is not swap
        * shows an error popup
  * and 'Encrypt device' is true
    * shows a new wizard step to enter the password
  * saves the partition options

##### When 'Format partition' is selected
* disables 'File system Id'
* allows to select a 'File system'
  * where options are: BtrFs, EXT2, EXT3, EXT4, FAT, XFS, Swap
* and 'File system' is BtrFS
  * does not show 'Options' button
  * shows 'Enable snaphsots'
  * and mount point is /
    * marks 'Enable snapshots'
  * shows button 'Subvolume Handling'
  * sets 'File system Id' to 0x83 Linux
* and 'File system' is EXT2
  * shows 'Options' button
  * and 'Options' is selected
    * shows a dialog with the fields
      * Stride Length in blocks: none
      * Block size in bytes: auto (default), 1024, 2048, 4096
      * Bytes per inode: auto (default), 1024, 2048, 4096, 8192, 16384, 32768
      * Percentage of blocks reserved for root: 5.0
      * Disable regular checks: false
  * sets 'File system Id' to 0x83 Linux
* and 'File system' is EXT3
  * shows 'Options' button
  * and 'Options' is selected
    * shows a dialog with the fields
      * Stride Length in blocks: none
      * Block size in bytes: auto (default), 1024, 2048, 4096
      * Bytes per inode: auto (default), 1024, 2048, 4096, 8192, 16384, 32768
      * Percentage of blocks reserved for root: 5.0
      * Disable regular checks: true
      * Inode size: default, 128, 256, 512, 1024
      * Directory index feature: false
  * sets 'File system Id' to 0x83 Linux
* and 'File system' is EXT4
  * shows 'Options' button
  * and 'Options' is selected
    * shows a dialog with the fields
      * Stride Length in blocks: none
      * Block size in bytes: auto (default), 1024, 2048, 4096
      * Bytes per inode: auto (default), 1024, 2048, 4096, 8192, 16384, 32768
      * Percentage of blocks reserved for root: 5.0
      * Disable regular checks: true
      * Inode size: default, 128, 256, 512, 1024
      * Directory index feature: false
      * No journal: false
  * sets 'File system Id' to 0x83 Linux
* and 'File system' is FAT
  * shows 'Options' button
  * and 'Options' is selected
    * shows a dialog with the fields
      * Number of FATs: auto (default), 1, 2
      * FAT size: auto (default), 12 bit, 16 bit, 32 bit
      * Root dir entries: auto
  * sets 'File system Id' to 0x0C Win95 FAT32
* and 'File system' is XFS
  * shows 'Options' button
  * and 'Options' is selected
    * shows a dialog with the fields
      * Block size in bytes: auto (default), 1024, 2048, 4096
      * Inode size: auto (default), 256, 512, 1024, 2048
      * Percentage of inode space: auto (default), 5, 10, ..., 95, 100
      * Inode aligned: auto (default), true, false
  * sets 'File system Id' to 0x83 Linux
* and 'File system' is Swap
  * shows 'Options' button as disabled
  * sets 'Mount point' to Swap
  * sets 'File system Id' to 0x82 Linux swap

##### When 'Do not format partition' is selected
* disables 'Format partition' options
* allows to select a 'File system Id'
  * where options are: 0x83 Linux, 0x8E Linux LVM, 0x82 Linux swap, 0xFD Linux RAID, 0x07 NTFS, 0x0C Win 95 FAT, 0xA0 Hibernation
    * *(pending) and partition table is GPT*
      * options include: 0x00 BIOS Grub, 0x00 GPT PReP Boot, 0x00 EFI Boot
* *(pending) allows to enter a 'File system Id' manually*
* *(pending) when 'File system Id' is 0x83 Linux, 0x07 NTFS, 0x0C Win 95 FAT, 0xA0 Hibernation, 0x00 EFI Boot*
  * enables 'Mounting options'
* *(pending) when 'File system Id' is 0x8E Linux LVM, 0xFD Linux RAID, 0xA0 Hibernation, 0x00 BIOS Grub, 0x00 GPT PReP Boot*
  * disables 'Mounting options'
* when 'File system Id' is 0x82 Linux swap
  * enables 'Mounting options'
  * sets 'Mount point' to swap

##### When 'Mount partition' is selected
* allows to select 'Mount point'
  * where options are: /, /home, /var, /opt, /boot, /srv, /tmp, /usr/local
  * first free value is taken by default
* allows to enter a 'Mount point' manually
* and a 'Mount point' is indicated
  * shows the button 'Fstab options'

##### When 'Do not mount partition' is selected
* * disables 'Mount device' options

##### When 'Fstab options' is selected
* and 'File system' is BtrFs
  * shows a dialog with the following fields
    * Mount in /etc/fstab by: Device name, Volume label, UUID (default), Device ID, Device path
    * Volume label:
    * Mount Read-only: false
    * No access time: false
    * Mountable by user: false
    * Do not mount at system start-up: false
    * *(pending) Arbitrary option value: subvol=@*
* and 'File system' is EXT2
  * shows a dialog with the following fields
    * Mount in /etc/fstab by: Device name, Volume label, UUID (default), Device ID, Device path.
    * Volume label:
    * Mount Read-only: false
    * No access time: false
    * Mountable by user: false
    * Do not mount at system start-up: false
    * Enable quota support: false
    * Access control lists (ACL): true
    * Extended user attributes: true
    * Arbitrary option value:
* and 'File system' is EXT3 or EXT4
  * shows a dialog with the following fields
    * Mount in /etc/fstab by: Device name, Volume label, UUID (default), Device ID, Device path.
    * Volume label:
    * Mount Read-only: false
    * No access time: false
    * Mountable by user: false
    * Do not mount at system start-up: false
    * Enable quota support: false
    * Data journaling mode: journal, ordered (default), writeback
    * Access control lists (ACL): true
    * Extended user attributes: true
    * Arbitrary option value:
* and 'File system' is FAT
  * shows a dialog with the following fields
    * Mount in /etc/fstab by: Device name, Volume label, UUID (default), Device ID, Device path.
    * Volume label:
    * Mount Read-only: false
    * No access time: false
    * Mountable by user: false
    * Do not mount at system start-up: false
    * *(pending) Charset for file names: iso, utf8, etc (default blank)*
    * Codepage for short FAT names: 437, 852, 932, 936, 949, 950, (default blank)
    * *(pending) Arbitrary option value: users,gid=users,umask=0002,utf8=true*
* and 'File system' is XFS
  * shows a dialog with the following fields
    * Mount in /etc/fstab by: Device name, Volume label, UUID (default), Device ID, Device path.
    * Volume label:
    * Mount Read-only: false
    * No access time: false
    * Mountable by user: false
    * Do not mount at system start-up: false
    * Enable quota support: false
    * Arbitrary option value:
* and 'File system' is Swap
  * shows a dialog with the following fields
    * Mount in /etc/fstab by: Device name, Volume label, UUID (default), Device ID, Device path.
    * Volume label:
    * Swap priority:
    * Arbitrary option value:

##### When 'Subvolume handling' is selected
* shows a dialog with a list of all subvolumes
* allows to add a new subvolume
* allows to remove one subvolume from the list
* alerts when trying to create a subvolume that does not start by /@
  * automatically appends /@ to the subvolume path

### When 'RAID' is selected in the tree view
* shows a table with the columns: Device, Size, F, Enc, Type, FS Type, Label, Mount Point, RAID Type, Chunk Size
  * and the table is filled out with info of all RAID devices
* shows the actions: 'Add RAID', 'Edit', 'Resize' and 'Delete'
* and action 'Add RAID' is selected
  * and there is less than two not mounted partitions
    * shows an error message
  * and there is at least two not mounted partitions with correct partition ID (LINUX, SWAP, LVM, RAID)
    * shows a wizard to create a new RAID
* and action 'Edit' is selected
  * shows dialog to edit the RAID partition
* and action 'Resize' is selected
  * shows a dialog to modify the RAID devices
* and action 'Delete' is selected
  * shows a confirm popup to delete the RAID
  * deletes the RAID

### When a 'RAID' is selected in the tree view
* shows a view with two tabs: 'Overview' and 'Used Devices'
* and tab 'Overview' is selected
  * shows a report with three sections: 'Device', 'RAID' and 'File System'
    * where 'Device' section contains the folling info
      * device name
      * device size
      * encrypted
      * device id
    * where 'RAID' section contains the following info
      * RAID type
      * chunk size
      * parity algorithm
    * where 'File System' section contains the following info
      * file system
      * mount point
      * label
  * shows the actions: 'Edit', 'Resize' and 'Delete'
    * and action 'Edit' is selected
      * shows dialog to edit the RAID partition (similar to edit disk partition)
    * and action 'Resize' is selected
      * shows a dialog to modify the RADID devices
    * and action 'Delete' is selected
      * shows a confirm popup to delete the RAID
      * deletes the RAID
* and tab 'Used Devices' is selected
  * shows a table with the columns: Device, Size, F, Enc and Type
    * and the table is filled out with info of all devices that belong to the RAID
  * and an item in the table is selected (double click)
    * jumps to the corresponding partition in the 'Hard Disks' section

### When 'Add RAID' is selected
* shows a wizard with 5 steps
  * select RAID type and devices
  * select RAID options
  * select partition role
    * same wizard step than in partition creation (see above)
  * set partition attributes (fs, mount point, etc)
    * same wizard step than in partition creation (see above)
    * 'File System Id' is not shown (automatically set to Linux RAID)
  * set encrypt password (optional)
    * same wizard step than in partition creation (see above)

#### When we are in wizard step to select RAID type and devices
* shows the following options
  * RAID Type
    * RAID 0 (at least 2 devices)
    * RAID 1 (at least 2 devices)
    * RAID 5 (at least 3 devices)
    * RAID 6 (at least 4 devices)
    * RAID 10 (at least 2 devices)
  * RAID Name (optional)
  * Available Devices
    * shows a table with the columns: Device, Size, Enc, Type
    * and the table is filled out with info of available devices for RAID
  * Selected Devices
    * shows a table with the columns: Device, Size, Enc, Type
    * and the table is filled out with info of devices that belong to the RAID
* shows the actions: 'Add', 'Add All', 'Remove', 'Remove All'
  * and action 'Add' is selected
    * move the selected device from 'Available devices' to 'Selected Devices'
  * and action 'Add All' is selected
    * move all devices from 'Available devices' to 'Selected Devices'
  * and action 'Remove' is selected
    * move the selected device from 'Selected Devices' to 'Available devices'
  * and action 'Remove All' is selected
    * move all devices from 'Selected Devices' to'Available devices'
* shows the actions: 'Top', 'Up', 'Down' and 'Bottom'
  * and action 'Top' is selected
    * reorder RAID devices by moving to top the current selected device from 'Selected Devices'
  * and action 'Up' is selected
    * reorder RAID devices by moving up the current selected device from 'Selected Devices'
  * and action 'Down' is selected
    * reorder RAID devices by moving down the current selected device from 'Selected Devices'
  * and action 'Bottom' is selected
    * reorder RAID devices by moving to bottom the current selected device from 'Selected Devices'
* *(pending) shows the action 'Classify'*
  * and action 'Classify' is selected
    * shows a dialog to classify the RAID devices
* and 'next' is selected
  * and there are not enough selected devices for the selected RAID type
    * shows an error popup and does not allow to continue


##### *(pending) When we are in the dialog to classify the RAID devices*
* shows a table with the columns: Device, Class
  * and the table is filled out with info of devices that belong to the RAID
* shows the actions: 'Class A', 'Class B', 'Class C', 'Class D' and 'Class E'
  * and one of them is selected:
    * set the class of all selected devices from the table
* shows the actions: 'Sorted (AAABBBCCC)', 'Interleaved (ABCABCABC)' and 'Pattern File'
  * and action 'Sorted (AAABBBCCC)' is selected
    * sorts devices by class
  * and action 'Interleaved (ABCABCABC)' is selected
    * sorts devices by class in interleaved order
  * and action 'Pattern File' is selected
    * opens a dialog to select a pattern file
    * sets class to devices according to the pattern file

#### When we are in wizard step to select RAID options
* when selected RAID type is: RAID0 or RAID1
  * shows the following options
    * Chunk Size
      * values: 4 KiB, 8 KiB, 16 KiB, 32 KiB, 128 KiB, 256 KiB, 512 KiB, 1 MiB, 2 MiB, 4 MiB
  * and RAID type is RADI0
    * default chunk size: 32 KiB
  * and RAID type is RADI1
    * default chunk size: 4 KiB
* when selected RAID type is: RAID5, RAID6 or RAID10
  * shows the following options
    * Chunk Size
      * values: 4 KiB, 8 KiB, 16 KiB, 32 KiB, 128 KiB, 256 KiB, 512 KiB, 1 MiB, 2 MiB, 4 MiB
    * Parity Algorithm
      * values: default, n2, o2, f2, n3, o3, f3
  * and RAID type is RAID5 or RAID6
    * default chunk size: 128 KiB
    * default parity algorithm: default
  * and RAID type is RAID10
    * default chunk size: 32 KiB
    * default parity algorithm: default

### When 'Edit' is selected
* same dialog than partition edition (see above)
* 'File System Id' is not shown

### When 'Resize' is selected
* same dialog than wizard step to select RAID type and devices
* 'RAID Type' is not shown
* 'RAID Name' is not shown

### When 'Volume Management' is selected in the tree view
* shows a table with the columns: Device, Size, F, Enc, Type, FS Type, Label, Mount Point, Metadata, PE Size, Stripes
  * and the table is filled out with info of all VGs and Lvs
* shows the actions: 'Add', 'Edit', 'Resize' and 'Delete'
* and action 'Add' is selected
  * and the table is empty
    * shows an option to add "Volume group"
  * and the table is not empty (at least one VG)
    * shows an option to add "Volume Group"
    * shows an option to add "Logical Volume"
* and action 'Edit' is selected
  * and a VG is selected in the table
    * shows the general view of the VG (same than selecting the VG in the tree view)
  * and a LV is selected in the table
    * shows dialog to edit the LV
* and action 'Resize' is selected
  * and a VG is selected in the table
    * shows dialog to resize the VG
  * and a LV is selected in the table
    * shows popup dialog to resize the LV
* and action 'Delete' is selected
  * and a VG is selected in the table
    * shows a confirm popup to delete the VG and its LVs
    * deletes the VG (and its LVs)
  * and a LV is selected in the table
    * shows a confirm popup to delete the LV
    * deletes the LV

#### When 'Add' + 'Volume Group' is selected
* and there are not valid unused devices (0x8e Linux, 0x83 LVM, 0xFD RAID)
  * shows an error popup
* and there are valid unused devices
  * shows the following options
    * Volume Group Name
    * Physical Extend Size
    * Available Physical Volumes
      * shows a table with the columns: Device, Size, Enc, Type
      * and the table is filled out with info of available devices for LVM
    * Selected Physical volumes
      * shows a table with the columns: Device, Size, Enc, Type
      * and the table is filled out with the devices that belong to the VG
  * shows the actions: 'Add', 'Add All', 'Remove', 'Remove All'
    * and action 'Add' is selected
      * move the selected device from 'Available Physical Volumes' to 'Selected Physical Volumes'
    * and action 'Add All' is selected
      * move all devices from 'Available Physical Volumes' to 'Selected Physical Volumes'
    * and action 'Remove' is selected
      * move the selected device from 'Selected Physical Volumes' to 'Available Physical Volumes'
    * and action 'Remove All' is selected
      * move all devices from 'Selected Physical Volumes' to'Available Physical Volumes'
  * and 'Finish' is selected
    * and 'Volume Group Name' is empty
      * shows an error popup
      * avoids to continue
    * and there are not selected physical volumes
      * shows an error popup
      * avoids to continue
    * creates the VG

#### When 'Resize' is selected (over a VG)
* same dialog than 'Add' + 'Volume Group' (see above)
* 'Volume Group Name' is not shown
* 'Physical Extend Size' is not shown

### When a 'VG' is selected in the tree view
* shows a view with three tabs: 'Overview', 'Logical Volumes' and 'Physical Volumes'
  * tab 'Logical Volumes' is selected by default
* and tab 'Overview' is selected
  * shows a report with two sections: 'Device' and 'LVM'
    * where 'LVM' section contains the folling info
      * device name
      * device size
    * where 'LVM' section contains the following info
      * *(pending) Metadata*
      * PE Size
* and tab 'Logical Volumes' is selected
  * shows a bar image with the LVs
  * shows a table with the columns: Device, Size, F, Enc, Type, FS Type, Label, Mount Point, Stripes
    * and the table is filled out with info of LVs that belong to the VG
  * shows the actions: 'Add', 'Edit', 'Resize' and 'Delete'
    * and action 'Add' is selected
      * shows wizard to add a new LV
    * and action 'Edit' is selected
      * shows dialog to edit the current selected LV in the table
      * same dialog than partition edition (see above)
      * 'File System Id' is not shown
      * and selected LV is a thin pool
        * shows an error popup
        * does not allow to edit the LV
    * and action 'Resize' is selected
      * shows popup dialog to resize the current selected LV in the table
    * and action 'Delete' is selected
      * shows a confirm popup to delete the selected LV
      * deletes the LV
* and tab 'Physical Volumes' is selected
  * shows a table with the columns: Device, Size, F, Enc, Type
    * and the table is filled out with info of PVs that belong to the VG

#### When 'Add' is selected
* and there is not free space in the VG
  * shows an error popup
* and there is free space in the VG
  * shows a wizard with 5 steps
    * select LV name and type
    * select LV size
    * select LV role
      * same wizard step than in partition creation (see above)
    * set fs attributes (fs type, mount point, etc)
      * same wizard step than in partition creation (see above)
      * 'File System Id' is not shown
    * set encrypt password (optional)
      * same wizard step than in partition creation (see above)
* and only it is possible to add a thin pool lv
  * sets 'Type' to 'Thin Pool'

##### When we are in the wizard step to select the LV name and type
* shows two sections: 'Name' and 'Type'
  * where 'Name' contains
    * 'Logical volume' field for the name of the LV
  * where 'Type' contains the options
    * Normal Volume
    * Thin Pool
    * Thin Volume
  * and 'Thin Volume' is selected
    * enables 'Used Pool' selectbox
  * and 'next' is selected
    * and 'Logical Volume' field is empty
      * shows an error popup
      * avoids to continue
    * and 'Logical Volume' field is not empty
      * continues to the wizard step to select the LV size

##### When we are in the wizard step to select the LV size
* shows two sections: 'Size' and 'Stripes'
  * where 'size' contains the options
    * Maximun Size
      * selected by default
    * Custom Size
      * filled out with maximum size by default
  * where 'Stripes' contains the fields
    * Number
    * Size
  * and 'next' is selected
    * and 'Custom Size' is selected
      * and entered size is not valid
        * shows an error popup
        * avoids to continue
    * continues to the wizard step select LV role

#### When 'resize' is selected
* shows a popup dialog with three options
  * Maximum Size
  * Minimum Size
  * Custom Size
  * and 'OK' is selected
    * and 'Custom Size' is selected
      * and entered size is not valid (minimum <= size <= maximum)
        * shows an error popup
        * avoids to continue
    * updates the LV size

### When a LV is selected in the tree view
* shows a report with three sections: 'Device', 'LVM' and 'File System'
  * where 'Device' section contains the folling info
    * Device
    * Size
    * Encrypted
  * where 'LVM' section contains the folling info
    * Stripes
  * where 'File system' section contains the folling info
    * File system
    * Mount point
    * Label
* shows the actions: 'Edit', 'Resize' and 'Delete'
  * and action 'Edit' is selected
    * the same than in the "VG view"
  * and action 'Resize' is selected
    * the same than in the "VG view"
  * and action 'Delete' is selected
    * the same than in the "VG view"
