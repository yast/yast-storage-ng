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
# with this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/base"
require "y2storage/dialogs/guided_setup/widgets/disk_selector"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog for volumes disks selection for the proposal.
      class SelectVolumesDisks < Base
        def initialize(*params)
          textdomain "storage"
          super
        end

        # This dialog has to be skipped when there is only
        # one candidate disk for installing.
        def skip?
          analyzer.candidate_disks.size == 1
        end

        # Before skipping, settings should be assigned.
        def before_skip
          settings.candidate_devices = analyzer.candidate_disks.map(&:name)
        end

        protected

        def dialog_title
          _("Select Hard Disk(s)")
        end

        def dialog_content
          # TODO: this trick is being used in several dialogs. Find a way to share it.
          content = disk_selector_widgets.flat_map { |w| [w.content, VSpacing(1.4)] }.tap(&:pop)

          HVCenter(
            HSquash(
              VBox(
                *content
              )
            )
          )
        end

        # Update the settings: Fetch the current widget values and store them in the settings.
        def update_settings!
          disk_selector_widgets.each(&:store)
        end

        def help_text
          # TRANSLATORS: Help text for guided storage setup
          _("Select the desired disk to allocate each volume, volume group, and/or partition.")
        end

        private

        # Disk selectors to display, one for every volume specification set in the settings that is
        # configurable by the user
        def disk_selector_widgets
          @disk_selector_widgets ||=
            settings.volumes_sets.to_enum.with_index.map do |vs, idx|
              next unless vs.proposed?

              Widgets::DiskSelector.new(
                idx,
                settings,
                candidate_disks: analyzer.candidate_disks,
                disk_helper:     disk_helper
              )
            end.compact
        end
      end
    end
  end
end
