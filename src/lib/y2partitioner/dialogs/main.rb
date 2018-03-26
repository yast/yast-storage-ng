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

Yast.import "Label"
Yast.import "Mode"
Yast.import "Popup"
Yast.import "Hostname"

module Y2Partitioner
  module Dialogs
    # main entry point to partitioner showing tree pager with all content
    class Main < CWM::Dialog
      # @return [Y2Storage::DeviceGraph] device graph with all changes done in dialog
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

      # runs dialog.
      # @param system [Y2Storage::DeviceGraph] system graph used to detect if something
      # is going to be formatted
      # @param initial [Y2Storage::DeviceGraph] device graph to display
      # @return [Symbol] result of dialog
      def run(system, initial)
        DeviceGraphs.create_instance(system, initial)
        UIState.create_instance
        res = nil
        loop do
          res = super()

          next if res == :redraw
          if res == :abort && Yast::Mode.installation
            next unless Yast::Popup.ConfirmAbort(:painless)
          end

          break
        end
        @device_graph = DeviceGraphs.instance.current

        res
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
    end
  end
end
