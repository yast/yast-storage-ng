# Setting up Virtual Multipath Hardware for Testing

I needed to test YaST behavior with multipath disks and had no actual
multipath hardware. Eventually I figured out a way to simulate it with QEMU.

## Requirements

I tested with QEMU 2.12.0.
(openSUSE Leap 15.0 has QEMU 2.11.2, Leap 15.1 has 3.1.0)

## Setup

The principle is:

- use two SCSI hard disks with
    - the same *serial* string, and
    - the same backing image
  
for this to work, we also need to

- use the *raw* format because *qcow2* supposedly has a bug
- disable caching
- disable locking of the images

so the necessary arguments are:

```sh
HDA=$HOME/mydisk.raw
qemu-img create -f raw "$HDA" 16G
qemu-kvm \
   $OTHER_ARGUMENTS \
   -device virtio-scsi-pci,id=scsi \
   -drive if=none,id=hda,file=$HDA,cache=none,format=raw,file.locking=off \
   -device scsi-hd,drive=hda,serial=MPIO \
   -drive if=none,id=hdb,file=$HDA,cache=none,format=raw,file.locking=off \
   -device scsi-hd,drive=hdb,serial=MPIO
```

## References

- https://duckduckgo.com/?q=qemu+multipath
- https://blog.elastocloud.org/2017/07/multipath-failover-simulation-with-qemu.html
