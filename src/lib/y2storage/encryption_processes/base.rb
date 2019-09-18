# encoding: utf-8
#
# Copyright (c) [2019] SUSE LLC
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

module Y2Storage
  module EncryptionProcesses
    class Base
      include Yast::Logger

      def initialize(method)
        @method = method
      end

      attr_reader :method

      def self.used_for?(_encryption)
        false
      end

      def self.available?
        true
      end

      def create_device(blk_device, dm_name)
        enc = blk_device.create_encryption(dm_name || "", encryption_type)
        enc.encryption_process = self
        enc
      end

      def pre_commit(device)
        log.info "No pre-commit action to perform by #{self.class.name} for #{device}"
      end

      def post_commit(device)
        log.info "No post-commit action to perform by #{self.class.name} for #{device}"
      end
    end
  end
end
