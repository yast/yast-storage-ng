#!/usr/bin/env ruby
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

# Usage:
#   Y2DIR=../src/ /sbin/yast2 proposal_settings_dialog.rb example_control.xml fake_devicegraph.yml

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup"
require "pp"

DATA_DIR = "../../test/data"
FALLBACK_CONTROL_FILE = DATA_DIR + "/control_files/volumes_ng/control.SLE-with-data.xml"
FALLBACK_DEVICEGRAPH_FILE = DATA_DIR + "/devicegraphs/empty_hard_disk_gpt_50GiB.yml"

control_file = Yast::WFM.Args[0] || FALLBACK_CONTROL_FILE
devicegraph_file = Yast::WFM.Args[1] || FALLBACK_DEVICEGRAPH_FILE

manager = Y2Storage::StorageManager.create_test_instance
manager.probe_from_yaml(devicegraph_file)

file_content = Yast::XML.XMLToYCPFile(control_file)
Yast::ProductFeatures.Import(file_content)
settings = Y2Storage::ProposalSettings.new_for_current_product

dialog = Y2Storage::Dialogs::GuidedSetup.new(settings, manager.probed_disk_analyzer)
dialog.run

puts "Resulting settings:\n"
pp dialog.settings
:next
