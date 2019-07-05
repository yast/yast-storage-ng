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
        # Widget to select the actions to perform over the Linux partitions
        class LinuxPartitionActions < Base
          # Whether the widget should be enabled by default
          #
          # @return [Boolean]
          attr_reader :enable_on_init

          alias_method :enable_on_init?, :enable_on_init

          # Constructor
          #
          # @param widget_id [String]
          # @param settings [Y2Storage::ProposalSettings]
          # @param enabled [Boolean]
          def initialize(widget_id, settings, enabled: true)
            super(widget_id, settings)

            textdomain "storage"

            @enable_on_init = enabled
          end

          # @see Widgets::Base
          def content
            VBox(
              Left(Label(_("Choose what to do with existing Linux partitions"))),
              Left(
                ComboBox(
                  Id(widget_id), "",
                  [
                    Item(Id(:none), _("Do not modify")),
                    Item(Id(:ondemand), _("Remove if needed")),
                    Item(Id(:all), _("Remove even if not needed"))
                  ]
                )
              )
            )
          end

          # Selects the default option according to the settings. The widget is enabled or disabled,
          # depending on the configuration (see {#enable_on_init})
          #
          # @see Widgets::Base
          def init
            self.value = settings.linux_delete_mode

            enable_on_init? ? enable : disable
          end

          # Sets the settings according to the selected value
          #
          # @see Widgets::Base
          def store
            settings.linux_delete_mode = value
          end
        end
      end
    end
  end
end
