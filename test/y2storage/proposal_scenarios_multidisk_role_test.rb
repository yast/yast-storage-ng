#!/usr/bin/env rspec
# Copyright (c) [2020] SUSE LLC
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
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe ".initial" do
    include_context "proposal"

    subject(:proposal) { described_class.initial(settings:) }

    let(:architecture) { :x86 }

    # Although this test obviously ensures the right behavior, it was actually added to
    # detect performance problems. The operation implemented here used to be dreadfully
    # slow, so this test took many minutes to execute.
    context "with separate VGs, multidisk_first and many small disks" do
      let(:control_file) { "suma_multidisk.xml" }
      let(:scenario) { "many_disks" }
      let(:lvm) { true }

      it "makes a valid proposal by disabling all the separate VGs" do
        expect(proposal.devices.lvm_lvs.map(&:lv_name)).to contain_exactly("root", "swap")
      end
    end
  end
end
