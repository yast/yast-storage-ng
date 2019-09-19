# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/encrypt_password"

module Y2Partitioner
  module Widgets
    # Widget to display the available options for a given encryption method
    class EncryptMethodOptions < CWM::ReplacePoint
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        super(id: "encrypt_options", widget: empty_widget)
        textdomain "storage"

        @controller = controller
      end

      # Redraws the widget to show the options for given encryption method
      #
      # @param encrypt_method [YStorage::EncryptionMethod]
      def refresh(encrypt_method)
        replace(options_for(encrypt_method))
      end

      private

      attr_reader :controller

      # @return [CWM::Empty] an empty widget
      def empty_widget
        @empty_widget ||= CWM::Empty.new("__empty__")
      end

      # @return [CWM::CustomWidget] a widget containing the options for the
      # given encryption method
      def options_for(encrypt_method)
        if encrypt_method.is?(:random_swap)
          RandomOptions.new(controller)
        elsif encrypt_method.is?(:luks1)
          Luks1Options.new(controller)
        end
      end
    end

    # Internal widget to display the options for random swap encryption
    #
    # Since there is no available options yet, it is being used just to display
    # a warning message to the user.
    class RandomOptions < CWM::CustomWidget
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        @controller = controller
      end

      # @macro seeCustomWidget
      def contents
        VBox(
          Left(
            Label(
              _("Be careful: the system cannot hibernate when\n" \
                "encrypting swap with random password. Please, \n" \
                "read Help for more information.")
            )
          )
        )
      end
    end

    # Internal widget to display the Luks1 encryption options
    class Luks1Options < CWM::CustomWidget
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        @controller = controller
      end

      # @macro seeCustomWidget
      def contents
        VBox(Widgets::EncryptPassword.new(@controller))
      end
    end
  end
end
