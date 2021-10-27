# Copyright (c) [2017-2021] SUSE LLC
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
require "y2storage/disk_analyzer"
require "y2storage/proposal_settings"
require "y2storage/dialogs/guided_setup/select_disks"
require "y2storage/dialogs/guided_setup/select_volumes_disks"
require "y2storage/dialogs/guided_setup/select_root_disk"
require "y2storage/dialogs/guided_setup/select_partition_actions"
require "y2storage/dialogs/guided_setup/select_scheme"
require "y2storage/dialogs/guided_setup/select_filesystem"

Yast.import "Wizard"
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

      # Executes steps of the wizard. A new wizard dialog is opened, where
      # the Abort button is replaced by Cancel.
      #
      # @return [Symbol] Last step result
      def run
        Yast::Wizard.OpenNextBackDialog
        Yast::Wizard.SetAbortButton(:cancel, Yast::Label.CancelButton)

        Yast::Sequencer.Run(aliases, sequence)
      ensure
        Yast::Wizard.CloseDialog
      end

      private

      def aliases
        {
          "select_disks"             => -> { run_dialog(SelectDisks) },
          "select_volumes_disks"     => -> { run_dialog(SelectVolumesDisks) },
          "select_root_disk"         => -> { run_dialog(SelectRootDisk) },
          "select_scheme"            => -> { run_dialog(SelectScheme) },
          "select_filesystem"        => -> { run_dialog(SelectFilesystem) },
          "select_partition_actions" => -> { run_dialog(SelectPartitionActions) }
        }
      end

      def sequence
        steps =
          case settings.allocate_volume_mode
          when :auto
            ["select_disks", "select_root_disk", "select_scheme", "select_filesystem"]
          when :device
            ["select_scheme", "select_filesystem", "select_volumes_disks",
             "select_partition_actions"]
          end

        sequence_for(steps)
      end

      # Generates the sequence based on given steps
      #
      # @example
      #   sequence_for(["first_step", "second_step", "third_step"]) #=> {
      #     "ws_start"    => "first_step",
      #     "first_step"  => { back: back, cancel: :cancel, abort: :abort, next: "second_step" }
      #     "second_step" => { back: back, cancel: :cancel, abort: :abort, next: "third_step" }
      #     "third_step"  => { back: back, cancel: :cancel, abort: :abort, next: :next }
      #   }
      #
      # @param steps [Array<String>]
      # @return [Hash] generated sequence
      def sequence_for(steps)
        common_actions = { back: :back, cancel: :cancel, abort: :abort }

        sequence = { "ws_start" => steps.first }

        steps.each_with_index do |step, idx|
          next_step = steps[idx + 1] || :next
          sequence[step] = common_actions.merge(next: next_step)
        end

        sequence
      end

      # Run the dialog or skip when necessary.
      def run_dialog(dialog_class)
        dialog = dialog_class.new(self)
        if dialog.skip?
          dialog.before_skip
        else
          result = dialog.run
        end
        result || :next
      end
    end
  end
end
