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
require "y2partitioner/actions/quit_partitioner"

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

        UIState.create_instance
        DeviceGraphs.create_instance(system, initial)
      end

      def title
        _("Expert Partitioner")
      end

      def contents
        # NOTE: Since this method is used as first parameter of {Yast::CWM.show} every time that
        # {#run} calls `super`, a new {OverviewTreePager} will be created in every dialog redraw.
        # So, let's keep a reference to it in the {UIState} to query the open items and preserve
        # their state in new instances.
        overview_tree_pager = Widgets::OverviewTreePager.new(hostname)
        UIState.instance.overview_tree_pager = overview_tree_pager

        MarginBox(
          0.5,
          0.5,
          overview_tree_pager
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
        Yast::Mode.installation ? Yast::Label.AcceptButton : next_label_for_installed_system
      end

      def abort_button
        Yast::Mode.installation ? Yast::Label.CancelButton : Yast::Label.AbortButton
      end

      # @see Actions::QuitPartitioner#quit?
      #
      # @return [Boolean] it aborts if returns true
      def abort_handler
        Actions::QuitPartitioner.new.quit?
      end

      # @see Actions::QuitPartitioner#quit?
      #
      # @return [Boolean] it goes back if returns true
      def back_handler
        Actions::QuitPartitioner.new.quit?
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

          break unless continue_running?(result)
        end

        @device_graph = current_graph
        dialog_result(result)
      rescue Y2Partitioner::ForcedAbortError
        :abort
      end

    protected

      # Checks whether the dialog should be rendered again
      #
      # @return [Boolean]
      def continue_running?(result)
        result == :redraw
      end

      # Result of the dialog
      #
      # During installation, abort means going back.
      #
      # @param result [Symbol] original result (e.g., :next, :back, :abort)
      # @return [Symbol]
      def dialog_result(result)
        return result unless Yast::Mode.installation

        result == :abort ? :back : result
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

      # Whether the system has been edited (devices or settings)
      #
      # TODO: add check for modifications in Partitioner settings
      #
      # @return [Boolean]
      def system_edited?
        DeviceGraphs.instance.devices_edited?
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
