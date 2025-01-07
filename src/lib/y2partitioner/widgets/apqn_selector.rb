# Copyright (c) [2020-2024] SUSE LLC
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
require "yast2/popup"
require "y2partitioner/widgets/encrypt_password"
require "y2partitioner/widgets/encrypt_label"
require "y2partitioner/widgets/pbkdf_selector"
require "y2partitioner/widgets/apqn_selector"

module Y2Partitioner
  module Widgets
    # Widget to display the available options for a given encryption method
    class ApqnSelector < CWM::ReplacePoint

      # Widget to select APQNs for generating a new secure key for pervasive encryption
      class ApqnMultiSelector < CWM::MultiSelectionBox
        # Constructor
        #
        # @param enable [Boolean] whether the widget should be enabled on init
        def initialize(id, all_apqns, selected_apqns)
          super()
          textdomain "storage"
          
          self.widget_id = id
          @apqns = all_apqns
          @selected_apqns = selected_apqns
        end

        # @return [String]
        def label
          _("Available APQNs:")
        end

        # @return [Array<String, String>]
        def items
          @apqns.map { |a| [a, a] }
        end

        def init
          self.value = @selected_apqns
        end
      end

      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(apqns_by_key, initial_key, initial_apqns, enable: true)
        textdomain "storage"

        @apqns_by_key = apqns_by_key
        @initial_key = initial_key
        @initial_apqns = initial_apqns
        @enable_on_init = enable

        super(id: "apqn_selector", widget: widgets_by_key[initial_key])
      end

      # @macro seeAbstractWidget
      def init
        super
        enable_on_init ? enable : disable
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widget needs to be enabled.
      def enable
        super

        widgets_by_key.values.each { |w| w.enable if w.respond_to?(:enable) }
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widget needs to be disabled.
      def disable
        super

        all_widgets.values.each { |w| w.disable if w.respond_to?(:disable) }
      end

      # Redraws the widget to show the options for given encryption method
      #
      # @param encrypt_method [YStorage::EncryptionMethod]
      def refresh(key)
        replace(widgets_by_key[key])
      end

      # All selected APQNs
      #
      # @return [Array<Y2Storage::EncryptionProcesses::Apqn>]
      def value
        return unless @widget.respond_to?(:value)
        
        @widget.value.map { |d| @controller.find_apqn(d) }.compact
      end

      private

      # @return [Boolean]
      attr_reader :enable_on_init
      attr_reader :apqns_by_key

      def widgets_by_key
        return @widgets_by_key if @widgets_by_key

        @widgets_by_key = {}
        apqns_by_key.each do |key, apqns|
          selected = key == @initial_key ? @initial_apqns : apqns
          @widgets_by_key[key] = widget_for(key, apqns, selected)
        end

        @widgets_by_key
      end

      def widget_for(key, apqns, selected)
        widget_id = "Details#{key}"
        if apqns.size > 1
          ApqnMultiSelector.new(widget_id, apqns.map(&:name), selected.map(&:name))
        else
          CWM::Empty.new(widget_id)
        end
      end
    end
  end
end
