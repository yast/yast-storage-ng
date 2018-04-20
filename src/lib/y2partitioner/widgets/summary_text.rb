# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "cwm"
require "y2storage/actions_presenter"
require "y2partitioner/device_graphs"

Yast.import "HTML"
Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # Interactive RichText widget to display the installation summary
    class SummaryText < CWM::RichText
      include Yast::I18n

      # Constructor
      def initialize
        textdomain "storage"

        # Needed to delegate events to the inner ActionsPresenter object
        self.handle_all_events = true
      end

      # @macro seeAbstractWidget
      def init
        calculate_actions
        calculate_packages if packages_info?
        refresh_value
      end

      # @macro seeAbstractWidget
      def handle(event)
        id = event["ID"]
        return nil unless id
        return nil unless actions.can_handle?(id)

        actions.update_status(id)
        refresh_value
        nil
      end

      # @macro seeAbstractWidget
      def help
        Yast::Mode.installation ? help_installation : help_installed_system
      end

    private

      # Object to manage the list of actions
      # @return [Y2Storage::ActionsPresenter]
      attr_reader :actions

      # Names of the packages that need to be installed
      # @return [Array<String>]
      attr_reader :packages

      # Whether the text should include information about the packages to
      # install
      #
      # @return [Boolean]
      def packages_info?
        Yast::Mode.installation
      end

      # Updates the widget content
      def refresh_value
        self.value = summary_text
      end

      # Updates the value of {#actions}
      #
      # @note Actions are calculated with the raw probed devicegraph as starting point
      #   (see {Y2Storage::StorageManager#raw_probed}).
      def calculate_actions
        actiongraph = current_graph.actiongraph
        @actions = Y2Storage::ActionsPresenter.new(actiongraph)
      end

      # Updates the value of {#packages}
      def calculate_packages
        handler = Y2Storage::PackageHandler.new
        handler.add_feature_packages(current_graph)
        @packages = handler.pkg_list.uniq
      end

      # @return [Y2Storage::Devicegraph]
      def current_graph
        DeviceGraphs.instance.current
      end

      # @return [Y2Storage::Devicegraph]
      def system_graph
        DeviceGraphs.instance.system
      end

      # Updated HTML content to display
      #
      # @return [String]
      def summary_text
        if packages_info?
          partitioning_text + packages_text
        else
          partitioning_text
        end
      end

      # Section of {#summary_text} about actions
      #
      # @return [String]
      def partitioning_text
        if actions.empty?
          Yast::HTML.Heading(_("<p>No changes to partitioning.</p>"))
        else
          Yast::HTML.Heading(_("<p>Changes to partitioning:</p>")) + actions.to_html
        end
      end

      # Section of {#summary_text} about packages to install
      #
      # @return [String]
      def packages_text
        if packages.empty?
          Yast::HTML.Heading(_("<p>No packages need to be installed.</p>"))
        else
          Yast::HTML.Heading(_("<p>Packages to install:</p>")) + Yast::HTML.List(packages)
        end
      end

      # Help during installation
      #
      # @return [String]
      def help_installation
        _("<p><b>Installation Summary:</b> " \
          "This shows the actions that will be performed " \
          "when you confirm the installation. " \
          "Until then, nothing is changed on your system." \
          "</p>")
      end

      # Help in an installed system
      #
      # @return [String]
      def help_installed_system
        _("<p><b>Installation Summary:</b> " \
          "This shows the actions that will be performed " \
          "when you finish the partitioner. " \
          "So far, nothing has been changed yet on your system." \
          "</p>")
      end
    end
  end
end
