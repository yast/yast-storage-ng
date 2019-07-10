#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
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
require "y2storage/arch"

describe Y2Storage::Arch do
  subject { described_class.new(storage_arch) }

  let(:storage_arch) { instance_double(Storage::Arch) }

  describe "support_resume?" do
    before do
      allow(storage_arch).to receive(:s390?).and_return(s390)
    end

    context "when the architecture is s390" do
      let(:s390) { true }

      it "returns false" do
        expect(subject.support_resume?).to eq(false)
      end
    end

    context "when the architecture is not s390" do
      let(:s390) { false }

      it "returns true" do
        expect(subject.support_resume?).to eq(true)
      end
    end
  end
end
