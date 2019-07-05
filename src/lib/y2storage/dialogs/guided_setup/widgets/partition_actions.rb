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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/widgets/base"
require "y2storage/dialogs/guided_setup/widgets/windows_partition_actions"
require "y2storage/dialogs/guided_setup/widgets/linux_partition_actions"
require "y2storage/dialogs/guided_setup/widgets/other_partition_actions"

module Y2Storage
  module Dialogs
    class GuidedSetup
      module Widgets
        # Widget to select the actions to perform over the partitions (delete and resize)
        class PartitionActions < Base
          extend Yast::I18n

          # Constructor
          #
          # @param widget_id [String]
          # @param settings [Y2Storage::ProposalSettings]
          # @param windows [Boolean] whether a widget for actions over Windows partitions should be shown
          # @param linux [Boolean] whether the widget for actions over Linux partitions should be enabled
          # @param other [Boolean] whether the widget for actions over other partitions should be enabled
          def initialize(widget_id, settings, windows: true, linux: true, other: true)
            super(widget_id, settings)

            textdomain "storage"

            self.windows_actions = windows
            self.linux_actions = linux
            self.other_actions = other
          end

          # @see Widgets::Base
          def content
            VBox(*add_spacing(widgets.map(&:content)))
          end

          # Initializes each widget
          #
          # @see Widgets::Base
          def init
            widgets.each(&:init)
          end

          # Stores each widget
          #
          # @see Widgets::Base
          def store
            widgets.each(&:store)
          end

          # @see Widgets::Base
          def help
            help = _(REMOVE_ACTIONS_HELP)

            help += _(WINDOWS_ACTIONS_HELP) if windows_actions?

            help
          end

          private

          # @return [Boolean]
          attr_accessor :windows_actions

          # @return [Boolean]
          attr_accessor :linux_actions

          # @return [Boolean]
          attr_accessor :other_actions

          alias_method :windows_actions?, :windows_actions

          alias_method :linux_actions?, :linux_actions

          alias_method :other_actions?, :other_actions

          REMOVE_ACTIONS_HELP = N_(
            "<p>" \
              "You can choose what to do with existing partitions:" \
            "</p>" \
            "<p>" \
              "<ul>" \
                "<li>Do not modify (keep them as they are)</li>" \
                "<li>Remove if needed</li>" \
                "<li>Remove even if not needed (always remove)</li>" \
              "</ul>" \
            "</p>"
          )

          WINDOWS_ACTIONS_HELP = N_(
            "<p>" \
              "And for Windows partitions, the following options are also available:" \
              "<ul>" \
                "<li>Resize if needed (Windows partitions only)</li>" \
                "<li>Resize or remove if needed (Windows partitions only)</li>" \
              "</ul>" \
            "<p>" \
            "<p>" \
              "That last option means to try to resize the Windows partition(s) to " \
              "make enough disk space available for Linux, but if that is not " \
              "enough, completely delete the Windows partition." \
            "</p>"
          )

          private_constant :REMOVE_ACTIONS_HELP, :WINDOWS_ACTIONS_HELP

          # Widgets to show
          #
          # @return [Array<Widgets::Base>]
          def widgets
            return @widgets if @widgets

            @widgets = []

            @widgets << windows_actions_widget if windows_actions?
            @widgets << linux_actions_widget
            @widgets << other_actions_widget

            @widgets
          end

          # Widget to select the actions over Windows partitions
          #
          # @return [Widgets::WindowsPartitionActions]
          def windows_actions_widget
            @windows_actions_widget ||= WindowsPartitionActions.new("#{widget_id}_windows", settings)
          end

          # Widget to select the actions over Linux partitions
          #
          # @return [Widgets::LinuxPartitionActions]
          def linux_actions_widget
            @linux_actions_widget ||=
              LinuxPartitionActions.new("#{widget_id}_linux", settings, enabled: linux_actions?)
          end

          # Widget to select the actions over other kind of partitions
          #
          # @return [Widgets::OtherPartitionActions]
          def other_actions_widget
            @other_actions_widget ||=
              OtherPartitionActions.new("#{widget_id}_other", settings, enabled: other_actions?)
          end

          # Adds vertical spacing between the widgets
          #
          # @param widgets [Array<Yast::Term>]
          # @return [Array<Yast::Term>]
          def add_spacing(widgets)
            widgets.flat_map { |w| [w, VSpacing(1)] }.tap(&:pop)
          end
        end
      end
    end
  end
end
