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
require "y2storage/dialogs/guided_setup/base"
require "y2storage/dialogs/guided_setup/helpers/candidate_disks"
require "y2storage/dialogs/guided_setup/widgets/partition_actions"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog thath allows to choose the actions to perform over Windows, Linux and other kind of
      # partitions.
      class SelectPartitionActions < Base
        extend Yast::I18n

        # Constructor
        #
        # @see GuidedSetup::Base
        def initialize(*params)
          textdomain "storage"
          super
        end

        # This dialog should be skipped when the actions over the partitions (delete and resize)
        # cannot be configured.
        #
        # @return [Boolean]
        def skip?
          candidate_disks_helper.partitions.none? || !settings.delete_resize_configurable
        end

        protected

        # @see GuidedSetup::Base
        def dialog_title
          _("Select Partition(s) Actions")
        end

        # @see GuidedSetup::Base
        def dialog_content
          HSquash(
            VBox(
              partition_actions_widget.content
            )
          )
        end

        # Widget to select the actions (delete or resize) over the partitions
        #
        # @return [Widgets::PartitionActions]
        def partition_actions_widget
          @partition_actions_widget ||= Widgets::PartitionActions.new("partition_actions", settings,
            windows: candidate_disks_helper.windows_partitions?,
            linux:   candidate_disks_helper.linux_partitions?,
            other:   candidate_disks_helper.other_partitions?)
        end

        # @see GuidedSetup::Base
        def initialize_widgets
          partition_actions_widget.init
        end

        # @see GuidedSetup::Base
        def update_settings!
          partition_actions_widget.store
        end

        # @see GuidedSetup::Base
        def help_text
          partition_actions_widget.help
        end

        private

        # Helper to work with candidate disks
        #
        # @return [Helpers::CandidateDisks]
        def candidate_disks_helper
          @candidate_disks_helper ||= Helpers::CandidateDisks.new(settings, analyzer)
        end
      end
    end
  end
end
