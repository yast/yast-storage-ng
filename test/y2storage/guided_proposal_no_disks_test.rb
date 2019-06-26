#!/usr/bin/env rspec
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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::GuidedProposal do
  # Regression test (bsc#1057430)
  describe ".initial" do
    before do
      Y2Storage::StorageManager.create_test_instance
    end

    let(:devicegraph) { Y2Storage::StorageManager.instance.probe_from_yaml(nil) }

    context "with no disks at all" do
      it "raises no Error" do
        expect { described_class.initial } .to_not raise_error
      end
    end
  end
end
