# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "yast/i18n"
require "y2storage"

Yast.import "HTML"

module Y2Partitioner
  # Class to represent storage setup errors
  class SetupErrorsPresenter
    include Yast::I18n

    # Constructor
    #
    # @param setup_checker [SetupChecker]
    def initialize(setup_checker)
      textdomain "storage"
      @setup_checker = setup_checker
    end

    # HTML represetation of the storage setup errors
    #
    # @return [String, nil] nil if there are no errors
    def to_html
      errors = [boot_errors_html, product_errors_html].compact
      return nil if errors.empty?

      errors.join(Yast::HTML.Newline)
    end

  private

    # @return [SetupChecker] checker for the current setup
    attr_reader :setup_checker

    # HTML representation for boot errors
    #
    # @return [String]
    def boot_errors_html
      errors = setup_checker.boot_errors
      # TRANSLATORS
      header = _("The system could not load because the following errors were found:\n")

      errors_html(header, errors)
    end

    # HTML representation for mandatory product errors
    #
    # @return [String]
    def product_errors_html
      errors = setup_checker.product_errors
      # TRANSLATORS
      header = _("The system could not work properly because the following errors were found:\n")

      errors_html(header, errors)
    end

    # HTML representation for a set of errors
    #
    # @note The representation is composed by a header message and the list error messages.
    #
    # @param header [String] header text
    # @param errors [Array<SetupError>] list of errors
    #
    # @return [String]
    def errors_html(header, errors)
      return nil if errors.empty?

      error_messages = errors.map(&:message)
      header + Yast::HTML.Newline + Yast::HTML.List(error_messages)
    end
  end
end
