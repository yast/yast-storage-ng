# Copyright (c) [2017-2019] SUSE LLC
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
require "y2storage/dialogs/guided_setup/widgets/root_disk_selector"
require "y2storage/dialogs/guided_setup/widgets/partition_actions"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog for root disk selection and the actions to perform over Windows, Linux and other kind of
      # partitions.
      class SelectRootDisk < Base
        extend Yast::I18n

        # Constructor
        #
        # @see GuidedSetup::Base
        def initialize(*params)
          textdomain "storage"
          super
        end

        # This dialog should be skipped when there is only one candidate disk for the installation and
        # the actions over the partitions (delete and resize) cannot be configured.
        #
        # @return [Boolean]
        def skip?
          candidate_disks_helper.single_candidate_disk? && !partitions_configurable?
        end

        # Before skipping, settings should be assigned.
        #
        # @see GuidedSetup::Base
        def before_skip
          settings.root_device = candidate_disks_helper.candidate_disks_names.first
        end

        protected

        # @see GuidedSetup::Base
        def dialog_title
          _("Select Hard Disk(s)")
        end

        # @see GuidedSetup::Base
        def dialog_content
          content = widgets.flat_map { |w| [w.content, VSpacing(1)] }.tap(&:pop)

          HSquash(
            VBox(
              *content
            )
          )
        end

        # Widgets of the dialog
        #
        # @return [Array<Widgets::Base>]
        def widgets
          widgets = [root_selection_widget]
          widgets << partition_actions_widget if partition_actions?

          widgets
        end

        # Widget to select the root device
        #
        # @return [Widgets::RootDiskSelector]
        def root_selection_widget
          @root_selection_widget ||= Widgets::RootDiskSelector.new("root_selector", settings,
            candidate_disks: candidate_disks_helper.candidate_disks,
            disk_helper:)
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
          widgets.each(&:init)
        end

        # @see GuidedSetup::Base
        def update_settings!
          widgets.each(&:store)
        end

        # @see GuidedSetup::Base
        def help_text
          widgets.map(&:help).join
        end

        private

        # Whether the partition actions can be configured by the user
        #
        # The partitions are configurable if there are partitions and the option to configure the
        # partitions is not disabled in the control file.
        #
        # @return [Boolean]
        def partitions_configurable?
          candidate_disks_helper.partitions.any? && partition_actions?
        end

        # Whether the actions (delete or resize) over the partitions are configurable
        #
        # @return [Boolean]
        def partition_actions?
          settings.delete_resize_configurable
        end

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
