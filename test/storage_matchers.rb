# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "rspec"
require "yast"
require "storage/refinements/test_devicegraph"
require "storage/refinements/test_partition"

module Yast
  module RSpec
    # RSpec extension to add YaST Storage specific matchers
    module StorageMatchers
      using Storage::Refinements::TestDevicegraph
      using Storage::Refinements::TestPartition

      # Matches an object by its attributes (similar to RSpec's
      # #have_attributes) but honoring Storage::Refinements::TestXX
      def match_fields(field_values)
        FieldsMatcher.new(field_values)
      end
      ::RSpec::Matchers.alias_matcher :an_object_matching_fields, :match_fields
      ::RSpec::Matchers.alias_matcher :an_object_with_fields, :match_fields

      # @private
      class FieldsMatcher < ::RSpec::Matchers::BuiltIn::BaseMatcher
        def failure_message
          # This should never be called before #match, but better safe
          return "" unless @non_matching_fields && @non_present_fields
          errors = []
          if !@non_matching_fields.empty?
            errors << "these fields don't match <#{@non_matching_fields.join(", ")}>"
          end
          if !@non_present_fields.empty?
            errors << "these fields don't exist <#{@non_present_fields.join(", ")}>"
          end
          "but " + errors.join(" and ")
        end

        def failure_message_when_negated
          "but it matches"
        end

      private

        def match(expected, actual)
          @non_matching_fields = []
          @non_present_fields = []

          expected.each do |field, value|
            begin
              # TODO: change != by something more powerful, likely another
              #       RSpec matcher
              # using #instance_eval because #send does not honor refinements
              actual_value = actual.instance_eval(field.to_s)
              if actual_value != value
                @non_matching_fields << format_field(field, actual_value)
              end
            rescue NameError
              @non_present_fields << field
            end
          end
          @non_matching_fields.empty? && @non_present_fields.empty?
        end

        def format_field(field, value)
          "#{field}(#{value})"
        end
      end
    end
  end
end
