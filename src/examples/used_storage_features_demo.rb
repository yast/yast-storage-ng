#!/usr/bin/env ruby
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

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "y2storage"

if !Process.euid.zero?
  STDERR.puts "You need to run this script as 'root'."
  exit 1
end

devicegraph = Y2Storage::StorageManager.instance.probed
used_features = Y2Storage::UsedStorageFeatures.new(devicegraph)
features = used_features.collect_features
print("Used storage features: #{features}\n")
pkg_list = used_features.feature_packages
print("Needed packages: #{pkg_list}\n")
