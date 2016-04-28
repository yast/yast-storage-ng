#!/usr/bin/env ruby

require "yast"	# changes $LOAD_PATH

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "storage/storage_manager"
require "storage/patches"
require "pp"

sm = Yast::Storage::StorageManager.fake_from_yaml()

dg = sm.create_devicegraph("xxx")

dd = ::Storage::Disk.create(dg, "/dev/sdX")
dd.size = 1024*1024*1024;

dp = dd.create_partition_table(::Storage::PtType_MSDOS)

puts "--- 1"

sl = dp.unused_partition_slots
pp sl

r1 = sl.first.region
r1.length = Yast::Storage::DiskSize.MiB(100).size / r1.block_size
pp r1

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

puts dd.inspect
puts dp.inspect



