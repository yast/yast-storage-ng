# Copyright (c) [2017-2019] SUSE LLC
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

module Y2Partitioner
  module Widgets
    # Encrypted {Y2Storage::BlkDevice} password
    class EncryptPassword < CWM::CustomWidget
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      # @param enable [Boolean] whether the widget should be enabled on init
      def initialize(controller, enable: true)
        textdomain "storage"

        @controller = controller
        @checker = Y2Storage::EncryptPasswordChecker.new
        @enable_on_init = enable
      end

      # @macro seeAbstractWidget
      def validate
        msg = checker.error_msg(pw1, pw2) if enabled?
        return true unless msg

        Yast::Report.Error(msg)
        Yast::UI.SetFocus(Id(:pw1))
        false
      end

      # @macro seeAbstractWidget
      def init
        enable_on_init ? enable : disable
      end

      # @macro seeAbstractWidget
      def store
        @controller.password = pw1
      end

      # @macro seeAbstractWidget
      def cleanup
        checker.tear_down
      end

      # @macro seeCustomWidget
      def contents
        VBox(
          Id(widget_id),
          Password(
            Id(:pw1),
            Opt(:hstretch),
            _("&Enter an Encryption Password:"),
            @controller.password
          ),
          Password(
            Id(:pw2),
            Opt(:hstretch),
            _("Reenter the Password for &Verification:"),
            @controller.password
          )
        )
      end

      private

      # @return Y2Storage::EncryptPasswordChecker
      attr_reader :checker

      # @return [Boolean] whether the widget should be enabled on init
      attr_reader :enable_on_init

      # @return [String]
      def pw1
        Yast::UI.QueryWidget(Id(:pw1), :Value)
      end

      # @return [String]
      def pw2
        Yast::UI.QueryWidget(Id(:pw2), :Value)
      end
    end
  end
end
