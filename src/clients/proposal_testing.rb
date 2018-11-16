# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
# TODO: just temporary client for testing partitioner with different hardware setup
# call with `yast2 partitioner_testing <path_to_yaml>`

require "yast"
require "y2storage"
require "y2storage/clients/inst_disk_proposal"

# Usage:
#
# /sbin/yast2 proposal_testing path_to_devicegraph_file [path_to_control_file]
#
# Example:
#
# $ Y2DIR=src/ /sbin/yast2 proposal_testing test/data/devicegraphs/empty_disks.yml
#   test/data/control_files/volumes_ng/control.SLE-like.xml

Yast.import "ProductFeatures"

def load_devicegraph
  file = Yast::WFM.Args.first

  case file
  when /.ya?ml$/
    Y2Storage::StorageManager.instance(mode: :rw).probe_from_yaml(file)
  when /.xml$/
    # note: support only xml device graph, not xml output of probing commands
    Y2Storage::StorageManager.instance(mode: :rw).probe_from_xml(file)
  else
    raise "Invalid testing parameter #{file}, expecting foo.yml or foo.xml."
  end
end

def load_control_file
  file = Yast::WFM.Args.last
  return if file.nil?

  features = Yast::XML.XMLToYCPFile(file)
  Yast::ProductFeatures.Import(features)
end

Y2Storage::StorageManager.create_test_instance

load_devicegraph
load_control_file

Y2Storage::Clients::InstDiskProposal.new.run
