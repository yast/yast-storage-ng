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
require "cwm"
require "y2storage"
require "y2partitioner/widgets/mkfs_optiondata"

module Y2Partitioner
  # Partitioner widgets
  module Widgets
    include Yast::Logger

    # Common parts of our dialog elements.
    module MkfsCommon
      # Ensure we have a unique widget_id.
      #
      # @param controller [Actions::Controllers::Filesystem]
      # @param option [MkfsOptiondata]
      #
      def initialize(controller, option)
        @filesystem = controller.filesystem
        @option = option
        self.widget_id = "#{self.class}_#{object_id}"
      end

      # Widget label.
      #
      # @return [String]
      #
      def label
        @option.label
      end

      # Help text.
      #
      # @return [String]
      #
      def help
        @option.help
      end

      # Get the initial value from file system object.
      def init
        self.value = @option.get(@filesystem)
      end

      # Store the new value in the file system object.
      def store
        @option.set(@filesystem, value)
      end

      # Validate the new value.
      #
      # return [Boolean]
      #
      def validate
        if !@option.validate?(value)
          Yast::Popup.Error(format(@option.error, value))
          false
        else
          true
        end
      end
    end

    # Class for selecting mkfs and tune2fs options for {Y2Storage::Filesystems}.
    class MkfsOptions < CWM::CustomWidget
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        @controller = controller
        self.handle_all_events = true
      end

      # Help text.
      #
      # The text is a combination of help texts from all sub-widgets.
      #
      # @return [String]
      #
      def help
        Yast::CWM.widgets_in_contents(contents).find_all do |w|
          w.respond_to?(:help)
        end.map(&:help).join("\n")
      end

      # @macro seeAbstractWidget
      def opt
        [:notify]
      end

      # @macro seeAbstractWidget
      def handle(event)
        case event["ID"]
        when :help
          Yast::Wizard.ShowHelp(help)
        end
      end

      # @macro seeAbstractWidget
      def contents
        # FIXME: add some VSpacing(1)?
        # contents is called several times for each dialog, so cache it
        @contents ||= VBox(
          * MkfsOptiondata.options_for(@controller.filesystem).map do |w|
            Left(Widgets.const_get(w.widget).new(@controller, w))
          end
        )
      end
    end

    # a class
    class MkfsInputField < CWM::InputField
      include MkfsCommon
    end

    # a class
    class MkfsCheckBox < CWM::CheckBox
      include MkfsCommon
    end

    # a class
    class MkfsComboBox < CWM::ComboBox
      include MkfsCommon

      # @macro seeAbstractWidget
      def items
        @option.values.map { |s| [s, s] }
      end
    end
  end
end
