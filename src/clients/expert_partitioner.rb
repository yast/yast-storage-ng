# Copyright (c) 2014 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact Novell about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "expert_partitioner/main_dialog"

storage_environment =
  case ENV.fetch("YAST2_STORAGE_PROBE_MODE", "STANDARD")
  # probe and write probed data to disk
  when "STANDARD_WRITE_DEVICEGRAPH"
    ::Storage::Environment.new(
      true,
      ::Storage::ProbeMode_STANDARD_WRITE_DEVICEGRAPH,
      ::Storage::TargetMode_DIRECT
    )
  # instead of probing read probed data from disk
  when "READ_DEVICEGRAPH"
    ::Storage::Environment.new(
      true,
      ::Storage::ProbeMode_READ_DEVICEGRAPH,
      ::Storage::TargetMode_DIRECT
    )
  # probe
  else
    ::Storage::Environment.new(true)
  end

Yast::Storage::StorageManager.create_instance(storage_environment) if storage_environment
ExpertPartitioner::MainDialog.new.run
