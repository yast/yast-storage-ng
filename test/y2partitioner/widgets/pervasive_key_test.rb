#!/usr/bin/env rspec

# Copyright (c) [2025] SUSE LLC
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
require "y2partitioner/widgets/pervasive_key"

describe Y2Partitioner::Widgets::PervasiveKey do
  subject { described_class.new(initial_key) }
  let(:initial_key) { "0x123456" }

  include_examples "CWM::AbstractWidget"

  context "when the key is longer than 20 characters" do
    let(:initial_key) { "0x123456789012345678901234567890" }

    include_examples "CWM::AbstractWidget"
  end
end

describe Y2Partitioner::Widgets::PervasiveKey::Label do
  subject { described_class.new("id", key) }

  let(:key) { "0x123456789012345678901234567890" }

  include_examples "CWM::CustomWidget"
end
