## Idea: List of Actions per Device

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

The idea would actually be the second part of the one about presenting [all final elements in
one view](./leaf_nodes.md), but it's presentend separatedly because its main concept may be useful
also in other contexts.

When the user selects a device in the list described in the other idea (or in any other list), the
Partitioner could display the actions that are planned for that device, in addition to the possible
options to use it or modify it.

Imagine a logical volume `vg0/root` that already existed in the system but the user has decided to
reformat it and mount it as root. The screen the user would see when clicking on it could be
something like:

```
Previous status: formatted as ext4

Chosen action(s):
 - Format it as Btrfs
 - Mount it at "/" (see subvolumes)

Possible actions:
  [Format / mount] [Delete] [Resize]
```
