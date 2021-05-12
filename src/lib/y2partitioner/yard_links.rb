# Copyright (c) [2017] SUSE LLC
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

# The documentatin tool YARD has no mechanism
# for linking to separately generated YARD documentation.
# So we use this file to help YARD.
# Other code does not use (or even `require`) this.

require "yast"

module CWM
  # See http://www.rubydoc.info/github/yast/yast-yast2/CWM/WidgetTerm
  class WidgetTerm < Yast::Term
  end
end
