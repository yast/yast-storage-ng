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

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/widgets/base"

module Y2Storage
  module Dialogs
    class GuidedSetup
      module Widgets
        # Widget to select the actions to perform over the Windows partitions (delete and resize)
        class WindowsPartitionActions < Base
          # Constructor
          #
          # @param widget_id [String]
          # @param settings [Y2Storage::ProposalSettings]
          def initialize(widget_id, settings)
            super

            textdomain "storage"
          end

          # @see Widgets::Base
          def content
            VBox(
              Left(Label(_("Choose what to do with existing Windows systems"))),
              Left(
                ComboBox(
                  Id(widget_id), "",
                  [
                    Item(Id(:not_modify), _("Do not modify")),
                    Item(Id(:resize), _("Resize if needed")),
                    Item(Id(:remove), _("Resize or remove as needed")),
                    Item(Id(:always_remove), _("Remove even if not needed"))
                  ]
                )
              )
            )
          end

          # Selects an option according to the settings (see {#windows_action})
          #
          # @see Widgets::Base
          def init
            self.value = windows_action
          end

          # Updates the settings according to the selected option
          #
          # @see Widgets::Base
          def store
            case value
            when :not_modify
              settings.resize_windows = false
              settings.windows_delete_mode = :none
            when :resize
              settings.resize_windows = true
              settings.windows_delete_mode = :none
            when :remove
              settings.resize_windows = true
              settings.windows_delete_mode = :ondemand
            when :always_remove
              settings.resize_windows = false
              settings.windows_delete_mode = :all
            end
          end

          private

          # Option to selected according to the settings
          #
          # @return [Symbol]
          def windows_action
            if settings.windows_delete_mode == :all
              :always_remove
            elsif settings.windows_delete_mode == :ondemand
              :remove
            elsif settings.resize_windows
              :resize
            else
              :not_modify
            end
          end
        end
      end
    end
  end
end
