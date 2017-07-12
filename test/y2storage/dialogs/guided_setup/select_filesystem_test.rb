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

require_relative "#{TEST_PATH}/support/guided_setup_context"

describe Y2Storage::Dialogs::GuidedSetup::SelectFilesystem do
  include_context "guided setup requirements"

  subject { described_class.new(guided_setup) }

  before do
    # Set some default values
    filesystem = Y2Storage::Filesystems::Type::BTRFS
    select_widget(:root_filesystem, filesystem.to_sym)
    select_widget(:home_filesystem, filesystem.to_sym)
  end

  describe "#run" do
    it "selects root filesystem from settings" do
      filesystem = Y2Storage::Filesystems::Type::EXT4
      settings.root_filesystem_type = filesystem

      expect_select(:root_filesystem, filesystem.to_sym)
      subject.run
    end

    it "selects home filesystem from settings" do
      filesystem = Y2Storage::Filesystems::Type::EXT3
      settings.home_filesystem_type = filesystem

      expect_select(:home_filesystem, filesystem.to_sym)
      subject.run
    end

    it "saves settings correctly" do
      root_filesystem = Y2Storage::Filesystems::Type::BTRFS
      home_filesystem = Y2Storage::Filesystems::Type::EXT4
      select_widget(:root_filesystem, root_filesystem.to_sym)
      select_widget(:home_filesystem, home_filesystem.to_sym)
      select_widget(:snapshots)
      select_widget(:separate_home)

      subject.run
      expect(subject.settings.root_filesystem_type).to eq(root_filesystem)
      expect(subject.settings.home_filesystem_type).to eq(home_filesystem)
      expect(subject.settings.use_snapshots).to eq(true)
      expect(subject.settings.use_separate_home).to eq(true)
    end

    context "when settings has not snapshots" do
      before do
        settings.use_snapshots = false
      end

      it "does not select snapshots by default" do
        expect_not_select(:snapshots)
        subject.run
      end
    end

    context "when settings has snapshots" do
      before do
        settings.use_snapshots = true
      end

      it "selects snapshots by default" do
        expect_select(:snapshots)
        subject.run
      end
    end

    context "when settings has not separate home" do
      before do
        settings.use_separate_home = false
      end

      it "does not select separate home by default" do
        expect_not_select(:separate_home)
        subject.run
      end
    end

    context "when settings has separate home" do
      before do
        settings.use_separate_home = true
      end

      it "selects separate home by default" do
        expect_select(:separate_home)
        subject.run
      end
    end

    context "when btrfs is selected for root partition" do
      before do
        select_widget(:root_filesystem, Y2Storage::Filesystems::Type::BTRFS.to_sym)
      end

      it "enables snapshots option" do
        expect_enable(:snapshots)
        subject.run
      end
    end

    context "when other filesystem is selected for root partition" do
      before do
        select_widget(:root_filesystem, Y2Storage::Filesystems::Type::EXT4.to_sym)
      end

      it "disables snapshots option" do
        expect_disable(:snapshots)
        subject.run
      end
    end

    context "when separate home is selected" do
      before do
        select_widget(:separate_home)
      end

      it "enables filesystem selection for home" do
        expect_enable(:home_filesystem)
        subject.run
      end
    end

    context "when separate home is not selected" do
      before do
        not_select_widget(:separate_home)
      end

      it "disables filesystem selection for home" do
        expect_disable(:home_filesystem)
        subject.run
      end
    end
  end
end
