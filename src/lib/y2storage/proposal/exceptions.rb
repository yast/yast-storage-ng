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

module Y2Storage
  class Proposal
    class Error < RuntimeError
    end
    # There is no enough space in the disk
    class NoDiskSpaceError < Error
    end
    # There are not available partition slots in the disk
    class NoMorePartitionSlotError < Error
    end
    # It was not possible to find a suitable root device
    class NoSuitableDeviceError < Error
    end
    # It's not possible to propose a bootable layout for the root device
    class NotBootableError < Error
    end
    # A method was called more times than expected
    class UnexpectedCallError < Error
    end
  end
end
