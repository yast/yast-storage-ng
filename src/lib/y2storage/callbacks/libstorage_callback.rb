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

require "storage"
require "yast"

Yast.import "Report"
Yast.import "Popup"
Yast.import "Label"

module Y2Storage
  module Callbacks
    # Mixin with methods that are common to all kind of callbacks used for the
    # interaction with libstorage-ng.
    module LibstorageCallback
      include Yast::Logger
      include Yast::I18n

      # Callback for libstorage-ng to show a message to the user.
      #
      # Currently it performs no action, we don't want to bother the regular
      # user with information about every single step. Libstorage-ng is
      # already writing that information to the YaST logs.
      #
      # See Storage::Callbacks#message in libstorage-ng
      def message(message); end

      # Callback for libstorage-ng to report an error to the user.
      #
      # In addition to displaying the error, it offers the user the possibility
      # to ignore it and continue.
      #
      # @note If the user rejects to continue, the method will return false
      # which implies libstorage-ng will raise the corresponding exception for
      # the error.
      #
      # See Storage::Callbacks#error in libstorage-ng
      #
      # @param message [String] error title coming from libstorage-ng
      # @param what [String] details coming from libstorage-ng
      # @return [Boolean] true will make libstorage-ng ignore the error, false
      #   will result in a libstorage-ng exception
      def error(message, what)
        textdomain "storage"
        log.info "libstorage-ng reported an error, asking the user whether to continue"
        log.info "Error details. Message: #{message}. What: #{what}."

        question = _("Continue despite the error?")
        result = Yast::Report.ErrorAnyQuestion(
          Yast::Popup.NoHeadline, "#{message}\n\n#{what}\n\n#{question}",
          Yast::Label.ContinueButton, Yast::Label.AbortButton, :focus_no
        )
        log.info "User answer: #{result}"
        result
      end
    end
  end
end
