#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage/clients/finish"

describe Y2Storage::Clients::Finish do
  subject(:client) { described_class.new }

  describe "#run" do
    before do
      allow(Yast::WFM).to receive(:Args).with(no_args).and_return(args)
      allow(Yast::WFM).to receive(:Args) { |n| n.nil? ? args : args[n] }

      allow(Yast::SCR).to receive(:Read)
      allow(Yast::SCR).to receive(:Write)
    end

    context "Info" do
      let(:args) { ["Info"] }

      it "returns a hash describing the client" do
        expect(client.run).to be_kind_of(Hash)
      end
    end

    context "Write" do
      let(:args) { ["Write"] }
      before { fake_scenario(scenario) }

      let(:scenario) { "lvm-two-vgs" }

      it "returns true" do
        expect(client.run).to eq(true)
      end

      it "updates sysconfig file" do
        mount_by_id = Y2Storage::Filesystems::MountByType::ID

        manager = Y2Storage::StorageManager.instance
        manager.default_mount_by = mount_by_id

        expect(Yast::SCR).to receive(:Write) do |path, value|
          expect(path.to_s).to match(/DEVICE_NAMES/)
          expect(value).to eq("id")
        end

        client.run
      end

      context "if Multipath is used in the target system" do
        let(:scenario) { "multipath-formatted.xml" }

        it "enables multipathd" do
          expect(Yast::Service).to receive(:Enable).with("multipathd")
          client.run
        end
      end

      context "if Multipath is not used in the target system" do
        let(:scenario) { "output/windows-pc" }

        it "does not enable any service" do
          expect(Yast::Service).to_not receive(:Enable)
          client.run
        end
      end
    end
  end
end
