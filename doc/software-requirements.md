
yast2-packager uses storage functions only via wrapper_storage.rb.

wrapper_storage.rb is not only used in yast2-packager but also yast2-country.
yast2-country is already adapted to storage-ng so we can ignore this here.

wrapper_storage.rb provides five functions:

- GetTargetMap

  Used in SpaceCalculation.rb during installation to generate a list of
  devices with mount-point and free space. libstorage-ng has functions to
  query all filesystems including their type, mount-points and block devices.


- GetTargetChangeTime

  Used by the software proposal to not reset its state if only the storage
  setup has changed (software_proposal.rb, bsc#371875).

  A solution was already discussed on IRC:
  https://w3.suse.de/~shundhammer/storage-timer.txt

  An additional note: Using a wall clock time is error prone when the system
  time or timezone can be set (like it can be in YaST). A simple revision
  counter that is increased as explained in the link above is simpler and more
  robust.


- RemoveDmMapsTo

  Obsolete. Was used for EVMS which is not supported anymore.


- GetWinPrimPartitions

  Obsolete.


- ClassicStringToByte

  Function humanstring_to_byte() in libstorage-ng or some other functions can
  be called directly.

