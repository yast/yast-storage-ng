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

require "yast"
require "rspec/expectations"

RSpec::Matchers.define :be_item do
  match do |element|
    element.is_a?(Yast::Term) && element.value == :item
  end
end

RSpec::Matchers.define :item_with_id do |expected_id|
  match do |item|
    return false unless be_item(item)

    id = item.params.detect { |i| i.is_a?(Yast::Term) && i.value == :id }

    id && id.params.first == expected_id
  end
end
