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
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/widgets/btrfs_subvolumes_add_button"
require "y2partitioner/widgets/btrfs_subvolumes_delete_button"
require "y2partitioner/device_graphs"

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # Widget to manage btrfs subvolumes of a specific filesystem
    #
    # FIXME: How to handle events directly from a CWM::Dialog ?
    # Events for :help and :cancel buttons should be managed from the dialog,
    # for example to show a popup with the help.
    class BtrfsSubvolumes < CWM::CustomWidget
      attr_reader :filesystem

      # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
      def initialize(filesystem)
        textdomain "storage"

        @filesystem = filesystem
        self.handle_all_events = true
      end

      # FIXME: The help handle does not work without wizard
      #
      # This handle should belongs to the dialog
      # @see Dialogs::BtrfsSubvolumes
      def handle(event)
        handle_help if event["ID"] == :help
        nil
      end

      def contents
        table = Widgets::BtrfsSubvolumesTable.new(filesystem)

        VBox(
          table,
          HBox(
            Widgets::BtrfsSubvolumesAddButton.new(table),
            Widgets::BtrfsSubvolumesDeleteButton.new(table)
          )
        )
      end

      def help
        _("<p>Create and remove subvolumes from a Btrfs filesystem.</p>\n")
      end

    private

      # Show help of all widgets that belong to its content
      # FIXME: this should belongs to the dialog
      # @see Dialogs::BtrfsSubvolumes
      def handle_help
        text = []
        Yast::CWM.widgets_in_contents([self]).each do |widget|
          text << widget.help if widget.respond_to?(:help)
        end
        Yast::Wizard.ShowHelp(text.join("\n"))
      end
    end
  end
end
