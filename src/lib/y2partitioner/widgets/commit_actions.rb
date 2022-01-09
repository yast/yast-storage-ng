# Copyright (c) [2020] SUSE LLC
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

require "cwm"

require "y2storage/storage_manager"
require "y2storage/callbacks/commit"
require "y2storage/used_filesystems"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Widgets
    # Widget to show the actions being performed over the system during the commit phase
    #
    # @example
    #
    #   widget = CommitActions.new
    #   widget.add_action("performing action 1")
    class CommitActions < CWM::CustomWidget
      # Constructor
      def initialize
        super
        self.handle_all_events = true

        @performed_actions = []
      end

      # Shows a box with the performed actions and an progress bar
      def contents
        @contents ||= VBox(
          actions_widget,
          progress_bar_widget
        )
      end

      # Performs the commit action and updates the widget
      #
      # Note that storage manager receives a callbacks. That callbacks updates the widget content every
      # time an action is performed by libstorage-ng.
      #
      # @see Y2Storage::StorageManager#commit
      # @see Y2Storage::Callbacks::Commit
      def init
        Y2Storage::StorageManager.instance.commit(callbacks: callbacks)
        Y2Storage::UsedFilesystems.new(Y2Storage::StorageManager.instance.staging).write
      end

      # An event is auto-sent after initializing the widget, see {#init}. Here, the workflow is returned
      # to the dialog just after initializing the widget. This is done to auto-close the dialog once the
      # commit action has finished.
      def handle
        :ok
      end

      # Adds a new action
      #
      # The new action is shown in the list of already performed actions. Moreover, the progress bar is
      # moved forward accordingly.
      #
      # @param action [String] action being performed
      def add_action(action)
        performed_actions << action

        refresh
      end

      private

      # Already performed actions, see {#add_action}
      #
      # @return [Array<String>]
      attr_accessor :performed_actions

      # Widget to show the list of performed actions
      #
      # @return [Actions]
      def actions_widget
        @actions_widget ||= Actions.new
      end

      # Progress bar widget
      #
      # @return [ProgressBar]
      def progress_bar_widget
        @progress_bar_widget ||= ProgressBar.new(planned_actions.size)
      end

      # Updates the content of the widget (list of actions and progress bar)
      def refresh
        actions_widget.value = performed_actions

        progress_bar_widget.forward
      end

      # Actions that will be performed
      #
      # @return [Array<String>]
      def planned_actions
        @planned_actions ||= DeviceGraphs.instance.current.actiongraph.commit_actions_as_strings
      end

      # Callbacks to use when committing changes
      #
      # @return [Y2Storage::Callbacks::Commit]
      def callbacks
        @callbacks ||= Y2Storage::Callbacks::Commit.new(widget: self)
      end

      # Widget to list the list of performed actions
      class Actions < CWM::RichText
        # The widget auto-scrolls when there are quite many actions
        def opt
          [:autoScrollDown]
        end

        # @param actions [Array<String>]
        def value=(actions)
          text = actions.join("<br />")

          super(text)
        end
      end

      # Widget for the progress bar
      class ProgressBar < CWM::DynamicProgressBar
        # Constructor
        #
        # @param steps_count [Integer] total number of steps
        def initialize(steps_count)
          super()

          @steps_count = steps_count
        end

        # @return [Integer]
        attr_reader :steps_count

        # No label
        def label
          ""
        end
      end
    end
  end
end
