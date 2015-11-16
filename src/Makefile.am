# Sources for storage

module_DATA = \
  modules/StorageControllers.rb \
  modules/StorageInit.rb \
  modules/StorageIcons.rb \
  modules/FileSystems.rb \
  modules/StorageUpdate.rb \
  modules/Storage.rb \
  modules/TabPanel.rb \
  modules/TreePanel.rb \
  modules/StorageSettings.rb \
  modules/Greasemonkey.rb \
  modules/MiniWorkflow.rb \
  modules/StorageProposal.rb \
  modules/DualMultiSelectionBox.rb \
  modules/StorageDevices.rb \
  modules/StorageFields.rb \
  modules/DevicesSelectionBox.rb \
  modules/Partitions.rb \
  modules/Region.rb \
  modules/StorageClients.rb \
  modules/StorageSnapper.rb

client_DATA = \
  clients/inst_disk_proposal.rb \
  clients/inst_resize_dialog.rb \
  clients/multipath-simple.rb \
  clients/inst_resize_ui.rb \
  clients/inst_disk.rb \
  clients/storage_finish.rb \
  clients/inst_custom_part.rb \
  clients/storage.rb \
  clients/inst_prepdisk.rb \
  clients/inst_target_part.rb \
  clients/partitions_proposal.rb \
  clients/disk_worker.rb \
  clients/inst_target_selection.rb \
  clients/disk.rb

yncludedir = @yncludedir@/partitioning
ynclude_DATA = \
  include/partitioning/ep-nfs.rb \
  include/partitioning/ep-import.rb \
  include/partitioning/ep-loop-dialogs.rb \
  include/partitioning/ep-settings.rb \
  include/partitioning/ep-lib.rb \
  include/partitioning/auto_part_create.rb \
  include/partitioning/lvm_lib.rb \
  include/partitioning/ep-raid-lib.rb \
  include/partitioning/custom_part_lib.rb \
  include/partitioning/ep-lvm-lib.rb \
  include/partitioning/ep-graph.rb \
  include/partitioning/ep-btrfs.rb \
  include/partitioning/ep-hd.rb \
  include/partitioning/custom_part_check_generated.rb \
  include/partitioning/auto_part_ui.rb \
  include/partitioning/ep-hd-dialogs.rb \
  include/partitioning/ep-log.rb \
  include/partitioning/ep-loop.rb \
  include/partitioning/lvm_pv_lib.rb \
  include/partitioning/ep-loop-lib.rb \
  include/partitioning/ep-dialogs.rb \
  include/partitioning/ep-raid-dialogs.rb \
  include/partitioning/auto_part_functions.rb \
  include/partitioning/ep-summary.rb \
  include/partitioning/lvm_lv_lib.rb \
  include/partitioning/ep-hd-lib.rb \
  include/partitioning/ep-all.rb \
  include/partitioning/partition_defines.rb \
  include/partitioning/ep-raid.rb \
  include/partitioning/ep-tmpfs-lib.rb \
  include/partitioning/ep-lvm-dialogs.rb \
  include/partitioning/auto_part_prepare.rb \
  include/partitioning/raid_lib.rb \
  include/partitioning/lvm_ui_dialogs.rb \
  include/partitioning/ep-btrfs-lib.rb \
  include/partitioning/ep-dm-lib.rb \
  include/partitioning/ep-main.rb \
  include/partitioning/ep-tmpfs.rb \
  include/partitioning/ep-btrfs-dialogs.rb \
  include/partitioning/ep-tmpfs-dialogs.rb \
  include/partitioning/ep-dm-dialogs.rb \
  include/partitioning/ep-dm.rb \
  include/partitioning/custom_part_dialogs.rb \
  include/partitioning/ep-unused.rb \
  include/partitioning/ep-lvm.rb \
  include/partitioning/custom_part_helptexts.rb

ylibdir = @ylibdir@/storage
ylib_DATA = \
  lib/storage/target_map_formatter.rb \
  lib/storage/used_storage_features.rb \
  lib/storage/storage_proposal.rb \
  lib/storage/disk_size.rb


scrconf_DATA = \
  scrconf/proc_partitions.scr \
  scrconf/sysconfig_storage.scr \
  scrconf/etc_cryptotab.scr \
  scrconf/etc_mtab.scr \
  scrconf/proc_swaps.scr \
  scrconf/proc_dasddev.scr

ybin_SCRIPTS = \
  bin/check.boot

ydata_DATA = \
  data/test_target_map.ycp \
  data/demo_target_map.ycp

desktop_DATA = \
  desktop/disk.desktop

fillup_DATA = \
  fillup/sysconfig.storage-yast2-storage

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(ybin_SCRIPTS) $(ydata_DATA) $(desktop_DATA) $(fillup_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common
