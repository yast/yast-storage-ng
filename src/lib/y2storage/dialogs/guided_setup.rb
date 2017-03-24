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
require "y2storage/dialogs/guided_setup/select_disks"
require "y2storage/dialogs/guided_setup/select_root_disk"
require "y2storage/dialogs/guided_setup/select_scheme"
require "y2storage/dialogs/guided_setup/select_filesystem"

module Y2Storage
  module Dialogs
    class GuidedSetup

      Yast.import "Sequencer"

      attr_accessor :settings_stack
      attr_reader :settings

      def initialize(settings)
        @settings_stack = []
        @settings = settings.dup
      end

      def run
        @settings_stack = [settings.dup]        

        aliases = {
          "select_disks" => lambda { SelectDisks.new(self).run },
          "select_root_disk" => lambda { SelectRootDisk.new(self).run },
          "select_scheme" => lambda { SelectScheme.new(self).run },
          "select_filesystem" => lambda { SelectFilesystem.new(self).run }
        }

        sequence = {
          "ws_start" => "select_disks",
          "select_disks" => { next: "select_root_disk", back: :back, abort: :abort },
          "select_root_disk" => { next: "select_scheme", back: :back,  abort: :abort },
          "select_scheme" => { next: "select_filesystem", back: :back,  abort: :abort },
          "select_filesystem" => { next: :next, back: :back,  abort: :abort },
        }

        result = Yast::Sequencer.Run(aliases, sequence)
        update_settings!
        require "byebug"; byebug
        result
      end

    private

      def update_settings!
        @settings = settings_stack.last unless settings_stack.empty?
      end
    end
  end
end
