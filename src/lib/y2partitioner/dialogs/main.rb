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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "cwm/dialog"
require "yast2/popup"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/overview"
require "y2partitioner/exceptions"
require "y2storage/partitioning_features"

Yast.import "Label"
Yast.import "Mode"
Yast.import "Popup"
Yast.import "Hostname"

module Y2Partitioner
  module Dialogs
    # Main entry point to Partitioner showing tree pager with all content
    class Main < CWM::Dialog
      include Y2Storage::PartitioningFeatures

      # @return [Y2Storage::Devicegraph] device graph with all changes done in dialog
      attr_reader :device_graph

      def initialize
        textdomain "storage"
      end

      def title
        _("Expert Partitioner")
      end

      def contents
        MarginBox(
          0.5,
          0.5,
          Widgets::OverviewTreePager.new(hostname)
        )
      end

      def skip_store_for
        [:redraw]
      end

      def back_button
        # do not show back button when running on running system. See CWM::Dialog.back_button
        Yast::Mode.installation ? nil : ""
      end

      def next_button
        Yast::Mode.installation ? Yast::Label.AcceptButton : Yast::Label.FinishButton
      end

      # Runs the dialog
      #
      # @param system [Y2Storage::Devicegraph] system graph used to detect if something
      #   is going to be formatted.
      # @param initial [Y2Storage::Devicegraph] device graph to display.
      #
      # @return [Symbol] result of the dialog.
      def run(system, initial)
        UIState.create_instance
        DeviceGraphs.create_instance(system, initial)

        return :back unless run_partitioner?

        result = nil

        loop do
          result = super()
          break unless continue_running?(result)
        end

        @device_graph = DeviceGraphs.instance.current
        result
      rescue Y2Partitioner::ForcedAbortError
        :abort
      end

    protected

      # Hostname of the current system.
      #
      # Getting the hostname is sometimes a little bit slow, so the value is
      # cached to be reused in every dialog redraw
      #
      # @return [String]
      def hostname
        @hostname ||= Yast::Hostname.CurrentHostname
      end

      # Whether the Partitioner should be run
      #
      # @note Before running the partitioner a warning can be show. In that case,
      #   the Partitioner should only be run if the user accepts the warning.
      #
      # @return [Boolean]
      def run_partitioner?
        !show_partitioner_warning? || partitioner_warning == :continue
      end

      # Checks whether the dialog should be rendered again
      #
      # @return [Boolean]
      def continue_running?(result)
        if result == :redraw
          true
        elsif result == :abort && Yast::Mode.installation
          !Yast::Popup.ConfirmAbort(:painless)
        else
          false
        end
      end

      # Whether the Partitioner warning should be shown
      #
      # @note This option is configured in the control file,
      #   see {Y2Storage::PartitioningFeatures#feature}.
      #
      # @return [Boolean]
      def show_partitioner_warning?
        show_warning = feature(:expert_partitioner_warning)
        show_warning.nil? ? false : show_warning
      end

      # Popup to alert the user about the usage of the Partitioner
      #
      # @return [Symbol] user's answer (:yes, :no)
      def partitioner_warning
        # Warning popup about using the expert partitioner
        message = _(
          "This is for experts only.\n" \
          "You might lose support if you use this!\n\n" \
          "Please refer to the manual to make sure your custom\n" \
          "partitioning meets the requirements of this product."
        )

        Yast2::Popup.show(message, headline: :warning, buttons: :continue_cancel, focus: :cancel)
      end
    end
  end
end
