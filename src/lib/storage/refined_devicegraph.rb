#!/usr/bin/env ruby
#
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

require "storage"

module Yast
  module Storage
    # Refinement for ::Storage::Devicegraph with some commodity methods
    module RefinedDevicegraph
      refine ::Storage::Devicegraph do
        # Set of actions needed to get the devicegraph starting with the current
        # probed one
        #
        # @return [::Storage::Actiongraph]
        def actiongraph(storage: StorageManager.instance)
          ::Storage::Actiongraph.new(storage, storage.probed, self)
        end
      end
    end
  end
end
