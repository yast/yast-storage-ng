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
        # Widget to select the root disk for the installation
        class RootDiskSelector < Base
          # Constructor
          #
          # @param widget_id [String]
          # @param settings [Y2Storage::ProposalSettings]
          # @param candidate_disks [Array<Y2Storage::Device>]
          # @param disk_helper [Helpers::Disk]
          def initialize(widget_id, settings, candidate_disks: [], disk_helper: nil)
            super(widget_id, settings)

            textdomain "storage"

            @candidate_disks = candidate_disks
            @disk_helper = disk_helper
          end

          # @see Widgets::Base
          def content
            VBox(
              Left(Label(_("Please select a disk to use as the \"root\" partition (/)"))),
              VSpacing(0.3),
              if single_candidate_disk?
                Left(Label(disk_label(candidate_disks.first)))
              else
                RadioButtonGroup(
                  Id(widget_id),
                  VBox(
                    *([any_disk_option] + candidate_disks.map { |d| disk_option(d) })
                  )
                )
              end
            )
          end

          # Selects the initial root disk
          #
          # @see Widgets::Base
          def init
            disk_name = settings.root_device || :any_disk

            self.value = disk_name
          end

          # Sets the settings with the selected root disk
          #
          # @see Widgets::Base
          def store
            settings.root_device = value
          end

          # Selected root disk
          #
          # @see Widgets::Base
          #
          # @return [String, nil] nil if no disk is selected (:any_disk option)
          def value
            return candidate_disks.first.name if single_candidate_disk?

            candidate_disks.map(&:name).detect { |d| selected_option?(d) }
          end

          # Selects a root disk
          #
          # @see Widgets::Base
          #
          # @param value [String] disk name
          def value=(value)
            return if single_candidate_disk?

            select_option(value)
          end

          # @see Widgets::Base
          def help
            _(
              "<p>" \
              "Select the disk where to create the root filesystem. " \
              "</p>" \
              "<p>" \
              "This is also the disk where boot-related partitions " \
              "will typically be created as necessary: /boot, ESP (EFI System " \
              "Partition), BIOS-Grub. " \
              "That means that this disk should be usable by the machine's " \
              "BIOS / firmware." \
              "</p>"
            )
          end

          private

          # @return [Array<Y2Storage::Device>]
          attr_reader :candidate_disks

          # @return [Helpers::Disk]
          attr_reader :disk_helper

          # Radio button to select "any disk" option
          #
          # @return [Yast::Term]
          def any_disk_option
            Left(RadioButton(Id(:any_disk), _("Any disk")))
          end

          # Radio button to select a disk
          #
          # @param disk [Y2Storage::Device]
          # @return [Yast::Term]
          def disk_option(disk)
            Left(RadioButton(Id(disk.name), disk_label(disk)))
          end

          # Label for a disk
          #
          # @see Helpers::Disk#label
          #
          # @param disk [Y2Storage::Device]
          # @return [String]
          def disk_label(disk)
            return disk.name unless disk_helper

            disk_helper.label(disk)
          end

          # Whether there is only one candidate disk
          #
          # @return [Boolean]
          def single_candidate_disk?
            candidate_disks.size == 1
          end

          # Whether a radio button is selected
          #
          # @param id [String]
          # @return [Boolean]
          def selected_option?(id)
            Yast::UI.QueryWidget(Id(id), :Value)
          end

          # Selects a radio button
          #
          # @param id [String]
          def select_option(id)
            Yast::UI.ChangeWidget(Id(id), :Value, true)
          end
        end
      end
    end
  end
end
