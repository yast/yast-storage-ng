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

require "y2storage/storage_class_wrapper"

module Y2Storage
  # Container of the actions that must be performed in one devicegraph to make
  # it equivalent to another one.
  #
  # This is a wrapper for Storage::Devicegraph
  class Actiongraph
    include StorageClassWrapper
    wrap_class Storage::Actiongraph

    # @!method empty?
    #   Checks whether the actiongraph is empty (no actions)
    storage_forward :empty?

    # @!method print_graph
    #   Prints a textual representation of the graph through stdout
    storage_forward :print_graph

    # @!write_graphviz(filename, graphviz_flags)
    #   Writes the devicegraph to a file in Graphviz format
    storage_forward :write_graphviz

    # @!commit_actions_as_strings
    #   @return [Array<String>] Action descriptions sorted according to
    #     dependencies among actions
    storage_forward :commit_actions_as_strings
  end
end
