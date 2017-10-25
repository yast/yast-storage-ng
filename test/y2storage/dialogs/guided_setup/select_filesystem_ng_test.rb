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
require_relative "#{TEST_PATH}/support/proposal_context"
require "pp"

describe Y2Storage::Dialogs::GuidedSetup::SelectFilesystem::Ng do
  include_context "proposal"
  include_context "guided setup requirements"

  let(:scenario) { "empty_hard_disk_gpt_25GiB" }
  let(:control_file_content) { Yast::XML.XMLToYCPFile(File.join(DATA_PATH, "control_files/volumes_ng", control_file)) }
  let(:settings) { Y2Storage::ProposalSettings.new_for_current_product }

  subject { described_class.new(guided_setup) }

  before do
    Yast::ProductFeatures.Import(control_file_content)
  end

  context "In a CaaSP configuration with root and separate /var/lib/docker" do
    let(:control_file) { "control.CAASP.xml" }

    describe "#settings" do
      it "uses NG settings" do
        expect(subject.settings.ng_format?).to be(true)
      end

      it "has 2 volumes" do
        expect(subject.settings.volumes.size).to be == 2
      end

      it "has a root_vol with Btrfs" do
        expect(subject.root_vol.mount_point).to eq "/"
        expect(subject.root_vol.fs_type).to eq Y2Storage::Filesystems::Type::BTRFS
        expect(subject.root_vol.proposed).to be(true)
      end

      it "enforces snapshots for the root_vol" do
        expect(subject.root_vol.snapshots).to be(true)
        expect(subject.root_vol.snapshots_configurable).to be(false)
      end

      it "does not have a home_vol" do
        expect(subject.home_vol).to be nil
      end

      it "does not have a swap_vol" do
        expect(subject.home_vol).to be nil
      end

      it "has one other_vol /var/lib/docker with Btrfs" do
        expect(subject.other_volumes.size).to be == 1
        expect(subject.other_volumes.first.mount_point).to eq "/var/lib/docker"
        expect(subject.other_volumes.first.fs_type).to eq Y2Storage::Filesystems::Type::BTRFS
      end
    end

    describe "#normalized_id" do
      it "leaves normal strings untouched" do
        expect(subject.send(:normalized_id, "foo")).to eq "foo"
      end

      it "changes slashes and other special characters to underscores" do
        expect(subject.send(:normalized_id, "/my/weird/path")).to eq "my_weird_path"
        expect(subject.send(:normalized_id, "!some$weird*name!")).to eq "some_weird_name"
      end

      it "cleans up underscores" do
        expect(subject.send(:normalized_id, "/$my/weird!!/path?!?")).to eq "my_weird_path"
      end
    end

    describe "#propose_widget_id" do
      it "returns the expected normalized widget IDs" do
        expect(subject.send(:propose_widget_id, "Home")).to eq :propose_home
        expect(subject.send(:propose_widget_id, "/home")).to eq :propose_home
        expect(subject.send(:propose_widget_id, "/var/lib/docker")).to eq :propose_var_lib_docker
      end
    end

    describe "#fs_type_widget_id" do
      it "returns the expected normalized widget IDs" do
        expect(subject.send(:fs_type_widget_id, "Home")).to eq :home_fs_type
        expect(subject.send(:fs_type_widget_id, "/home")).to eq :home_fs_type
        expect(subject.send(:fs_type_widget_id, "/var/lib/docker")).to eq :var_lib_docker_fs_type
      end
    end

    describe "#run" do
      it "does not go up in smoke" do
        subject.run
      end

      it "selects the root filesystem type from the settings" do
        fs_type = Y2Storage::Filesystems::Type::EXT4
        subject.root_vol.send(:fs_type=, fs_type)

        expect_select(:root_fs_type, fs_type.to_sym)
        subject.run
      end

      it "saves settings correctly" do
        root_fs_type = Y2Storage::Filesystems::Type::XFS
        var_lib_docker_fs_type = Y2Storage::Filesystems::Type::EXT4
        select_widget(:root_fs_type, root_fs_type.to_sym)
        select_widget(:var_lib_docker_fs_type, var_lib_docker_fs_type.to_sym)
        select_widget(:propose_var_lib_docker)
        select_widget(:snapshots)

        subject.run

        var_lib_docker_vol = subject.other_volumes.first
        expect(subject.root_vol.fs_type).to eq(root_fs_type)
        expect(subject.root_vol.proposed?).to eq(true)
        expect(subject.root_vol.snapshots?).to eq(true)

        expect(var_lib_docker_vol.fs_type).to eq(var_lib_docker_fs_type)
        expect(var_lib_docker_vol.proposed?).to eq(true)
      end
    end
  end
end
