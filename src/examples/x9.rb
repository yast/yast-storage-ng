#!/usr/bin/env ruby

require "yast"	# changes $LOAD_PATH

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "storage/storage_manager"
require "storage/patches"
require "storage/yaml_writer"
require "pp"

sm = Yast::Storage::StorageManager.fake_from_yaml()

dg = sm.create_devicegraph("xxx")

r_all = ::Storage::Region.new(0, 2 * ::Storage.GiB / 512, 512)
dd = ::Storage::Disk.create(dg, "/dev/sdX", r_all)

dd.topology = ::Storage::Topology.new(0, 512)
dd.topology.minimal_grain = 512
pp dd.topology

dp = dd.create_partition_table(::Storage::PtType_MSDOS)
if ::Storage.msdos?(dp)
  ::Storage.to_msdos(dp).minimal_mbr_gap = 512*5;
end

puts "--- 1"

sl = dp.unused_partition_slots
pp sl

r1 = sl.first.region
r1.length = Yast::Storage::DiskSize.MiB(100).size / r1.block_size
#r1.start = 256
pp r1
#r1 = dd.topology.align(r1, ::Storage::AlignPolicy_KEEP_SIZE)
#puts "aligned"
#pp r1

dp.create_partition("/dev/sdX1", r1, ::Storage::PartitionType_PRIMARY)

puts dd.inspect
puts dp.inspect

puts "--- 2"

sl = dp.unused_partition_slots
pp sl

r1 = sl.first.region
r1.length = Yast::Storage::DiskSize.MiB(500).size / r1.block_size
pp r1

dp.create_partition("/dev/sdX2", r1, ::Storage::PartitionType_EXTENDED)

puts dd.inspect
puts dp.inspect

puts "--- 3"

sl = dp.unused_partition_slots
pp sl

r1 = sl.first.region
r1.length = Yast::Storage::DiskSize.MiB(100).size / r1.block_size
pp r1

dp.create_partition("/dev/sdX3", r1, ::Storage::PartitionType_PRIMARY)

puts dd.inspect
puts dp.inspect

puts "--- 4"

sl = dp.unused_partition_slots
pp sl

r1 = (sl.find { |x| x.logical_slot }).region
r1.length = Yast::Storage::DiskSize.MiB(100).size / r1.block_size
pp r1

dp.create_partition("/dev/sdX4", r1, ::Storage::PartitionType_LOGICAL)

pp dd
pp dp

Yast::Storage::YamlWriter.write(dg, "/dev/stdout");

