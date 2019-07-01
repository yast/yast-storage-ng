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
require "y2storage/dialogs/guided_setup/select_filesystem/base"
require "y2storage/dialogs/guided_setup/select_filesystem/volume_widget"

module Y2Storage
  module Dialogs
    class GuidedSetup
      module SelectFilesystem
        # This is the more advanced version for the NG-style proposal settings
        # that support more than just a separate home volume.
        #
        # See also {SelectFilesystem::Legacy}.
        class Ng < Base
          def handle_event(event)
            volume_widgets.each { |w| w.handle(event) }
          end

          # This dialog is skipped when the settings are not editable or there is
          # nothing to edit
          #
          # @see GuidedSetup#allowed?
          #
          # @return [Boolean]
          def skip?
            !guided_setup.allowed? || settings.volumes.none?(&:configurable?)
          end

          protected

          # Set of widgets to display, one for every volume in the settings that
          # is configurable by the user
          def volume_widgets
            @volume_widgets ||=
              settings.volumes.to_enum.with_index.map do |vol, idx|
                next unless vol.configurable?

                VolumeWidget.new(settings, idx)
              end.compact
          end

          # Return a widget term for the dialog content, i.e. all the volumes
          # and possibly some more interactive widgets.
          #
          # @return [WidgetTerm]
          #
          def dialog_content
            content = volume_widgets.each_with_object(VBox()) do |widget, vbox|
              vbox << VSpacing(1.4) unless vbox.empty?
              vbox << widget.content
            end

            HVCenter(
              HSquash(
                content
              )
            )
          end

          def initialize_widgets
            volume_widgets.each(&:init)
          end

          # Update the settings: Fetch the current widget values and store them
          # in the settings.
          #
          def update_settings!
            volume_widgets.each(&:store)
          end
        end
      end
    end
  end
end
