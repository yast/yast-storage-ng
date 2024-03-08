# Copyright (c) [2020-2024] SUSE LLC
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
require "y2partitioner/widgets/columns/base"
require "y2storage/filesystem_label"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the `Label` column
      class FilesystemLabel < Base
        # Constructor
        def initialize
          super
          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, disk or partition label. Can be empty.
          _("Label")
        end

        # @see Columns::Base#value_for
        def value_for(device)
          Y2Storage::FilesystemLabel.new(device, system_graph: system_graph).to_s
        end

        # @see Columns::Base#id
        def id
          :label
        end
      end
    end
  end
end
