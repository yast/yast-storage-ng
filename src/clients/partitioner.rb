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
require "y2partitioner/clients/main"
require "y2partitioner/cli"

# To test with simulated hardware (from a bug report?), use
#   yast2 partitioner_testing foo.xml
#   yast2 partitioner_testing foo.yml

if Yast::WFM.Args.empty?
  Y2Partitioner::Clients::Main.new.run
else
  Y2Partitioner::CLI.run
end
