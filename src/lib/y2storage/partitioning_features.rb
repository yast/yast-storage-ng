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

Yast.import "ProductFeatures"

module Y2Storage
  # Mixin that enables a class to define attributes that are never exposed via
  #   #inspect, #to_s or similar methods, with the goal of preventing
  #   unintentional leaks of sensitive information in the application logs.
  module PartitioningFeatures
    def load_feature(*feature, to: nil, source: partitioning_section)
      value = feature(*feature, source: source)
      set_feature(*feature, to, value)
    end

    def load_integer_feature(*feature, to: nil, source: partitioning_section)
      value = feature(*feature, source: source)
      return nil if value.nil?

      value = value.to_i
      set_feature(*feature, to, value) if value >= 0
    end

    def load_size_feature(*feature, to: nil, source: partitioning_section)
      value = feature(*feature, source: source)
      return nil if value.nil?

      begin
        value = DiskSize.parse(value, legacy_units: true)
      rescue TypeError
        value = nil
      end
      set_feature(*feature, to, value) if value && value > DiskSize.zero
    end

    # Reads the "subvolumes" section of control.xml
    # @see SubvolSpecification.from_control_file
    def load_subvolumes_feature(*feature, to: nil, source: partitioning_section)
      value = feature(*feature, source: source)
      value = SubvolSpecification.list_from_control_xml(value)
      set_feature(*feature, to, value) if value
    end

    def load_volumes_feature(*feature, to: nil, source: partitioning_section)
      value = feature(*feature, source: source)
      return nil if value.nil?

      value = value.map { |v| VolumeSpecification.new(v) }
      set_feature(*feature, to, value)
    end

    def feature(*feature, source: partitioning_section)
      feature = feature.map(&:to_s)
      Yast::Ops.get(source, feature)
    end

  private

    def set_feature(*feature, to, value)
      attr = to || feature.last
      send(:"#{attr}=", value) unless value.nil?
    end

    def partitioning_section
      Yast::ProductFeatures.GetSection("partitioning")
    end
  end
end
