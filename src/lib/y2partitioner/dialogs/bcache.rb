# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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
require "y2storage/cache_mode"
require "y2storage/disk_size"
require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Bcache dialog
    #
    # Used by {Actions::AddBcache}.
    class Bcache < Base
      # Constructor
      #
      # @param suitable_backing [Array<Y2Storage::BlkDevice>] devices that can be used for backing.
      # @param suitable_caching [Array<Y2Storage::BlkDevice, Y2Storage::BcacheCset>]
      #   devices that can be used for caching.
      # @param device [Y2Storage::Bcache] existing bcache device or nil if it is a new one.
      def initialize(suitable_backing, suitable_caching, device = nil)
        textdomain "storage"

        @caching = CachingDeviceSelector.new(device, suitable_caching)
        @backing = BackingDeviceSelector.new(device, suitable_backing, @caching)
        @cache_mode = CacheModeSelector.new(device)
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
          VSpacing(1),
          HBox(
            @cache_mode,
            HSpacing(1),
            Empty()
          )
        )
      end

      # Selected caching device
      #
      # Undefined if result of dialog is not `:next`.
      #
      # @return [Y2Storage::BlkDevice, Y2Storage::BcacheCset]
      def caching_device
        @caching.result
      end

      # Selected backing device
      #
      # Undefined if result of dialog is not `:next`
      #
      # @return [Y2Storage::BlkDevice]
      def backing_device
        @backing.result
      end

      # Bcache options
      #
      # Undefined if result of dialog is not `:next`
      #
      # @return [Hash<Symbol, Object>]
      def options
        {
          cache_mode: @cache_mode.result
        }
      end

      # Base class for widgets to select a device
      #
      # @see BackingDeviceSelector, CachingDeviceSelector
      class DeviceSelector < CWM::ComboBox
        # @return [Y2Storage::Bcache]
        attr_reader :bcache

        # @return [Array<Y2Storage::BlkDevice, Y2Storage::BcacheCset>]
        attr_reader :devices

        # Device selected in widget
        #
        # Only rely on this value when the dialog succeed and {#store} is called.
        #
        # @return [Y2Storage::BlkDevice, Y2Storage::BcacheCset]
        attr_reader :result

        # Constructor
        #
        # @param bcache [Y2Storage::Bcache, nil] existing bcache or nil if it is a new one.
        # @param devices [Array<Y2Storage::BlkDevice, Y2Storage::BcacheCset>] possible devices
        #   that can be used as backing device.
        def initialize(bcache, devices)
          textdomain "storage"

          @bcache = bcache
          @devices = devices
        end

        # @macro seeAbstractWidget
        def init
          self.value = default_sid
        end

        # @macro seeAbstractWidget
        def store
          @result = selected_device
        end

      private

        # sid of the device that is initally selected
        #
        # @return [String, nil]
        def default_sid
          return nil unless default_device

          default_device.sid.to_s
        end

        # The first avilable device is selected by default
        #
        # @return [Y2Storage::BlkDevice, Y2Storage::BcacheCset, nil] nil if there is no
        #   devices to select.
        def default_device
          devices.first
        end

        # Selected device
        #
        # @return [Y2Storage::BlkDevice, nil] nil if no device has been selected
        def selected_device
          return nil if value.nil? || value.empty?

          devices.find { |d| d.sid == value.to_i }
        end

        def item_for_device(device)
          label = device.is?(:bcache_cset) ? device.display_name : device.name

          [device.sid.to_s, label]
        end
      end

      # Widget to select the backing device
      class BackingDeviceSelector < DeviceSelector
        # @return [Y2Storage::BlkDevice, Y2Storage::BcacheCset]
        attr_reader :caching

        # Constructor
        #
        # @param bcache [Y2Storage::Bcache, nil] existing bcache or nil if it is a new one.
        # @param devices [Array<Y2Storage::BlkDevice>] possible devices that can be used as
        #   backing device.
        # @param caching [Y2Partitioner::Dialogs::Bcache::CachingDeviceSelector] reference to
        #   caching widget. Used to check that caching and backing devices are not identical.
        def initialize(bcache, devices, caching)
          super(bcache, devices)

          @caching = caching
        end

        # @macro seeAbstractWidget
        def label
          _("Backing Device")
        end

        # @macro seeItemsSelection
        def items
          devices.map { |d| item_for_device(d) }
        end

        # @macro seeAbstractWidget
        def help
          # TRANSLATORS: %{label} is replaced by the label of the option to select a backing device.
          format(
            _("<p>" \
                "<b>%{label}</b> is the device that will be used as backing device for bcache." \
                "It will define the available space of bcache. " \
                "The Device will be formatted so any previous content will be wiped out." \
              "</p>"),
            label: label
          )
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
          elsif value == caching.value
            Yast2::Popup.show(
              _("Backing and Caching devices cannot be identical."),
              headline: _("Cannot Create Bcache")
            )
            return false
          else
            true
          end
        end

      private

        # When the bcache exists, its backing device should be the default device.
        # Otherwise, the first available device is the default one.
        def default_device
          return bcache.backing_device if bcache

          super
        end
      end

      # Widget to select the caching device
      class CachingDeviceSelector < DeviceSelector
        # @macro seeAbstractWidget
        def label
          _("Caching Device")
        end

        # @macro seeItemsSelection
        def items
          items = devices.map { |d| item_for_device(d) }

          items.prepend(item_for_non_device)
        end

        # @macro seeAbstractWidget
        def help
          # TRANSLATORS: %{label} is replaced by the label of the option to select a caching device.
          format(
            _("<p>" \
                "<b>%{label}</b> is the device that will be used as caching device for bcache." \
                "It should be faster and usually is smaller than the backing device, " \
                "but it is not required. The device will be formatted so any previous " \
                "content will be wiped out." \
              "</p>" \
              "<p>" \
                "If you are thinking about using bcache later, it is recommended to setup " \
                "your slow devices as bcache backing devices without a cache. You can " \
                "add a caching device later." \
              "</p>"),
            label: label
          )
        end

      private

        def item_for_non_device
          ["", _("Without caching")]
        end

        # When the bcache exists, its caching set should be the default device.
        # Otherwise, the first available device is the default one.
        def default_device
          return bcache.bcache_cset if bcache && bcache.bcache_cset

          super
        end
      end

      # Widget to select the cache mode
      class CacheModeSelector < CWM::ComboBox
        # Cache mode selected in widget
        #
        # Only rely on this value when the dialog succeed and {#store} is called.
        attr_reader :result

        # Constructor
        #
        # @param bcache [Y2Storage::Bcache, nil] existing bcache or nil if it is a new one
        def initialize(bcache)
          textdomain "storage"

          @bcache = bcache
        end

        # @macro seeAbstractWidget
        def label
          _("Cache Mode")
        end

        # @macro seeItemsSelection
        def items
          Y2Storage::CacheMode.all.map do |mode|
            [mode.to_sym.to_s, mode.to_human_string]
          end
        end

        # @macro seeAbstractWidget
        #
        # @see https://en.wikipedia.org/wiki/Cache_(computing)#Writing_policies
        def help
          # TRANSLATORS: %{label} is replaced by the label of the option to select a cache mode.
          format(
            _("<p>" \
                "<b>%{label}</b> is the operating mode for bcache. " \
                "There are currently four supported modes.<ul> " \
                "<li><i>Writethrough</i> reading operations are cached, writing is done " \
                "in parallel to both devices. No data is lost in case of failure of " \
                "the caching device. This is the default mode.</li>" \
                "<li><i>Writeback</i> both reading and writing operations are cached. " \
                "This result in better performance when writing.</li>" \
                "<li><i>Writearound</i> reading is cached, new content is " \
                "written only to the backing device.</li>" \
                "<li><i>None</i> means cache is neither used for reading nor for writing. " \
                "This is useful mainly for temporarily disabling the cache before any big " \
                "sequential read or write, otherwise that would result in intensive " \
                "overwriting on the cache device.</li>" \
              "</p>"),
            label: label
          )
        end

        # @macro seeAbstractWidget
        def init
          self.value = (@bcache ? @bcache.cache_mode : Y2Storage::CacheMode::WRITETHROUGH).to_sym.to_s
        end

        # @macro seeAbstractWidget
        def store
          @result = Y2Storage::CacheMode.find(value.to_sym)
        end
      end
    end
  end
end
