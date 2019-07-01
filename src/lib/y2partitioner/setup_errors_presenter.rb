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
    # @note An empty string is returned when there is no error.
    #
    # @return [String]
    def to_html
      errors_html || warnings_html || ""
    end

    private

    # @return [SetupChecker] checker for the current setup
    attr_reader :setup_checker

    # HTML representation for boot warnings
    #
    # @return [String, nil] nil if there is no boot warning
    def warnings_html
      warnings = [boot_warnings_html, product_warnings_html].compact
      return nil if warnings.empty?

      warnings.join(Yast::HTML.Newline)
    end

    # HTML representation for boot warnings
    #
    # @return [String, nil] nil if there is no boot warning
    def boot_warnings_html
      warnings = setup_checker.boot_warnings
      # TRANSLATORS
      header = _("The system might not be able to boot:\n")

      create_html(header, warnings)
    end

    # HTML representation for mandatory product warnings
    #
    # @return [String, nil] nil if there is no product warning
    def product_warnings_html
      warnings = setup_checker.product_warnings
      # TRANSLATORS
      header = _(
        "The system could not work properly because the following product " \
          "requirements were not fulfilled:\n"
      )

      create_html(header, warnings)
    end

    # HTML representation for fatal booting errors
    #
    # @return [String, nil] nil if there is no error
    def errors_html
      errors = setup_checker.errors
      # TRANSLATORS
      header = _("The system cannot be installed because the following errors were found:\n")

      create_html(header, errors)
    end

    # HTML representation for a set of errors
    #
    # @note The representation is composed by a header message and the list error messages.
    #
    # @param header [String] header text
    # @param errors [Array<SetupError>] list of errors
    #
    # @return [String, nil] nil if there is no error
    def create_html(header, errors)
      return nil if errors.empty?

      error_messages = errors.map(&:message)
      header + Yast::HTML.Newline + Yast::HTML.List(error_messages)
    end
  end
end
