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
require "cwm/common_widgets"
require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Select a partition table type (GPT, MS-DOS, DASD)
    # Part of {Actions::CreatePartitionTable}.
    class PartitionTableType < Base
      # Choose partition table type
      class TypeChoice < CWM::RadioButtons
        # @param controller [Actions::Controllers::PartitionTable]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
          @supported_types = controller.possible_partition_table_types.map(&:to_s)
          log.info("Supported partition table types: #{@supported_types}")
        end

        # @macro seeAbstractWidget
        def label
          _("New Partition Table Type")
        end

        # @macro seeAbstractWidget
        def help
          # helptext
          _("<p>Choose the partition table type for the new partition.</p>")
        end

        def items
          user_texts = {
            # radio button text for a partition table type
            "gpt"   => _("&GPT"),
            "msdos" => _("&MS-DOS (Classic PC Style)"),
            "dasd"  => _("&DASD")
          }

          @supported_types.map do |type|
            user_text = user_texts[type] || type
            [type, user_text]
          end
        end

        # @macro seeAbstractWidget
        def validate
          !value.nil?
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.default_partition_table_type.to_s
        end

        # @macro seeAbstractWidget
        def store
          @controller.type = Y2Storage::PartitionTables::Type.new(value)
        end
      end

      # @param controller [Actions::Controllers::Partition]
      #   partition controller collecting data for a partition to be created
      def initialize(controller)
        @disk_name = controller.disk_name
        @controller = controller
        textdomain "storage"
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(type_choice)
      end

    private

      def type_choice
        @type_choice ||= TypeChoice.new(@controller)
      end
    end
  end
end
