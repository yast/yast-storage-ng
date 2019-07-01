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
# TODO: just temporary client for testing partitioner with different hardware setup
# call with `yast2 partitioner_testing <path_to_yaml>`

require "yast"
require "y2partitioner/clients/main"
require "y2storage"

# Comment next line and run the file with root privileges to test system lock
Y2Storage::StorageManager.create_test_instance

arg = Yast::WFM.Args.first
case arg
when /.ya?ml$/
  Y2Storage::StorageManager.instance(mode: :rw).probe_from_yaml(arg)
when /.xml$/
  # note: support only xml device graph, not xml output of probing commands
  Y2Storage::StorageManager.instance(mode: :rw).probe_from_xml(arg)
else
  raise "Invalid testing parameter #{arg}, expecting foo.yml or foo.xml."
end

Y2Partitioner::Clients::Main.new.run(allow_commit: false)
