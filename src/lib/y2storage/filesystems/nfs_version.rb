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
require "yast2/equatable"

module Y2Storage
  module Filesystems
    class NfsVersion
      extend Yast::I18n
      include Yast::I18n
      include Yast2::Equatable

      textdomain "storage"

      # Properties for each NFS version
      VERSIONS = {
        nil   => {
          name: N_("Any")
        },
        "3"   => {
          name: N_("NFSv3")
        },
        "4"   => {
          name: N_("NFSv4")
        },
        "4.1" => {
          name: N_("NFSv4.1")
        },
        "4.2" => {
          name: N_("NFSv4.2")
        }
      }.freeze

      private_constant :VERSIONS

      attr_reader :value

      eql_attr :value

      def self.all
        VERSIONS.keys.map { |v| new(v) }
      end

      def initialize(value = nil)
        textdomain "storage"

        value = "4" if value == "4.0"
        @value = value
      end

      def name
        VERSIONS[value][:name]
      end

      def any?
        value.nil?
      end

      # Whether the system infrastructure associated to NFSv4 (e.g. enabled
      # NFS4_SUPPORT in sysconfig/nfs) is needed in order to use this version of
      # the protocol.
      #
      # @return [Boolean]
      def need_v4_support?
        return false if value.nil?
        value.start_with?("4")
      end
    end
  end
end
