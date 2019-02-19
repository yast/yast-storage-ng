# encoding: utf-8

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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/base"
require "y2storage/filesystems/type"

module Y2Storage
  module Dialogs
    class GuidedSetup
      module SelectFilesystem
        # Base class for the dialog to select filesystems.
        class Base < GuidedSetup::Base
          def initialize(*params)
            textdomain "storage"
            super
          end

          def dialog_title
            _("Filesystem Options")
          end

          def help_text
            settings.lvm ? help_text_for_volumes : help_text_for_partitions
          end

          def help_text_for_volumes
            _("Select the filesystem type for each of the volumes.")
          end

          def help_text_for_partitions
            _("Select the filesystem type for each of the partitions.")
          end
        end
      end
    end
  end
end
