# Copyright (c) [2022] SUSE LLC
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

require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Dialog to create and edit an NFS mount
    class Nfs < SingleStep
      attr_reader :title

      # @param form [CWM::CustomWidget]
      def initialize(form, title)
        super()
        textdomain "storage"
        @form = form
        @title = title
      end

      # @macro seeDialog
      def contents
        HVSquash(
          VBox(@form, form_validator)
        )
      end

      private

      def form_validator
        FormValidator.new(@form)
      end

      class FormValidator < CWM::CustomWidget
        Yast.import "Popup"

        def initialize(form)
          textdomain "storage"

          @form = form
          @initial_share = nfs.share
        end

        def contents
          Empty()
        end

        def validate
          @form.store
          return true unless validate_reachable?
          return true if nfs.reachable?

          # TRANSLATORS: pop-up message. %s is replaced for something like 'server:/path'
          msg = _("Test mount of NFS share '%s' failed.\nSave it anyway?") % nfs.share
          keep = Yast::Popup.YesNo(msg)
          # Save only if user confirms (bsc#450060)
          log.warn "Test mount of NFS share #{nfs.inspect} failed. Save anyway?: #{keep}"
          keep
        end

      private

        def nfs
          @form.nfs
        end

        NEW_DEVICE_SHARE = ":".freeze
        private_constant :NEW_DEVICE_SHARE

        def validate_reachable?
          # Always validate new NFS entries
          return true if @initial_share == NEW_DEVICE_SHARE

          # For pre-existing entries, check only if the connection information changed
          nfs.share_changed?
        end
      end
    end
  end
end
