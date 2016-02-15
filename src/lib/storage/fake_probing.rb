#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "storage"
require_relative "storage_manager"

# This file can be invoked separately for minimal testing.

module Yast
  module Storage
    #
    # Class to build faked device graphs in libstorage instead of doing real
    # hardware probing. This can be used to create device graphs from YaML
    # files or directly with libstorage calls. The objective is to achieve
    # broader test coverage with faked hardware setups that would be difficult
    # to set up with real hardware, much less with virtualized hardware.
    #
    # An instance of this class must be created before any other libstorage
    # calls to make sure it is properly initialized, i.e. without real hardware
    # probing.
    #
    class FakeProbing
      include Yast::Logger

      PROBED = "probed"
      FAKE   = "fake"

      attr_reader :devicegraph

      def initialize
        @storage     = init_storage
        @devicegraph = @storage.create_devicegraph(FAKE)
      end

      # Initialize libstorage with a fake environment.
      #
      def init_storage
        StorageManager::create_instance(fake_storage_env)
      end

      # Create a Storage::Environment suitable for fake device graphs,
      # i.e. without real hardware probing.
      #
      # @return [::Storage::Environment] fake environment
      #
      def fake_storage_env
        read_only   = false
        probe_mode  = ::Storage::ProbeMode_NONE
        target_mode = ::Storage::TargetMode_DIRECT
        ::Storage::Environment.new(read_only, probe_mode, target_mode)
      end

      # Copy the fake device graph to the probed device graph.
      #
      # This should usually be the last step after creating all desired devices
      # in the fake device graph before beginning the real tests with the
      # storage proposal etc.
      #
      def to_probed
        @storage.remove_devicegraph(PROBED) if @storage.exist_devicegraph(PROBED)
        @storage.copy_devicegraph(FAKE, PROBED)
      end

      # Debugging: Dump all disks of 'devicegraph' to stdout.
      #
      def dump_disks(devicegraph = nil)
        devicegraph ||= @devicegraph
        disks = devicegraph.all_disks.to_a
        disks.each { |disk| puts("Found disk #{disk.name}") }
      end
    end
  end
end


# if used standalone, do a minimalistic test case

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  fake_probing = Yast::Storage::FakeProbing.new
  devicegraph = fake_probing.devicegraph
  sdx = ::Storage::Disk.create(devicegraph, "/dev/sdx")
  sdy = ::Storage::Disk.create(devicegraph, "/dev/sdy")
  sdz = ::Storage::Disk.create(devicegraph, "/dev/sdz")
  fake_probing.to_probed
  puts("Probed disks:")
  fake_probing.dump_disks(Yast::Storage::StorageManager.instance.probed)
end
