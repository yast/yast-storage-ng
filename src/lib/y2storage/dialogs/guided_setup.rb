# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage/disk_analyzer"
require "y2storage/refinements/size_casts"
require "y2storage/dialogs/guided_setup/select_disks"
require "y2storage/dialogs/guided_setup/select_root_disk"
require "y2storage/dialogs/guided_setup/select_scheme"
require "y2storage/dialogs/guided_setup/select_filesystem"

module Y2Storage
  module Dialogs
    # Class to control the guided setup workflow.
    # Calculates the proposal settings to be used in the next proposal attempt.
    class GuidedSetup
      Yast.import "Sequencer"

      using Y2Storage::Refinements::SizeCasts
      # @return [ProposalSettings] settings specified by the user
      attr_reader :settings
      attr_reader :devicegraph, :disks_data

      def initialize(devicegraph, settings)
        @devicegraph = devicegraph
        @settings = settings.dup
        @disks_data = read_disks_data
      end

      def run
        settings = @settings.dup

        aliases = {
          "select_disks"      => -> { SelectDisks.new(self, settings).run },
          "select_root_disk"  => -> { SelectRootDisk.new(self, settings).run },
          "select_scheme"     => -> { SelectScheme.new(self, settings).run },
          "select_filesystem" => -> { SelectFilesystem.new(self, settings).run }
        }

        sequence = {
          "ws_start"          => "select_disks",
          "select_disks"      => { next: "select_root_disk", back: :back, abort: :abort },
          "select_root_disk"  => { next: "select_scheme", back: :back, abort: :abort },
          "select_scheme"     => { next: "select_filesystem", back: :back,  abort: :abort },
          "select_filesystem" => { next: :next, back: :back,  abort: :abort }
        }

        result = Yast::Sequencer.Run(aliases, sequence)
        @settings = settings if result == :next
        result
      end

    protected

      def read_disks_data
        analyzer = Y2Storage::DiskAnalyzer.new(devicegraph)
        disks = analyzer.candidate_disks
        installed_systems = analyzer.installed_systems
        disks.map { |d| disk_data(d, installed_systems[d.name]) }
      end

      def disk_data(disk, installed_systems)
        label = ([disk.name, DiskSize.new(disk.size)] + installed_systems).join(", ")
        {
          name:  disk.name,
          label: label
        }
      end
    end
  end
end
