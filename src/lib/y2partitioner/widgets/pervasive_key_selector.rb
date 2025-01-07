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
require "y2storage/pbkd_function"

module Y2Partitioner
  module Widgets
    # Master key selector for a {Y2Storage::Encryption} device using pervasive encryption
    class PervasiveKeySelector < CWM::ComboBox
      # Constructor
      #
      # @param apqns_by_key [Hash]
      # @param initial_key [String]
      # @param enable [Boolean] whether the widget should be enabled on init
      def initialize(apqns_by_key, initial_key, enable: true)
        super()
        textdomain "storage"

        @apqns_by_key = apqns_by_key
        @initial_key = initial_key
        @enable_on_init = enable
      end

      # @macro seeAbstractWidget
      def label
        _("Master Key Verification Pattern")
      end

      def opt
        [:notify]
      end

      # Sets the initial value
      def init
        enable_on_init ? enable : disable
        self.value = initial_key
      end

      # @macro seeItemsSelection
      def items
        apqns_by_key.keys.sort.map { |k| [k, key_label(k)] }
      end

      # @see #items
      def key_label(key)
        apqns = apqns_by_key[key]
        if apqns.first.mode =~ /CCA/
          if apqns.size > 1
            # TRANSLATORS: Related to encryption using a CryptoExpress adapter in CCA mode, %s is
            # replaced by a key verification pattern
            format(_("CCA: %s (several APQNs)"), key)
          else
            # TRANSLATORS: Related to encryption using a CryptoExpress adapter in CCA mode.
            #              %{key} is replaced by a key verification pattern;
            #              %{apqn} by the name of an APQN
            format(_("CCA: %{key} (APQN %{apqn})"), key: key, apqn: apqns.first.name)
          end
        else
          # TRANSLATORS: this string is used to display a subset of a key verification pattern.
          # %{start} is replaced by the first 10 characters of the pattern; %{ending} by the final 10.
          key_string = format(_("%{start}...%{ending}"), start: key[0..9], ending: key[-10..-1])
          if apqns.size > 1
            # TRANSLATORS: Related to encryption using a CryptoExpress adapter in EP11 mode, %s is
            # replaced by a subset of the key verification pattern
            format(_("EP11: %s (several APQNs)"), key_string)
          else
            # TRANSLATORS: Related to encryption using a CryptoExpress adapter in EP11 mode.
            #              %{key} is replaced by a subset of the key verification pattern;
            #              %{apqn} by the name of an APQN
            format(_("EP11: %{key} (APQN %{apqn})"), key: key_string, apqn: apqns.first.name)
          end
        end
      end

      private

      # @return [Boolean] whether the widget should be enabled on init
      attr_reader :enable_on_init

      # @return [Hash] All APQNs objects grouped by their master key
      attr_reader :apqns_by_key

      # @return [String] Master key initially selected
      attr_reader :initial_key
    end
  end
end
