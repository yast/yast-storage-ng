# BtrFS Subvolumes

There are different ways to define the list of BtrFS subvolumes in YaST.

## Control File and Storage Proposal

The list of subvolumes for a BtrFS file system can be configured by means of the control file. For example, for SLE (and also for openSUSE) the control file contains something like the following:

~~~
<partitioning>
  <volumes config:type="list">
    <volume>
      <mount_point>/</mount_point>
      <fs_type>btrfs</fs_type>
      <btrfs_default_subvolume>@</btrfs_default_subvolume>
      <subvolumes config:type="list">
        <subvolume>
            <path>home</path>
        </subvolume>
        <subvolume>
            <path>opt</path>
        </subvolume>
        <subvolume>
            <path>root</path>
        </subvolume>
        <subvolume>
            <path>srv</path>
        </subvolume>
        <subvolume>
            <path>tmp</path>
        </subvolume>
      </subvolumes>
    </volume>
  </volumes>
</partitioning>
~~~

This configuration of subvolumes is taken into accout by the Storage Proposal when calculating the partitioning proposal. But it also affects to the Expert Partitioner, see *Expert Partitioner* section.

Note that there is a *btrfs_default_subvolume* option. This option allows to configure a kind of "prefix" subvolume, and it may end up being the real default subvolume or not. For example, when using snapshots, the default subvolume is a snapshot subvolume instead of this one. The *btrfs_default_subvolume* has some implications over the rest of subvolumes:

* All the subvolumes are created as children of the *btrfs_default_subvolume*.
* The path of the *btrfs_default_subvolume* is prepended to the path of all the other subvolumes.

When the storage proposal is calculated during the installation, all the BtrFS file systems are configured to contain the list of subvolumes indicated in the control file. Note that the list of subvolumes can be defined for all the volumes formatted as BtrFS and not only for root. In the very specific case of root, the Storage Proposal will use a fallback list of subvolumes when nothing is indicated in the control file. The list of subvolumes can always be manually adapted by means of the Expert Partitioner.


## AutoYaST

AutoYaST also allows to indicate the list of subvolumes for the root file system:

~~~
<subvolumes config:type="list">
  <path>tmp</path>
  <path>opt</path>
  <path>srv</path>
  <path>var/crash</path>
  <path>var/lock</path>
  <path>var/run</path>
  <path>var/tmp</path>
  <path>var/spool</path>
  ...
</subvolumes>
~~~

And similar to the control file, it has a `subvolumes_prefix` option to indicate the default subvolume, typically *@*. This option is equivalent to `btrfs_default_subvolume` from the control file. And again, the fallback list is applied when no subvolumes are indicated.

Note that when exporting the AutoYaST profile, the `subvolumes_prefix` is inferred from the current list of subvolumes. That is, if the top level subvolume only has a child, a typical hierarchy using *@* is supposed:

~~~
top level
|-- @
  |-- @/home
  |-- @/var
~~~

And also note that the subvolume prefix is used when exporting the list of subvolumes. That is, the path of a subvolume is exported as its path after extracting the subvolume prefix. For example, if the subvolume prefix is *@* and the path of the subvolume to be exported is *@/home*, then the path of the subvolume is exported as *home*.


## Expert Partitioner

The Expert Partitioner allows to add, edit and delete BtrFS subvolumes. But it also tries to assign the list of subvolumes from the control file (or the fallback list) when we create or edit a BtrFS file system. For example, let's say we have the following in the control file:

~~~
<partitioning>
  <volumes config:type="list">
    <volume>
      <mount_point>/</mount_point>
      <fs_type>btrfs</fs_type>
      <btrfs_default_subvolume>@</btrfs_default_subvolume>
      <subvolumes config:type="list">
        <subvolume>
            <path>home</path>
        </subvolume>
        <subvolume>
            <path>opt</path>
        </subvolume>
      </subvolumes>
    </volume>
  </volumes>
</partitioning>
~~~

and we use the Expert Partitioner to create a new BtrFS file system. If we indicate to not mount the file system or we indicate a mount point different to root, then the file system will be created with no subvolumes. Afterwards, we can add subvolumes one by one. But, if we decide to mount the file system as root, then the list of subvolumes indicated in the control file for root is assigned to the file system.

## The *@* subvolume

Extracted from https://www.spinics.net/lists/linux-btrfs/msg44611.html:

> @ subvolume is set as the default subvolume. As you'd expect, it's
> mounted at / and used as such. The reason we use a separate subvolume
> is so we can easily implement our boot-and-rollback-from-snapshot
> functionality in SLE12. Having the root file system as a separate
> subvolume means we can move one of the snapshot subvolumes into the fs
> tree root, move the other @ subvolumes into that subvolume, and we
> have a rolled back system from which we can easily remove the
> now-unused root. If we didn't use a separate subvolume for it, it
> would make the rollback very complicated.

So, everything points to that the *@* subvolume hierarchy was introduced to ease the rollback from snapshots. This approach is currently used by both, SLE and openSUSE distributions, and the hierarchy tree looks like:

~~~
top level
|-- @
  |-- @/home
  |-- @/var
  |-- @/.snapshots
      |-- @/.snapshots/1/snapshot
      |-- @/.snapshots/2/snapshot (default)
~~~

But currently there is not a real advantage of having that specific hierarchy. Which really makes to replace the root subvolume easier is the fact of having root and the rest (home, var, etc) as separate subvolumes. In fact, other simpler hierarchies could be used, and restoring snapshots would be accomplished by exactly the same procedure. For example:

~~~
top level
|-- root
|   |-- .snapshots
|        |-- snapshot1
|        |-- snapshot2 (default)
|-- home
|-- var
~~~

Moreover, when snapper is configured during the installation, root is always installed in the *.snapshots/1/snapshot* subvolume, so *@* subvolume is actually not used in that scenario.

Maybe YaST should be agnostic to all this by simply allowing to define a subvolumes tree. For example, in the control file:

~~~
<partitioning>
  <volumes config:type="list">
    <volume>
      <mount_point>/</mount_point>
      <fs_type>btrfs</fs_type>
      <subvolumes config:type="list">
        <subvolume>
          <path>@</path>
          <default>true</default>
          <subvolumes config:type="list">
            <subvolume>
              <path>@/home</path>
              <mount_point>/home</mount_point>
            </subvolume>
            <subvolume>
              <path>@/opt</path>
              <mount_point>/opt</mount_point>
            </subvolume>
          </subvolumes>
        </subvolume>
      </subvolumes>
    </volume>
  </volumes>
</partitioning>
~~~

The Expert Partitioner should also allow to create nested subvolumes as well as to define the default one.

More information about the *@* subvolume can be found at:

* https://www.spinics.net/lists/linux-btrfs/msg44611.html

* https://unix.stackexchange.com/questions/491589/meaning-of-in-btrfs-pathnames

* https://lists.debian.org/debian-boot/2016/06/msg00003.html
