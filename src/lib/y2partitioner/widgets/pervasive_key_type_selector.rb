# Copyright (c) [2024] SUSE LLC
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

module Y2Partitioner
  module Widgets
    # Widget to select the key variant for pervasive encryption
    class PervasiveKeyTypeSelector < CWM::ReplacePoint
      # Widget to select the key variant for a CCA key
      class CcaTypeSelector < CWM::ComboBox
        # Constructor
        def initialize
          super
          textdomain "storage"
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: title of the widget to select the variant of a CCA key (AES data vs AES cipher)
          _("Key Type")
        end

        # @macro seeItemsSelection
        def items
          [
            ["CCA-AESCIPHER", _("CCA AESCIPHER (more secure)")],
            ["CCA-AESDATA", _("CCA AESDATA (allows to export the keys)")]
          ]
        end
      end

      # Constructor
      def initialize(controller, initial_apqn, enable: true)
        textdomain "storage"

        @controller = controller
        @initial_apqn = initial_apqn
        @enable_on_init = enable

        super(id: "key_type", widget: widget_for(initial_apqn))
      end

      # @macro seeAbstractWidget
      def init
        super
        enable_on_init ? enable : disable
      end

      # @macro seeAbstractWidget
      def enable
        super

        @widget.enable if @widget.respond_to?(:enable)
      end

      # @macro seeAbstractWidget
      def disable
        super

        @widget.enable if @widget.respond_to?(:enable)
      end

      # Redraws to show the appropriate widget
      def refresh(apqn)
        new_widget = widget_for(apqn)
        replace(new_widget) if new_widget != @widget
      end

      # Selected key variant
      #
      # @return [String]
      def value
        return "ep11" unless @widget.respond_to?(:value)
        
        @widget.value
      end

      private

      # @return [Boolean]
      attr_reader :enable_on_init

      # @return [Actions::Controllers::Encryption]
      attr_reader :controller

      # @return [Y2Storage::EncryptionProcesses::Apqn]
      attr_reader :initial_apqn

      # Empty widget or selector for the CCA key variant
      def widget_for(apqn_name)
        apqn = controller.find_apqn(apqn_name)
        return cca_selector if apqn.mode =~ /CCA/

        CWM::Empty.new("empty_#{widget_id}")
      end

      # @return [CcaTypeSelector]
      def cca_selector
        @cca_selector ||= CcaTypeSelector.new
      end
    end
  end
end
