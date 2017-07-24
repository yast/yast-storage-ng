#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../spec_helper"
require "y2storage/clients/inst_prepdisk"

Yast.import "Installation"

describe Y2Storage::Clients::InstPrepdisk do
  subject(:client) { described_class.new }

  describe "#run" do
    before do
      Y2Storage::StorageManager.create_test_instance
      Y2Storage::StorageManager.instance.probe
      allow(Yast::Installation).to receive(:destdir).and_return "/dest"
      allow(Yast::SCR).to receive(:Execute).and_return(true)
      allow(Yast::Mode).to receive(:update).and_return(mode == :update)
      allow_any_instance_of(Y2Storage::Devicegraph).to receive(:save)
    end

    let(:storage_manager) { Y2Storage::StorageManager.instance }

    context "in installation mode" do
      let(:mode) { :installation }

      it "uses the destination directory to mount and prepare the result" do
        expect(storage_manager).to receive(:rootprefix=).with("/dest")
        client.run
      end

      it "commits all libstorage pending changes" do
        expect(storage_manager).to receive(:commit)
        client.run
      end

      it "saves probed devicegraph to a xml log file" do
        expect(storage_manager.probed).to receive(:save).with(/.*probed.*.xml/)
        client.run
      end

      it "saves staging devicegraph to a xml log file" do
        expect(storage_manager.staging).to receive(:save).with(/.*staging.*.xml/)
        client.run
      end
    end

    context "in update mode" do
      let(:mode) { :update }

      it "does not change libstorage root prefix" do
        expect(storage_manager).not_to receive(:rootprefix=)
        client.run
      end

      it "does not commit anything" do
        expect(storage_manager).not_to receive(:commit)
        client.run
      end

      it "returns :auto" do
        expect(client.run).to eq(:auto)
      end
    end
  end
end
