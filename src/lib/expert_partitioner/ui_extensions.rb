# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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

Yast.import "UI"
Yast.import "Directory"

include Yast::UIShortcuts

module Yast
  module UIShortcuts
    def LeftRadioButton(*opts)
      Left(RadioButton(*opts))
    end

    def LeftRadioButtonWithAttachment(*opts)
      tmp1 = opts[0..-2]
      tmp2 = opts[-1]
      VBox(
        Left(RadioButton(*tmp1)),
        HBox(HSpacing(4), tmp2)
      )
    end

    def IconAndHeading(heading, icon)
      HBox(Image("#{Yast::Directory.icondir}/22x22/apps/#{icon}", ""), Heading(heading))
    end
  end
end
