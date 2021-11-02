#!/usr/bin/env rspec
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

require_relative "../spec_helper"
require_relative "#{TEST_PATH}/support/widgets_context"
require "y2storage/dialogs/guided_setup"

Yast.import "Wizard"
Yast.import "Popup"
Yast.import "Report"

RSpec.shared_context "guided setup requirements" do
  include_context "widgets"

  alias_method :term_with_id, :find_widget

  def select_disks(disks)
    disks.each { |d| select_widget(d) }
    (all_disks - disks).each { |d| not_select_widget(d) }
  end

  # Builds and returns a Disk double
  #
  # @param name [String] device name of the disk
  # @param args [Hash] the key :partitions is turned into a collection of Partition doubles to mock
  #   Disk#partitions, the rest are passed to the double instance as mocked messages
  def disk(name, args = {})
    defaults = { size: Y2Storage::DiskSize.new(0), boss?: false, sd_card?: false, partitions: {} }
    args = defaults.merge(args)
    args[:name] = name

    partitions = args.delete(:partitions)
    parts =
      if partitions && partitions[name]
        partitions[name].map { |pname| partition_double(pname) }
      else
        []
      end

    disk = instance_double(Y2Storage::Disk, **args)
    allow(disk).to receive(:partitions).and_return parts
    allow(disk).to receive(:is?).with(:sd_card).and_return false

    disk
  end

  def partition_double(name)
    instance_double(Y2Storage::Partition, name: "/dev/#{name}")
  end

  before do
    # Mock opening and closing the dialog
    allow(Yast::Wizard).to receive(:CreateDialog).and_return(true)
    allow(Yast::Wizard).to receive(:CloseDialog).and_return(true)
    # Always confirm when clicking in abort
    allow(Yast::Popup).to receive(:ConfirmAbort).and_return(true)
    # Always close report warning
    allow(Yast::Report).to receive(:Warning).and_return(true)

    allow(Yast::UI).to receive(:UserInput).and_return(:next, :abort)

    allow(guided_setup).to receive(:settings).and_return(settings)

    allow(analyzer).to receive(:candidate_disks)
      .and_return(all_disks.map { |d| disk(d, partitions: partitions) })

    allow(analyzer).to receive(:device_by_name) { |d| disk(d, partitions: partitions) }

    allow(analyzer).to receive(:installed_systems)
      .and_return(windows_systems + linux_systems)

    allow(analyzer).to receive(:windows_systems).and_return(windows_systems)
    allow(analyzer).to receive(:linux_systems).and_return(linux_systems)

    allow(analyzer).to receive(:windows_partitions).and_return(windows_partitions)
    allow(analyzer).to receive(:linux_partitions).and_return(linux_partitions)
  end

  let(:guided_setup) { Y2Storage::Dialogs::GuidedSetup.new(settings, analyzer) }

  let(:devicegraph) { instance_double(Y2Storage::Devicegraph) }

  let(:analyzer) { instance_double(Y2Storage::DiskAnalyzer) }

  let(:settings) { Y2Storage::ProposalSettings.new_for_current_product }

  let(:all_disks) { [] }
  let(:candidate_disks) { [] }
  let(:selected_disks) { [] }

  let(:windows_systems) { [] }
  let(:linux_systems) { [] }
  let(:windows_partitions) { [] }
  let(:linux_partitions) { [] }

  let(:partitions) { {} }
end
