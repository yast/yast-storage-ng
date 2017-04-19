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

  def allow_dialog(dialog, action, &block)
    allow_any_instance_of(dialog).to receive(action), &block
  end

  def allow_run_select_disks(&block)
    allow_dialog(Y2Storage::Dialogs::GuidedSetup::SelectDisks, :run, &block)
  end

  def allow_run_select_root_disk(&block)
    allow_dialog(Y2Storage::Dialogs::GuidedSetup::SelectRootDisk, :run, &block)
  end

  def allow_run_select_scheme(&block)
    allow_dialog(Y2Storage::Dialogs::GuidedSetup::SelectScheme, :run, &block)
  end

  def allow_run_select_filesystem(&block)
    allow_dialog(Y2Storage::Dialogs::GuidedSetup::SelectFilesystem, :run, &block)
  end

  def allow_run_all_dialogs
    allow_run_select_disks { :next }
    allow_run_select_root_disk { :next }
    allow_run_select_scheme { :next }
    allow_run_select_filesystem { :next }
  end

  def allow_skip_dialog(dialog)
    allow_dialog(dialog, :skip?) { true }
    allow_dialog(dialog, :before_skip) { nil }
  end

  def allow_not_skip_dialog(dialog)
    allow_dialog(dialog, :skip?) { false }
  end

  def allow_not_skip_any_dialog
    allow_not_skip_dialog(Y2Storage::Dialogs::GuidedSetup::SelectDisks)
    allow_not_skip_dialog(Y2Storage::Dialogs::GuidedSetup::SelectRootDisk)
    allow_not_skip_dialog(Y2Storage::Dialogs::GuidedSetup::SelectScheme)
    allow_not_skip_dialog(Y2Storage::Dialogs::GuidedSetup::SelectFilesystem)
  end

  def expect_run_dialog(dialog)
    expect_any_instance_of(dialog).to receive(:run).once
  end

  def expect_not_run_dialog(dialog)
    expect_any_instance_of(dialog).not_to receive(:run)
  end

  def disk(name)
    instance_double(Y2Storage::Disk, name: name, size: Y2Storage::DiskSize.new(0))
  end

  subject { described_class.new(settings) }

  let(:settings) { Y2Storage::ProposalSettings.new }

  describe "#run" do
    before do
      allow_run_all_dialogs
      allow_not_skip_any_dialog
    end

    context "when a dialog is skipped" do
      let(:dialog) { Y2Storage::Dialogs::GuidedSetup::SelectRootDisk }

      before { allow_skip_dialog(dialog) }

      it "does not run that dialog" do
        expect_not_run_dialog(dialog)
        subject.run
      end

      it "runs next dialog" do
        next_dialog = Y2Storage::Dialogs::GuidedSetup::SelectScheme
        expect_run_dialog(next_dialog)
        subject.run
      end
    end

    context "when all dialogs return :next" do
      it "returns :next" do
        expect(subject.run).to eq(:next)
      end

      context "and some options are selected" do
        before do
          allow_run_select_scheme do
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
        allow_run_select_disks { :back }
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when some dialog aborts" do
      before do
        allow_run_select_scheme { :abort }
      end

      it "returns :abort" do
        expect(subject.run).to eq(:abort)
      end
    end
  end
end
