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

require "y2partitioner/widgets/help"

RSpec.shared_examples "help fields" do
  it "returns a list of symbols" do
    expect(subject.help_fields).to all(be_a(Symbol))
  end

  # NOTE: add to `excluded_help_fields` all fields without associated help
  it "exists help for all help fields" do
    help_fields = subject.help_fields - excluded_help_fields

    help_fields.each do |help_field|
      expect(Y2Partitioner::Widgets::Help::TEXTS[help_field]).to_not be_nil
    end
  end
end
