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
    let(:storage) { double("Storage::Storage").as_null_object }

    before do
      Y2Storage::StorageManager.create_test_instance
      allow(Y2Storage::StorageManager.instance).to receive(:storage).and_return storage
      allow(Yast::Installation).to receive(:destdir).and_return "/dest"
      allow(storage).to receive(:prepend_rootprefix).with("/dev").and_return "/dest/dev"
      allow(storage).to receive(:prepend_rootprefix).with("/proc").and_return "/dest/proc"
      allow(storage).to receive(:prepend_rootprefix).with("/sys").and_return "/dest/sys"
      allow(Yast::SCR).to receive(:Execute).and_return(true)
    end

    it "uses the destination directory to mount and prepare the result" do
      expect(storage).to receive(:rootprefix=).with("/dest")
      client.run
    end

    it "commits all libstorage pending changes" do
      expect(storage).to receive(:calculate_actiongraph)
      expect(storage).to receive(:commit)
      client.run
    end
  end
end
