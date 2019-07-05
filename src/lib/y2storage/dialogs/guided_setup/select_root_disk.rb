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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/base"
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
          single_candidate_disk? && !partitions_configurable?
        end

        # Before skipping, settings should be assigned.
        #
        # @see GuidedSetup::Base
        def before_skip
          settings.root_device = candidate_disks.first.name
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
            candidate_disks: candidate_disks,
            disk_helper:     disk_helper)
        end

        # Widget to select the actions (delete or resize) over the partitions
        #
        # @return [Widgets::PartitionActions]
        def partition_actions_widget
          @partition_actions_widget ||= Widgets::PartitionActions.new("partition_actions", settings,
            windows: windows_actions?,
            linux:   linux_actions?,
            other:   other_actions?)
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

        # Candidate disks to perform the installation
        #
        # @return
        def candidate_disks
          return @candidate_disks if @candidate_disks

          candidates = settings.candidate_devices || []
          @candidate_disks = candidates.map { |d| analyzer.device_by_name(d) }
        end

        # Whether the actions (delete or resize) over the partitions are configurable
        #
        # @return [Boolean]
        def partition_actions?
          settings.delete_resize_configurable
        end

        # Whether the actions (delete or resize) over Windows partitions are configurable
        #
        # @return [Boolean]
        def windows_actions?
          !windows_partitions.empty?
        end

        # Whether the actions (delete) over Linux partitions are configurable
        #
        # @return [Boolean]
        def linux_actions?
          !linux_partitions.empty?
        end

        # Whether the actions (delete) over other kind of partitions are configurable
        #
        # @return [Boolean]
        def other_actions?
          all_partitions.size > linux_partitions.size + windows_partitions.size
        end

        # Windows partitions from the candidate disks
        #
        # @return [Array<Y2Storage::Partition>]
        def windows_partitions
          analyzer.windows_partitions(*candidate_disks)
        end

        # Linux partitions from the candidate disks
        #
        # @return [Array<Y2Storage::Partition>]
        def linux_partitions
          analyzer.linux_partitions(*candidate_disks)
        end

        # All partitions from the candidate disks
        #
        # @return [Array<Y2Storage::Partition>]
        def all_partitions
          @all_partitions ||= candidate_disks.map(&:partitions).flatten
        end

        # Whether there is only one candidate disk
        #
        # @return [Boolean]
        def single_candidate_disk?
          candidate_disks.size == 1
        end

        # Whether the partition actions can be configured by the user
        #
        # The partitions are configurable if there are partitions and the option to configure the
        # partitions is not disabled in the control file.
        #
        # @return [Boolean]
        def partitions_configurable?
          all_partitions.any? && partition_actions?
        end
      end
    end
  end
end
