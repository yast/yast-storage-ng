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

module Y2Storage
  module Refinements
    # Refinement for ::Storage::Devicegraph with some commodity methods
    module Devicegraph
      refine ::Storage::Devicegraph do
        # Set of actions needed to get this devicegraph
        #
        # By default the starting point is the probed devicegraph
        #
        # @param from [Devicegraph] starting graph to calculate the actions
        #       If nil, the probed devicegraph is used.
        # @return [::Storage::Actiongraph]
        def actiongraph(from: nil, storage: StorageManager.instance)
          from ||= storage.probed
          ::Storage::Actiongraph.new(storage, from, self)
        end

        alias_method :orig_copy, :copy
        # Returns a copy of the devicegraph
        #
        # @return [::Storage::Devicegraph]
        def copy
          new_graph = ::Storage::Devicegraph.new
          orig_copy(new_graph)
          new_graph
        end
      end
    end
  end
end
