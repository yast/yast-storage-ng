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

require "y2storage/boot_requirements_checker"
require "y2storage/devices_lists"
require "y2storage/disk_analyzer"
require "y2storage/disk_size"
require "y2storage/fake_device_factory"
require "y2storage/free_disk_space"
require "y2storage/planned_volume"
require "y2storage/planned_volumes_list"
require "y2storage/proposal"
require "y2storage/proposal_settings"
require "y2storage/refinements"
require "y2storage/storage_manager"
require "y2storage/yaml_writer"
