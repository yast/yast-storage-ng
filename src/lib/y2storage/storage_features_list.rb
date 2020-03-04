# Copyright (c) [2016-2017,2019-2020] SUSE LLC
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
require "forwardable"
require "y2storage/storage_feature"

module Y2Storage
  # List of storage features
  #
  # In libstorage-ng a set of features is representend by an integer
  # bit-field that must be processed to get the list of features, each one
  # represented by a bit-mask referenced by a constant.
  #
  # This class turns one of those bit-fields into an object-oriented collection
  # of {StorageFeature} objects.
  class StorageFeaturesList
    include Yast::Logger
    include Enumerable
    extend Forwardable

    def_delegators :@features, :each, :empty?

    # Constructor
    #
    # @param bits [Integer, nil] bit-field representing all the features that
    #   must be part of the list. If nil, the list will contain all the known
    #   storage features.
    def initialize(bits = nil)
      @features = StorageFeature.all.dup
      @features.select! { |f| f.in_bitfield?(bits) } if bits
    end

    # Return a list of all software packages required for the storage features
    # included in the list.
    #
    # @return [Array<String>] list of package names
    def pkg_list
      return @pkg_list unless @pkg_list.nil?

      @pkg_list = []
      each do |feature|
        log.info("Feature #{feature.id} requires #{feature.pkg_list}")
        @pkg_list.concat(feature.pkg_list)
      end
      @pkg_list.uniq!

      log.info("Storage feature packages: #{@pkg_list}")

      @pkg_list
    end
  end
end
