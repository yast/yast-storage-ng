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

require_relative "../../test_helper"

RSpec.shared_examples "Y2Partitioner::Widgets::Column" do
  describe "#title" do
    it "returns either, an string or a Yast::Term" do
      expect(subject.title).to be_an(String).or be_a(Yast::Term)
    end
  end

  describe "#id" do
    it "returns a symbol" do
      expect(subject.id).to be_a(Symbol)
    end
  end
end
