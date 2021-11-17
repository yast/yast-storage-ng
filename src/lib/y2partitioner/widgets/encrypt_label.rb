# Copyright (c) [2021] SUSE LLC
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
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Widgets
    # Label for a {Y2Storage::Luks} device
    class EncryptLabel < CWM::InputField
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      # @param enable [Boolean] whether the widget should be enabled on init
      def initialize(controller, enable: true)
        textdomain "storage"

        @controller = controller
        @enable_on_init = enable
      end

      # @macro seeAbstractWidget
      def label
        _("LUKS &Label (optional)")
      end

      # Checks whether there is already a LUKS device with the given label
      #
      # @note An error popup is presented when other LUKS has the given label.
      #
      # @return [Boolean]
      def validate
        return true unless duplicated_label?

        # TRANSLATORS: Error pop-up
        Yast::Popup.Error(_("This LUKS label is already in use. Select a different one."))
        Yast::UI.SetFocus(Id(widget_id))

        false
      end

      # @macro seeAbstractWidget
      def init
        enable_on_init ? enable : disable
        self.value = @controller.label
      end

      # @macro seeAbstractWidget
      def store
        @controller.label = value
      end

      private

      # @return [Boolean] whether the widget should be enabled on init
      attr_reader :enable_on_init

      # Whether the given label is duplicated
      #
      # @return [Boolean] true if the label is duplicated; false otherwise.
      def duplicated_label?
        return false if value.empty?

        DeviceGraphs.instance.current.encryptions.any? do |enc|
          next false if enc.sid == @controller.encryption&.sid
          next false unless enc.respond_to?(:label)

          enc.label == value
        end
      end
    end
  end
end
