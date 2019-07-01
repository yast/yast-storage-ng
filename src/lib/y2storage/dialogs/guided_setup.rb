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
require "y2storage/proposal_settings"
require "y2storage/dialogs/guided_setup/select_disks"
require "y2storage/dialogs/guided_setup/select_root_disk"
require "y2storage/dialogs/guided_setup/select_scheme"
require "y2storage/dialogs/guided_setup/select_filesystem"
require "y2storage/partitioning_features"

Yast.import "Wizard"
Yast.import "Sequencer"

module Y2Storage
  module Dialogs
    # Class to control the guided setup workflow.
    #
    # Calculates the proposal settings to be used in the next proposal attempt.
    class GuidedSetup
      extend PartitioningFeatures

      class << self
        # Whether is is allowed to use the Guided Setup
        #
        # @return [Boolean]
        def allowed?
          settings_editable?
        end

        # Whether the Guided Setup can be shown
        #
        # @note Even when the "proposal_settings_editable" from control file is set to not allow
        #   to edit the proposal settings, the Guided Setup can still be used to select in which
        #   disks to install (two first steps of the Guided Setup).
        #
        # @param disk_analyzer [DiskAnalyzer]
        # @return [Boolean]
        def can_be_shown?(disk_analyzer)
          allowed? || disk_analyzer.candidate_disks.size > 1
        end

        private

        # Whether the proposal settings are set as editable in the control file
        #
        # @see PartitioningFeatures#feature
        #
        # @return [Boolean]
        def settings_editable?
          editable = feature(:proposal, :proposal_settings_editable)
          editable.nil? ? true : editable
        end
      end

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
        aliases = {
          "select_disks"      => -> { run_dialog(SelectDisks) },
          "select_root_disk"  => -> { run_dialog(SelectRootDisk) },
          "select_scheme"     => -> { run_dialog(SelectScheme) },
          "select_filesystem" => -> { run_dialog(select_filesystem_class) }
        }

        common_actions = { back: :back, cancel: :cancel, abort: :abort }

        sequence = {
          "ws_start"          => "select_disks",
          "select_disks"      => common_actions.merge(next: "select_root_disk"),
          "select_root_disk"  => common_actions.merge(next: "select_scheme"),
          "select_scheme"     => common_actions.merge(next: "select_filesystem"),
          "select_filesystem" => common_actions.merge(next: :next)
        }

        Yast::Wizard.OpenNextBackDialog
        Yast::Wizard.SetAbortButton(:cancel, Yast::Label.CancelButton)

        Yast::Sequencer.Run(aliases, sequence)
      ensure
        Yast::Wizard.CloseDialog
      end

      # Whether is is allowed to use the Guided Setup
      #
      # @see GuidedSetup.allowed?
      #
      # @return [Boolean]
      def allowed?
        GuidedSetup.allowed?
      end

      private

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

      # Subclass of {SelectFilesystem::Base} that must be used
      def select_filesystem_class
        settings.ng_format? ? SelectFilesystem::Ng : SelectFilesystem::Legacy
      end
    end
  end
end
