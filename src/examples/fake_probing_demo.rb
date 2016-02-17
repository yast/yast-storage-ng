#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require "storage/fake_probing.rb"

fake_probing = Yast::Storage::FakeProbing.new
devicegraph = fake_probing.devicegraph
sdx = ::Storage::Disk.create(devicegraph, "/dev/sdx")
sdy = ::Storage::Disk.create(devicegraph, "/dev/sdy")
sdz = ::Storage::Disk.create(devicegraph, "/dev/sdz")
fake_probing.to_probed
puts("Probed disks:")
fake_probing.dump_disks(Yast::Storage::StorageManager.instance.probed)
