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
require_relative "matchers"

shared_examples "Y2Partitioner::Widgets::Menus" do
  describe "#label" do
    it "produces a String" do
      expect(subject.label).to be_a String
    end
  end

  describe "#items" do
    it "produces an array of Items" do
      expect(subject.items).to be_an Array

      expect(subject.items).to all(be_item)
    end
  end

  describe "#disabled_items" do
    it "produces an array of Items" do
      expect(subject.items).to be_an Array

      expect(subject.items).to all(be_item)
    end
  end

  describe "#handle" do
    it "produces a Symbol or nil" do
      expect(subject.handle(:dummy_event)).to be_a(Symbol).or be_nil
    end
  end
end
