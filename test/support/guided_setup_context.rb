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

  def is_selected(id, value = true)
    allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(value)
  end

  def is_not_selected(id)
    allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(false)
  end

  def all_disks
    disks_data.map { |d| d[:name] }
  end

  def select_disks(disks)
    disks.each { |d| is_selected(d) }
    (all_disks - disks).each { |d| is_not_selected(d) }
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
  end

  let(:guided_setup) do
    instance_double(
      Y2Storage::Dialogs::GuidedSetup,
      disks_data: disks_data,
      settings: settings
    )
  end

  let(:disks_data) { {} }

  let(:settings) { Y2Storage::ProposalSettings.new }
end
