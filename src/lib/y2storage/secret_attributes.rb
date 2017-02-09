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

module Y2Storage
  # Mixin that enables a class to define attributes that are never exposed via
  # #inspect, #to_s or similar methods, with the goal of preventing
  # unintentional leaks of sensitive information in the application logs.
  module SecretAttributes
    # Inner class to store the value of the attribute without exposing it
    # directly
    class Attribute
      def initialize(value)
        @value = value
      end

      def value
        @value
      end

      def to_s
        value.nil? ? "nil" : "<secret>"
      end

      alias_method :inspect, :to_s
      
      def instance_variables
        # This adds even an extra barrier, just in case some formatter tries to
        # use deep instrospection
        []
      end
    end

    module ClassMethods
      # Similar to .attr_accessor but with additional mechanisms to prevent
      # exposing the internal value of the attribute
      def secret_attr(name)
        define_method(:"#{name}") do
          attribute = instance_variable_get(:"@#{name}")
          attribute ? attribute.value : nil
        end

        define_method(:"#{name}=") do |value|
          instance_variable_set(:"@#{name}", Attribute.new(value))
          value
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
