# Copyright (c) [2020] SUSE LLC
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

module Y2Partitioner
  module Widgets
    # Class to validate cross option constraints of filesystem
    # formatting (mkfs and tune2fs, atm) options.
    #
    class MkfsOptionvalidator
      include Yast::Logger
      include Yast::I18n
      extend Yast::I18n

      # TODO
      #
      ALL_VALIDATORS = [
        {
          fs:       [:xfs],
          validate: lambda do |widgets|
            block_size = option_value(widgets, :block_size)
            block_size = (block_size == "auto") ? 4096 : block_size.to_i

            inode_size = option_value(widgets, :inode_size)
            inode_size = (inode_size == "auto") ? 512 : inode_size.to_i

            inode_size <= block_size / 2
          end,
          error:    N_(
            "The inode size is too big for the block size. " \
            "The inode size must not exceed one half of the block size."
          )
        }
      ]

      # Remember validator data.
      #
      # @param validator [Hash]
      #
      def initialize(validator)
        @value = validator
        textdomain "storage"
      end

      # Validate option value.
      #
      # This calls the validation function if there is one defined _and_ an
      # error message exists. Else it just returns true.
      #
      # @param val [Array<Widgets>]
      #
      # @return [Boolean]
      #
      def validate?(val)
        return true if val.nil? || !validate || !@value[:error]

        validate[val]
      end

      private

      # Allowed keys in {ALL_VALIDATORS}.
      #
      # @param foo [Symbol]
      #
      # @return [Boolean]
      #
      def good_key?(foo)
        [
          :fs, :validate, :error
        ].include?(foo)
      end

      # Make validator hash entries readable via methods.
      #
      # Note this intentionally returns nil if there's neither a method nor
      # a hash key.
      #
      # @param foo [Symbol]
      #
      # @return [Object]
      #
      def method_missing(foo)
        if good_key?(foo)
          @value[foo]
        else
          super
        end
      end

      # Make class interface consistent. Rubocop insists on this function.
      #
      # @param foo [Symbol]
      # @param _all [Boolean]
      #
      # @return [Boolean]
      #
      def respond_to_missing?(foo, _all)
        good_key?(foo)
      end

      class << self
        # Get list of option validators for a specific file system.
        #
        # The returned list can be empty.
        #
        # @param filesystem [Y2Storage::Filesystems]
        #
        # @return [Array<MkfsOptionvalidator>]
        #
        def validators_for(filesystem)
          fs = filesystem.type.to_sym
          all_validators.find_all { |x| x[:fs].include?(fs) }.map { |x| MkfsOptionvalidator.new(x) }
        end

        # Get list of all validators.
        #
        # @return [Array<MkfsOptionvalidator>]
        #
        def all
          all_validators.map { |x| MkfsOptionvalidator.new(x) }
        end

        private

        # Get list of all validators.
        #
        # @return [Array<Hash>]
        #
        def all_validators
          ALL_VALIDATORS
        end

        # TODO
        #
        def option_value(widgets, option_id)
          widgets.find { |widget| widget.option_id == option_id }.value
        end
      end
    end
  end
end
