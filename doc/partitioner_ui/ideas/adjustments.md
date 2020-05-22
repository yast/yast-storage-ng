## Idea: Small Adjustments

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

The main concept here would be to accept the UI in Leap 15.2 is already quite good. It just bears some
legacy burden from the old storage UI and the information presented is not always ideal. The goal of
this idea would be to introduce a couple of minor changes here and there, while keeping the general
approach and the current organization.

### Adjustment 1: More Reasonable Workflow to Format/Mount

One of these small changes would be a reorganization of the current workflow to format and mount
block devices.

The partition ID would not be part anymore of the screen used to select the format/mount options, it
should be moved elsewhere.

The format/mount screen would look like this:


```
┌Formatting─────────────────────────┐    ┌Mounting───────────────────────────┐
│                                   │    │                                   │
│ ┌[x] Format device──────────────┐ │    │ ┌[x] Mount device───────────────┐ │
│ │  Filesystem: BTRFS            │ │    │ │  Mount point                  │ │
│ │  [Format options...]          │ │    │ │  /home▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒↓ │ │
│ └───────────────────────────────┘ │    │ │                               │ │
│                                   │    │ │  [Mount options...]           │ │
│ ┌[x] Encrypt device─────────────┐ │    │ │  [Subvolume options...]       │ │
│ │  [x] Keep existing encryption │ │    │ └───────────────────────────────┘ │
│ │                               │ │    └───────────────────────────────────┘
│ │  [Encryption options...]      │ │
│ │                               │ │
│ │  Password                     │ │
│ │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │ │
│ │  Retype password              │ │
│ │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │ │
│ └───────────────────────────────┘ │
└───────────────────────────────────┘
```

Some notes about that sketch:

- There's no file system selection drop-down anymore - that's hidden behind the "Format options"
  button. The rationale is that we advertise a default filesystem and users usually don't change that.
- MAYBE: make swap not available here. If something is going to be used as swap it should be
  specified in a previous/different step. The reason is that swap and 'normal' filesystems are
  treated differently already (try alternating between swap and xfs, for example and watch the mounting
  option dialog). And it's inconsistent to have a swap partition id and a btrfs filesystem anyway.

Clicking "Format options" or "Mount options" would lead to the corresponding pop-up dialog:

```
┌Format options─────────────────────┐    ┌Mount options──────────────────────┐
│                                   │    │                                   │
│ Filesystem                        │    │ [x] Mount at System Start-up      │
│ XFS▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒↓      │    │ [ ] Mountable by User             │
│                                   │    │ [ ] Mount Read-Only               │
│ ┌XFS options────────────────────┐ │    │ [ ] Enable Quota Support          │
│ │ Block Size in Bytes           │ │    │                                   │
│ │ auto▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒↓    │ │    │ Mount filesystem by               │
│ │ Inode Size in Bytes           │ │    │ UUID▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒↓            │
│ │ auto▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒↓    │ │    │                                   │
│ │ Percentage of Inode Space     │ │    │ Volume label                      │
│ │ auto▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒     │ │    │ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │
│ │                               │ │    │                                   │
│ │ [x] Inodes Aligned            │ │    │ Additional Option Values          │
│ └───────────────────────────────┘ │    │ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │
│                                   │    │                                   │
│      [OK]  [Cancel]  [Help]       │    │      [OK]  [Cancel]  [Help]       │
└───────────────────────────────────┘    └───────────────────────────────────┘
```
