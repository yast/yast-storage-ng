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
require "yast2/popup"
require "cwm/common_widgets"
require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Form to set the backing and caching device for bcache.
    # Part of {Actions::AddBcache}.
    class Bcache < Base
      # @param suitable_backing [Array<Y2Storage::BlkDevice>] devices that can be used for backing
      # @param suitable_caching [Array<Y2Storage::BlkDevice,Y2Storage::BcacheCset>]
      #   devices that can be used for caching
      # @param device [Y2Storage::Bcache] device if already exists or nil for newly created one.
      def initialize(suitable_backing, suitable_caching, device = nil)
        textdomain "storage"
        @caching = CachingDevice.new(device, suitable_caching)
        @backing = BackingDevice.new(device, suitable_backing, @caching)
      end

      # @macro seeDialog
      def title
        _("Bcache Device")
      end

      # @macro seeDialog
      def contents
        VBox(
          HBox(
            @backing,
            HSpacing(1),
            @caching
          ),
          VSpacing(1)
        )
      end

      # Selected caching device. Undefined if result of dialog is not `:next`
      # @return [Y2Storage::BlkDevice, Y2Storage::BcacheCset]
      def caching_device
        @caching.result
      end

      # Selected backing device. Undefined if result of dialog is not `:next`
      # @return [Y2Storage::BlkDevice]
      def backing_device
        @backing.result
      end

      # Widget to select the backing device
      class BackingDevice < CWM::ComboBox
        # @param device [Y2Storage::BlkDevice,nil] existing backing device or nil if it is new bcache
        # @param devices [Array<Y2Storage::BlkDevice>] possible devices that can be used
        #   as backing device for bcache
        # @param caching [Y2Partitioner::Dialogs::Bcache::CachingDevice] reference to caching widget.
        #   Used for validation if both caching and backing device is not identical.
        def initialize(device, devices, caching)
          textdomain "storage"
          @device = device
          @devices = devices
          @caching = caching
        end

        # @macro seeAbstractWidget
        def label
          _("Backing Device")
        end

        # @macro seeItemsSelection
        def items
          @devices.map do |dev|
            [dev.sid.to_s, dev.name]
          end
        end

        # @macro seeAbstractWidget
        def help
          # TRANSLATORS: %s stands for name of option
          format(_(
                   "<b>%s</b> is the device that will be used as backing device for bcache." \
                   "It will define the available space of bcache. " \
                   "The Device will be formatted so any previous content will be wiped out."
          ), label)
        end

        # @macro seeAbstractWidget
        def init
          return unless @device

          self.value = @device.sid.to_s
        end

        # @macro seeAbstractWidget
        def store
          val = value
          @result = @devices.find { |d| d.sid == val.to_i }
        end

        # @macro seeAbstractWidget
        def validate
          log.info "selected value #{value.inspect}"
          # value can be empty string if there is no items
          if value.nil? || value.empty?
            Yast2::Popup.show(
              _("Empty backing device is not yet supported"),
              headline: _("Cannot Create Bcache")
            )
            return false
          elsif value == @caching.value
            Yast2::Popup.show(
              _("Backing and Caching devices cannot be identical."),
              headline: _("Cannot Create Bcache")
            )
            return false
          else
            true
          end
        end

        # returns device selected in widget. Only when dialog succeed and store is called.
        # Otherwise undefined
        attr_reader :result
      end

      # Widget to select the caching device
      class CachingDevice < CWM::ComboBox
        # @param device [Y2Storage::BcacheCset,nil] existing caching device or nil if it is new bcache
        # @param devices [Array<Y2Storage::BlkDevice,Y2Storage::BcacheCset>] possible devices
        #   that can be used as caching device for bcache
        def initialize(device, devices)
          textdomain "storage"
          @device = device
          @devices = devices
        end

        # @macro seeAbstractWidget
        def label
          _("Caching Device")
        end

        # @macro seeItemsSelection
        def items
          @devices.map do |dev|
            case dev
            when Y2Storage::BcacheCset
              [dev.sid.to_s, dev.display_name]
            else
              [dev.sid.to_s, dev.name]
            end
          end
        end

        # @macro seeAbstractWidget
        def help
          # TRANSLATORS: %s stands for name of option
          format(_(
                   "<b>%s</b> is the device that will be used as caching device for bcache." \
                   "It should be faster and usually is smaller than the backing device, " \
                   "but it is not required. " \
                   "The device will be formatted so any previous content will be wiped out."
          ), label)
        end

        # @macro seeAbstractWidget
        def init
          return unless @device

          self.value = @device.sid.to_s
        end

        # @macro seeAbstractWidget
        def store
          val = value
          @result = @devices.find { |d| d.sid == val.to_i }
        end

        # returns device selected in widget. Only when dialog succeed and store is called.
        # Otherwise undefined
        attr_reader :result
      end
    end
  end
end
