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

require_relative "../test_helper"
require "cwm/rspec"
require "y2partitioner/widgets/apqn_selector"

describe Y2Partitioner::Widgets::ApqnSelector do
  subject { described_class.new(controller) }

  let(:controller) do
    instance_double(Y2Partitioner::Actions::Controllers::Encryption, online_apqns: apqns)
  end

  let(:apqns) { [apqn1, apqn2] }

  let(:apqn1) { instance_double(Y2Storage::EncryptionProcesses::Apqn, name: "01.0001") }

  let(:apqn2) { instance_double(Y2Storage::EncryptionProcesses::Apqn, name: "01.0002") }

  include_examples "CWM::MultiSelectionBox"

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return(apqns)
    end

    it "saves selected APQNs in the controller" do
      expect(controller).to receive(:apqns=).with(apqns)

      subject.store
    end
  end
end
