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
require "cwm"
require "y2storage"
require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Form to set the chunk size and parity of an MD RAID
    # Part of {Actions::AddMd}.
    class MdOptions < Base
      # @param controller [Actions::Controllers::Md]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        @chunk_size_selector = ChunkSize.new(controller)
        @parity_selector = controller.parity_supported? ? Parity.new(controller) : Empty()
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(
          VBox(
            Left(@chunk_size_selector),
            Left(@parity_selector)
          )
        )
      end

      private

      attr_reader :controller

      # Widget to select the chunk size
      class ChunkSize < CWM::ComboBox
        # @param controller [Actions::Controllers::Md]
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        def label
          _("Chunk Size")
        end

        def help
          _("<p><b>Chunk Size:</b> " \
            "It is the smallest \"atomic\" mass of data that can be written to the devices. " \
            "A reasonable chunk size for RAID 5 is 128 kB. " \
            "For RAID 0, 32 kB is a good starting point. " \
            "For RAID 1, the chunk size does not affect the array very much." \
            "</p>")
        end

        # @macro seeAbstractWidget
        def opt
          [:hstretch, :notify]
        end

        def items
          @controller.chunk_sizes.map { |s| [s.to_s, s.to_s] }
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.chunk_size.to_s
        end

        # @macro seeAbstractWidget
        def store
          @controller.chunk_size = Y2Storage::DiskSize.new(value)
        end
      end

      # Widget to select the md parity
      class Parity < CWM::ComboBox
        # @param controller [Actions::Controllers::Md]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
        end

        def label
          _("Parity Algorithm")
        end

        def help
          _("<p><b>Parity Algorithm:</b> " \
            "The parity algorithm to use with RAID 5/6. " \
            "Left-symmetric is the one that offers maximum performance " \
            "on typical disks with rotating platters." \
            "</p>")
        end

        # @macro seeAbstractWidget
        def opt
          [:hstretch, :notify]
        end

        def items
          @controller.md_parities.map { |p| [p.to_s, p.to_human_string] }
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.md_parity.to_s
        end

        # @macro seeAbstractWidget
        def store
          @controller.md_parity = Y2Storage::MdParity.find(value)
        end
      end
    end
  end
end
