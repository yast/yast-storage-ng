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
require "y2partitioner/widgets/mkfs_optionvalidator"

describe Y2Partitioner::Widgets do
  let(:all_validators) { Y2Partitioner::Widgets::MkfsOptionvalidator.all }

  describe Y2Partitioner::Widgets::MkfsOptionvalidator do
    subject { all_validators }

    it "'fs' is a list of allowed filesystem symbols" do
      subject.each do |x|
        expect(x.fs).to be_a(Array)
        expect(x.fs.find { |fs| ![:ext2, :ext3, :ext4, :btrfs, :xfs, :vfat].include? fs }).to be nil
      end
    end

    it "'validate' references a proc" do
      subject.each do |x|
        expect(x.validate).to be_a(Proc).or be_a(NilClass)
      end
    end

    it "if it can validate there must be an error message" do
      subject.each do |x|
        expect(x.validate ? !x.error.empty? : true).to be true
      end
    end
  end
end
