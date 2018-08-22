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

require_relative "../../spec_helper.rb"
require_relative "#{TEST_PATH}/support/guided_setup_context"

describe Y2Storage::Dialogs::GuidedSetup::SelectRootDisk do
  include_context "guided setup requirements"

  subject { described_class.new(guided_setup) }

  before do
    settings.candidate_devices = candidate_disks
  end

  describe "#skip?" do
    context "when there is only one disk" do
      let(:candidate_disks) { ["/dev/sda"] }

      context "and there are no partitions" do
        let(:partitions) { { "/dev/sda" => [] } }

        it "returns true" do
          expect(subject.skip?).to be(true)
        end
      end

      context "and it contains partitions" do
        let(:partitions) { { "/dev/sda" => ["sda1"] } }

        it "returns false" do
          expect(subject.skip?).to be(false)
        end
      end
    end

    context "where there are several disks" do
      let(:candidate_disks) { ["/dev/sda", "/dev/sdb"] }

      it "returns false" do
        expect(subject.skip?).to be(false)
      end
    end
  end

  describe "#run" do
    let(:all_disks) { ["/dev/sda", "/dev/sdb"] }
    let(:candidate_disks) { all_disks }

    before do
      select_widget(:windows_action, :not_modify) unless windows_partitions.empty?
      select_widget(:linux_delete_mode, :all)
      select_widget(:other_delete_mode, :all)
    end

    context "when settings has not a root disk" do
      before { settings.root_device = nil }

      it "selects 'any' option by default" do
        expect_select(:any_disk)
        expect_not_select("/dev/sda")
        expect_not_select("/dev/sdb")
        subject.run
      end
    end

    context "when settings has a root disk" do
      before { settings.root_device = "/dev/sda" }

      it "selects that disk by default" do
        expect_select("/dev/sda")
        expect_not_select("/dev/sdb")
        subject.run
      end
    end

    context "when there is only one disk" do
      let(:all_disks) { ["/dev/sda"] }

      it "updates settings with that disk" do
        subject.run
        expect(subject.settings.root_device).to eq("/dev/sda")
      end
    end

    context "when there are several disks" do
      context "and a disk is selected" do
        before { select_disks(["/dev/sdb"]) }

        it "updates settings with the selected disk" do
          subject.run
          expect(subject.settings.root_device).to eq("/dev/sdb")
        end
      end

      context "and 'any' option is selected" do
        before { select_disks([:any_disk]) }

        it "updates settings with root disk as nil" do
          subject.run
          expect(subject.settings.root_device).to be_nil
        end
      end
    end

    context "when no disk has a Windows system" do
      let(:windows_partitions) { [] }

      it "does not show the windows actions" do
        widget = term_with_id(/windows_action/, subject.send(:dialog_content))
        expect(widget).to be_nil
      end
    end

    context "when some disk has a Windows system" do
      let(:windows_partitions) { [partition_double("sda1")] }

      it "shows the windows actions" do
        widget = term_with_id(/windows_action/, subject.send(:dialog_content))
        expect(widget).to_not be_nil
      end

      context "when settings.windows_delete_mode is set to :all" do
        let(:windows_partitions) { [partition_double("sda1")] }
        before { settings.windows_delete_mode = :all }

        it "sets the Windows action to :always_remove" do
          expect_select(:windows_action, :always_remove)
          subject.run
        end
      end

      context "when settings.windows_delete_mode is set to :ondemand" do
        let(:windows_partitions) { [partition_double("sda1")] }
        before { settings.windows_delete_mode = :ondemand }

        it "sets the Windows action to :remove" do
          expect_select(:windows_action, :remove)
          subject.run
        end
      end

      context "when settings.windows_delete_mode is set to :none" do
        let(:windows_partitions) { [partition_double("sda1")] }
        before { settings.windows_delete_mode = :none }

        context "and resizing is allowed" do
          before { settings.resize_windows = true }

          it "sets the Windows action to :resize" do
            expect_select(:windows_action, :resize)
            subject.run
          end
        end

        context "and resizing is not allowed" do
          before { settings.resize_windows = false }

          it "sets the Windows action to :not_modify" do
            expect_select(:windows_action, :not_modify)
            subject.run
          end
        end
      end

      context "updating settings regarding Windows" do
        context "if :not_modify is selected for Windows action" do
          before { select_widget(:windows_action, :not_modify) }

          it "updates the settings according" do
            subject.run
            expect(settings.windows_delete_mode).to eq :none
            expect(settings.resize_windows).to eq false
          end
        end

        context "if :resize is selected for Windows action" do
          before { select_widget(:windows_action, :resize) }

          it "updates the settings according" do
            subject.run
            expect(settings.windows_delete_mode).to eq :none
            expect(settings.resize_windows).to eq true
          end
        end

        context "if :remove is selected for Windows action" do
          before { select_widget(:windows_action, :remove) }

          it "updates the settings according" do
            subject.run
            expect(settings.windows_delete_mode).to eq :ondemand
            expect(settings.resize_windows).to eq true
          end
        end

        context "if :always_remove is selected for Windows action" do
          before { select_widget(:windows_action, :always_remove) }

          it "updates the settings according" do
            subject.run
            expect(settings.windows_delete_mode).to eq :all
          end
        end
      end
    end

    context "when no disk has a Linux partition" do
      let(:linux_partitions) { [] }

      it "disables linux actions" do
        expect_disable(:linux_delete_mode)
        subject.run
      end
    end

    context "when some disk has Linux partitions" do
      let(:linux_partitions) { [partition_double("sda2"), partition_double("sda3")] }

      it "enables linux actions" do
        expect_enable(:linux_delete_mode)
        subject.run
      end
    end

    context "when all the partitions are Windows systems or Linux" do
      let(:windows_partitions) { [partition_double("sda1")] }
      let(:linux_partitions) { [partition_double("sda2"), partition_double("sda3")] }
      let(:partitions) do
        { "/dev/sda" => [partition_double("sda1"), partition_double("sda2"), partition_double("sda3")] }
      end

      it "disables other actions" do
        expect_disable(:other_delete_mode)
        subject.run
      end
    end

    context "when there are other kind of partitions (not Linux or Windows system)" do
      let(:windows_partitions) { [] }
      let(:linux_partitions) { [partition_double("sda2"), partition_double("sda3")] }
      let(:partitions) do
        { "/dev/sda" => [partition_double("sda1"), partition_double("sda2"), partition_double("sda3")] }
      end

      it "enables other actions" do
        expect_enable(:other_delete_mode)
        subject.run
      end
    end

    it "selects the right linux action by default" do
      settings.linux_delete_mode = :ondemand
      expect_select(:linux_delete_mode, :ondemand)
      subject.run

      settings.linux_delete_mode = :all
      expect_select(:linux_delete_mode, :all)
      subject.run
    end

    it "selects the right other action by default" do
      settings.other_delete_mode = :ondemand
      expect_select(:other_delete_mode, :ondemand)
      subject.run

      settings.other_delete_mode = :all
      expect_select(:other_delete_mode, :all)
      subject.run
    end

    describe "updating settings regarding linux partitions" do
      context "if :ondemand is selected for linux_delete_mode" do
        before { select_widget(:linux_delete_mode, :ondemand) }

        it "updates the settings according" do
          subject.run
          expect(settings.linux_delete_mode).to eq :ondemand
        end
      end

      context "if :all is selected for linux_delete_mode" do
        before { select_widget(:linux_delete_mode, :all) }

        it "updates the settings according" do
          subject.run
          expect(settings.linux_delete_mode).to eq :all
        end
      end
    end

    describe "updating settings regarding other partitions" do
      context "if :all is selected for other_delete_mode" do
        before { select_widget(:other_delete_mode, :all) }

        it "updates the settings according" do
          subject.run
          expect(settings.other_delete_mode).to eq :all
        end
      end

      context "if :none is selected for other_delete_mode" do
        before { select_widget(:other_delete_mode, :none) }

        it "updates the settings according" do
          subject.run
          expect(settings.other_delete_mode).to eq :none
        end
      end
    end
  end
end
