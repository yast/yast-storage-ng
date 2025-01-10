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
    # Widget to select the APQNs for pervasive encryption
    class ApqnSelector < CWM::ReplacePoint
      # Internal widget used when there are several candidate APQNs for the given key
      class ApqnMultiSelector < CWM::MultiSelectionBox
        # Constructor
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

        widgets_by_key.each_value { |w| w.enable if w.respond_to?(:enable) }
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widget needs to be disabled.
      def disable
        super

        all_widgets.each_value { |w| w.disable if w.respond_to?(:disable) }
      end

      # Redraws the widget to show the options for given master key
      #
      # @param key [String]
      def refresh(key)
        replace(widgets_by_key[key])
      end

      # All selected APQNs, if there are several possible ones
      #
      # @return [Array<Y2Storage::EncryptionProcesses::Apqn>, nil] nil if there is only one possible APQN
      def value
        return unless @widget.respond_to?(:value)

        @widget.value
      end

      private

      # @return [Boolean]
      attr_reader :enable_on_init

      # @return [Hash] list of possible APQNs for each configured master key
      attr_reader :apqns_by_key

      # @return [Hash{String => CWM::AbstractWidget}]
      def widgets_by_key
        return @widgets_by_key if @widgets_by_key

        @widgets_by_key = {}
        apqns_by_key.each do |key, apqns|
          selected = key == @initial_key ? @initial_apqns : apqns
          @widgets_by_key[key] = widget_for(key, apqns, selected)
        end

        @widgets_by_key
      end

      # Returns either a selector or an empty widget (if there is only one possible APQN)
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
