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
require "y2storage/dialogs/guided_setup/select_disks"
require "y2storage/dialogs/guided_setup/select_root_disk"
require "y2storage/dialogs/guided_setup/select_scheme"
require "y2storage/dialogs/guided_setup/select_filesystem"

Yast.import "Sequencer"

module Y2Storage
  module Dialogs
    # Class to control the guided setup workflow.
    #
    # Calculates the proposal settings to be used in the next proposal attempt.
    class GuidedSetup
      # Settings specified by the user
      attr_reader :settings
      # Disk analyzer to recover disks info
      attr_reader :analyzer

      def initialize(settings, analyzer)
        @settings = settings.dup
        @analyzer = analyzer
      end

      # Executes steps of the wizard.
      # @return [Symbol] last step result.
      def run
        aliases = {
          "select_disks"      => -> { run_dialog(SelectDisks) },
          "select_root_disk"  => -> { run_dialog(SelectRootDisk) },
          "select_scheme"     => -> { run_dialog(SelectScheme) },
          "select_filesystem" => -> { run_dialog(SelectFilesystem) }
        }

        sequence = {
          "ws_start"          => "select_disks",
          "select_disks"      => { next: "select_root_disk", back: :back, abort: :abort },
          "select_root_disk"  => { next: "select_scheme", back: :back, abort: :abort },
          "select_scheme"     => { next: "select_filesystem", back: :back,  abort: :abort },
          "select_filesystem" => { next: :next, back: :back,  abort: :abort }
        }

        Yast::Sequencer.Run(aliases, sequence)
      end

    private

      # Run the dialog or skip when necessary.
      def run_dialog(dialog_class)
        dialog = dialog_class.new(self)
        if dialog.skip?
          dialog.before_skip
        else
          @result = dialog.run
        end
        @result ||= :next
      end
    end
  end
end
