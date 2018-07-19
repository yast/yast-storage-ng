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
require "cwm/common_widgets"
require "cwm/custom_widget"
require "y2storage"
require "y2partitioner/dialogs/base"
require "y2partitioner/size_parser"
require "y2partitioner/widgets/controller_radio_buttons"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Determine the size of a partition to be created, in the form
    # of a {Y2Storage::Region}.
    # Part of {Actions::AddPartition}.
    # Formerly MiniWorkflowStepPartitionSize
    class PartitionSize < Base
      # @param controller [Actions::Controllers::Partition]
      #   a partition controller, collecting data for a partition to be created
      def initialize(controller)
        textdomain "storage"
        @disk_name = controller.disk_name
        @controller = controller
        type = controller.type
        @regions = controller.unused_slots.select { |s| s.possible?(type) }.map(&:region)
        @optimal_regions = controller.unused_optimal_slots.select { |s| s.possible?(type) }.map(&:region)

        raise ArgumentError, "No region to make a partition in" if @optimal_regions.empty?
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(SizeWidget.new(@controller, @regions, @optimal_regions))
      end

      # return finish for extended partition, as it can set only type and its size
      def run
        res = super
        res = :finish if res == :next && @controller.type.is?(:extended)
        res
      end

      # Choose a size (region, really) for a new partition
      # from several options: use maximum, enter size, enter start+end
      class SizeWidget < Widgets::ControllerRadioButtons
        # @param controller [Actions::Controllers::Partition]
        #   a controller collecting data for a partition to be created
        # @param regions [Array<Y2Storage::Region>]
        #   regions available to create a partition in
        # @param optimal_regions [Array<Y2Storage::Region>]
        #   regions with an optimally aligned start available to create
        #   a partition in
        def initialize(controller, regions, optimal_regions)
          textdomain "storage"
          @controller = controller
          @regions = regions
          @optimal_regions = optimal_regions
          @largest_region = @optimal_regions.max_by(&:size)
        end

        # @macro seeAbstractWidget
        def label
          _("New Partition Size")
        end

        def items
          max_size_label = Yast::Builtins.sformat(_("Maximum Size (%1)"),
            @largest_region.size.human_floor)
          [
            [:max_size, max_size_label],
            [:custom_size, _("Custom Size")],
            [:custom_region, _("Custom Region")]
          ]
        end

        def widgets
          @widgets ||= [
            MaxSizeDummy.new(@largest_region),
            CustomSizeInput.new(@controller, @optimal_regions),
            CustomRegion.new(@controller, @regions, @largest_region)
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = (@controller.size_choice ||= :max_size)
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        def store
          w = current_widget
          w.store
          @controller.region = w.region
          @controller.size_choice = value
        end

        # @macro seeAbstractWidget
        def help
          # helptext
          _(
            "<p>Choose the size for the new partition.</p>\n" \
            "<p>If a size is specified (any of the two first options in the form),\n" \
            "the start and end of the partition will be aligned to ensure optimal\n" \
            "performance and to minimize gaps. That may result in a slightly\n" \
            "smaller partition.</p>\n" \
            "<p>If a custom region is specified, the start and end will be honored\n" \
            "as closely as possible, with no performance optimizations. This is the\n" \
            "best option to create very small partitions.</p>"
          )
        end
      end

      # An invisible widget that knows a Region
      class MaxSizeDummy < CWM::Empty
        attr_reader :region

        # @param region [Y2Storage::Region]
        def initialize(region)
          @region = region
        end

        # @macro seeAbstractWidget
        def store
          # nothing to do, that's OK
        end
      end

      # Enter a human readable size
      class CustomSizeInput < CWM::InputField
        include SizeParser

        # @return [Y2Storage::DiskSize]
        attr_reader :min_size, :max_size

        # @param controller [Actions::Controllers::Partition]
        #   a controller collecting data for a partition to be created
        # @param regions [Array<Y2Storage::Region>]
        #   regions available to create a partition in
        def initialize(controller, regions)
          textdomain "storage"
          @controller = controller
          @regions = regions
          largest_region = @regions.max_by(&:size)
          @max_size = largest_region.size
          @min_size = controller.optimal_grain
        end

        # Forward to controller
        def size
          @controller.custom_size
        end

        # Forward to controller
        def size=(v)
          @controller.custom_size = v
        end

        # @return [Y2Storage::Region] the smallest region
        #   that can contain the chosen size
        def parent_region
          suitable_rs = @regions.find_all { |r| r.size >= size }
          suitable_rs.min_by(&:size)
        end

        # @return [Y2Storage::Region]
        # A new region created in the smallest region
        #   that can contain the chosen size
        def region
          parent = parent_region
          bsize = parent.block_size
          length = (size.to_i / bsize.to_i.to_f).ceil
          Y2Storage::Region.create(parent.start, length, bsize)
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @macro seeAbstractWidget
        def init
          self.size ||= max_size
          self.value = size
        end

        # @macro seeAbstractWidget
        def store
          self.size = value
        end

        # @macro seeAbstractWidget
        def validate
          return true unless enabled?
          v = value
          return true unless v.nil? || v < min_size || v > max_size

          min_s = min_size.human_ceil
          max_s = max_size.human_floor
          Yast::Popup.Error(
            Yast::Builtins.sformat(
              # error popup, %1 and %2 are replaced by sizes
              _("The size entered is invalid. Enter a size between %1 and %2."),
              min_s, max_s
            )
          )
          # TODO: Let CWM set the focus
          Yast::UI.SetFocus(Id(widget_id))
          false
        end

        # @return [Y2Storage::DiskSize,nil]
        def value
          parse_user_size(super)
        end

        # @param v [Y2Storage::DiskSize]
        def value=(v)
          super(v.human_floor)
        end
      end

      # Specify start+end of the region
      class CustomRegion < CWM::CustomWidget
        attr_reader :region

        # @param controller [Actions::Controllers::Partition]
        #   a controller collecting data for a partition to be created
        # @param regions [Array<Y2Storage::Region>]
        #   regions available to create a partition in
        # @param default_region [Y2Storage::Region]
        #   region suggested initially if there is none, used to suggest an
        #   optimally aligned region (i.e. one not included in regions)
        def initialize(controller, regions, default_region)
          textdomain "storage"
          @controller = controller
          @regions = regions
          @region = @controller.region || default_region
        end

        # @macro seeCustomWidget
        def contents
          # we can't use IntField() since it overflows :-(
          VBox(
            Id(widget_id),
            MinWidth(10, InputField(Id(:start_block), _("Start Block"))),
            MinWidth(10, InputField(Id(:end_block), _("End Block")))
          )
        end

        # UI::QueryWidget both ids in one step
        def query_widgets
          [
            Yast::UI.QueryWidget(Id(:start_block), :Value).to_i,
            Yast::UI.QueryWidget(Id(:end_block), :Value).to_i
          ]
        end

        # @macro seeAbstractWidget
        def init
          valid_chars = ("0".."9").reduce(:+)
          start_block = @region.start
          end_block = @region.end

          Yast::UI.ChangeWidget(Id(:start_block), :ValidChars, valid_chars)
          Yast::UI.ChangeWidget(Id(:start_block), :Value, start_block.to_s)
          Yast::UI.ChangeWidget(Id(:end_block), :ValidChars, valid_chars)
          Yast::UI.ChangeWidget(Id(:end_block), :Value, end_block.to_s)
        end

        # @macro seeAbstractWidget
        def store
          start_block, end_block = query_widgets
          len = end_block - start_block + 1
          bsize = @region.block_size
          @region = Y2Storage::Region.create(start_block, len, bsize)
        end

        # @macro seeAbstractWidget
        def validate
          return true unless enabled?

          start_block, end_block = query_widgets
          error = @controller.error_for_custom_region(start_block, end_block)

          return true unless error

          Yast::Popup.Error(error)
          Yast::UI.SetFocus(Id(:start_block))
          false
        end
      end
    end
  end
end
