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
require "set"
require "pp"

# This file can be invoked separately for minimal testing.
# Use 'sudo' if you do that since it will do hardware probing with libstorage.

module Yast
  module Storage
    #
    # Storage proposal for installation: Class that can suggest how to create
    # or change partitions for a Linux system installation based on available
    # storage devices (disks) and certain configuration parameters.
    #
    class Proposal
      include Yast::Logger

      # User-configurable settings for the storage proposal.
      class Settings
        attr_accessor :use_lvm, :encrypt_volume_group
        attr_accessor :root_filesystem_type, :enable_snapshots
        attr_accessor :use_separate_home, :home_filesystem_type
        attr_accessor :enlarge_swap_for_suspend

        def initialize
          @use_lvm = false
          @encrypt_volume_group = false
          @root_filesystem_type = :Btrfs
          @enable_snapshots = true
          @use_separate_home = true
          @home_filesystem_type = :XFS
          @enlarge_swap_for_suspend = false
        end
      end

      attr_accessor :settings

      def initialize
        @settings = Settings.new
        @proposal = ""
      end

      def propose
        "No disks found - no storage proposal possible"
      end
    end
  end
end

# if used standalone, do a minimalistic test case

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  proposal = Yast::Storage::Proposal.new
  proposal.settings.root_filesystem_type = :XFS
  proposal.settings.use_separate_home = false
  pp proposal
end
