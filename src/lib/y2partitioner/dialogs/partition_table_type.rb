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
require "y2storage"
require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Select a partition table type (GPT, MS-DOS, DASD)
    # Part of {Actions::CreatePartitionTable}.
    class PartitionTableType < Base
      # Choose partition table type
      class TypeChoice < CWM::RadioButtons
        # Constructor
        #
        # @param possible_types [Array<Y2Storage::PartitionTables::Type>]
        # @param default_type [Y2Storage::PartitionTables::Type]
        def initialize(possible_types, default_type)
          textdomain "storage"
          super()

          @supported_types = possible_types.map(&:to_s)
          @default_type = default_type.to_s
          log.info("Supported partition table types: #{@supported_types}")
        end

        # @macro seeAbstractWidget
        def label
          _("New Partition Table Type")
        end

        # @macro seeAbstractWidget
        def help
          # helptext
          _("<p>Choose the type of the new partition table.</p>")
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
          self.value = @default_type
        end
      end

      # Constructor
      #
      # @param disk [Y2Storage::Partitionable]
      # @param possible_types [Array<Y2Storage::PartitionTables::Type>]
      # @param default_type [Y2Storage::PartitionTables::Type]
      def initialize(disk, possible_types, default_type)
        textdomain "storage"

        @disk = disk
        @type_choice = TypeChoice.new(possible_types, default_type)
      end

      # @macro seeDialog
      def title
        # TRANSLATORS: %s is a device name like /dev/sda
        format("Create New Partition Table on %s", @disk.name)
      end

      # @macro seeDialog
      def contents
        HVSquash(@type_choice)
      end

      # Partition type selected by the user
      #
      # @return [Y2Storage::PartitionTables::Type]
      def selected_type
        Y2Storage::PartitionTables::Type.new(@type_choice.value)
      end
    end
  end
end
