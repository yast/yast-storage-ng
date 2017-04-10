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

describe Y2Storage::Dialogs::GuidedSetup do

  def run_dialog(dialog, &block)
    allow_any_instance_of(dialog).to receive(:run), &block
  end

  def run_select_disks(&block)
    run_dialog(Y2Storage::Dialogs::GuidedSetup::SelectDisks, &block)
  end

  def run_select_root_disk(&block)
    run_dialog(Y2Storage::Dialogs::GuidedSetup::SelectRootDisk, &block)
  end

  def run_select_scheme(&block)
    run_dialog(Y2Storage::Dialogs::GuidedSetup::SelectScheme, &block)
  end

  def run_select_filesystem(&block)
    run_dialog(Y2Storage::Dialogs::GuidedSetup::SelectFilesystem, &block)
  end

  subject { described_class.new(fake_devicegraph, settings) }

  before do
    fake_scenario(scenario)
    # Mock reading of installed systems
    allow_any_instance_of(Y2Storage::DiskAnalyzer).to receive(:installed_systems).and_return({})
  end

  let(:settings) { Y2Storage::ProposalSettings.new }

  describe "#run" do
    let(:scenario) { "gpt_and_msdos" }

    context "when all dialogs return :next" do
      before do
        run_select_disks { :next }
        run_select_root_disk { :next }
        run_select_scheme { :next }
        run_select_filesystem { :next }
      end

      it "returns :next" do
        expect(subject.run).to eq(:next)
      end

      context "and some options are selected" do
        before do
          run_select_scheme do
            subject.settings.use_lvm = true
            :next
          end
        end

        it "updates settings" do
          subject.run
          expect(subject.settings.use_lvm).to eq(true)
        end
      end
    end

    context "when first dialog returns :back" do
      before do
        run_select_disks { :back }
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when some dialog aborts" do
      before do
        run_select_disks { :next }
        run_select_root_disk { :next }
        run_select_scheme { :abort }
        run_select_filesystem { :next }
      end

      it "returns :abort" do
        expect(subject.run).to eq(:abort)
      end
    end
  end
end
