#!/usr/bin/env rspec
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

require_relative "../spec_helper"
require "y2storage/dialogs/guided_setup"

Yast.import "Wizard"
Yast.import "UI"
Yast.import "Popup"
Yast.import "Report"

RSpec.shared_context "guided setup requirements" do
  include Yast::UIShortcuts

  def term_with_id(regexp, content)
    content.nested_find do |nested|
      next unless nested.is_a?(Yast::Term)
      nested.params.any? { |i| i.is_a?(Yast::Term) && i.value == :id && regexp.match?(i.params.first) }
    end
  end

  def expect_select(id, value = true)
    expect(Yast::UI).to receive(:ChangeWidget).once.with(Id(id), :Value, value)
  end

  def expect_not_select(id, value = true)
    expect(Yast::UI).not_to receive(:ChangeWidget).with(Id(id), :Value, value)
  end

  def expect_enable(id)
    expect(Yast::UI).to receive(:ChangeWidget).once.with(Id(id), :Enabled, true)
  end

  def expect_not_enable(id)
    expect(Yast::UI).not_to receive(:ChangeWidget).with(Id(id), :Enabled, true)
  end

  def expect_disable(id)
    expect(Yast::UI).to receive(:ChangeWidget).once.with(Id(id), :Enabled, false)
  end

  def select_widget(id, value = true)
    allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(value)
  end

  def not_select_widget(id)
    allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(false)
  end

  def select_disks(disks)
    disks.each { |d| select_widget(d) }
    (all_disks - disks).each { |d| not_select_widget(d) }
  end

  def disk(name, partitions = {})
    disk = instance_double(Y2Storage::Disk, name: name, size: Y2Storage::DiskSize.new(0))
    parts =
      if partitions && partitions[name]
        partitions[name].map { |pname| partition_double(pname) }
      else
        []
      end
    allow(disk).to receive(:partitions).and_return parts
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

    allow(Yast::UI).to receive(:ChangeWidget).and_call_original
    allow(Yast::UI).to receive(:QueryWidget).and_call_original

    allow(guided_setup).to receive(:settings).and_return(settings)

    allow(analyzer).to receive(:candidate_disks)
      .and_return(all_disks.map { |d| disk(d, partitions) })

    allow(analyzer).to receive(:device_by_name) { |d| disk(d, partitions) }

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
