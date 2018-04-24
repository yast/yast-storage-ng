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
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/overview"
require "y2partitioner/exceptions"
require "y2partitioner/dialogs/summary"

Yast.import "Label"
Yast.import "Mode"
Yast.import "Popup"
Yast.import "Hostname"

module Y2Partitioner
  module Dialogs
    # Main entry point to Partitioner showing tree pager with all content
    class Main < CWM::Dialog
      # @return [Y2Storage::Devicegraph] device graph with all changes done in dialog
      attr_reader :device_graph

      # Constructor
      #
      # @param system [Y2Storage::Devicegraph] system graph (devices on disk)
      # @param initial [Y2Storage::Devicegraph] starting point (initial device graph
      #   to display)
      def initialize(system, initial)
        textdomain "storage"

        # Initial graph is saved to know if something has changed at the end.
        @initial_graph = initial

        UIState.create_instance
        DeviceGraphs.create_instance(system, initial)
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
        [:redraw, :reprobe]
      end

      def back_button
        # do not show back button when running on running system. See CWM::Dialog.back_button
        Yast::Mode.installation ? nil : ""
      end

      def next_button
        Yast::Mode.installation ? Yast::Label.AcceptButton : next_label_for_installed_system
      end

      # Runs the dialog
      #
      # @note When running in an installed system, a last step is shown with the summary of
      #   changes, see {#need_summary?} and {#run_summary}.
      #
      # @return [Symbol] result of the dialog
      def run
        result = nil

        loop do
          result = super

          if result == :next && need_summary?
            result = run_summary
          end

          @initial_graph = current_graph if result == :reprobe

          break unless continue_running?(result)
        end

        @device_graph = current_graph
        result
      rescue Y2Partitioner::ForcedAbortError
        :abort
      end

    protected

      # @return [Y2Storage::Devicegraph]
      attr_reader :initial_graph

      # Checks whether the dialog should be rendered again
      #
      # @return [Boolean]
      def continue_running?(result)
        if result == :redraw
          true
        elsif result == :reprobe
          true
        elsif result == :abort && Yast::Mode.installation
          !Yast::Popup.ConfirmAbort(:painless)
        else
          false
        end
      end

      # Whether it is needed to show the summary of changes as last step
      #
      # The summary is only shown in an installed system and when the user has done
      # any change.
      #
      # @return [Boolean]
      def need_summary?
        !Yast::Mode.installation && system_edited?
      end

      # Runs the summary dialog
      #
      # When the user goes back, the Partitioner dialog should be redrawn.
      #
      # @return [Symbol] dialog result
      def run_summary
        summary_result = Dialogs::Summary.run
        summary_result == :back ? :redraw : summary_result
      end

      # Whether the system has been edited
      #
      # The system is considered as edited when the user has modified the devices
      # or the Partitioner settings.
      #
      # @return [Boolean]
      def system_edited?
        partitioner_settings_edited? || devices_edited?
      end

      # TODO: There is a PBI to add the settings modifications to the summary.
      #
      # Whether the Partitioner settings were modified by the user
      #
      # @return [Boolean]
      def partitioner_settings_edited?
        false
      end

      # Whether the devices were modified by the user
      #
      # @return [Boolean]
      def devices_edited?
        current_graph != initial_graph
      end

      # Current devicegraph with all the modifications
      #
      # @return [Y2Storage::Devicegraph]
      def current_graph
        DeviceGraphs.instance.current
      end

      # Hostname of the current system.
      #
      # Getting the hostname is sometimes a little bit slow, so the value is
      # cached to be reused in every dialog redraw
      #
      # @return [String]
      def hostname
        @hostname ||= Yast::Hostname.CurrentHostname
      end

      # Label for next button when running in an installed system
      #
      # The label is "Next" when there are changes or "Finish" otherwise.
      #
      # @return [String]
      def next_label_for_installed_system
        system_edited? ? Yast::Label.NextButton : Yast::Label.FinishButton
      end
    end
  end
end
