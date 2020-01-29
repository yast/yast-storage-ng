# Copyright (c) [2018-2020] SUSE LLC
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

require "y2partitioner/icons"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/help"
require "y2partitioner/yast_nfs_client"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for NFS handling. It relies in the dialog content provided
      # by yast2-nfs-client
      #
      # @see YastNfsClient
      class NfsMounts < Base
        include Yast::I18n

        include Help

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("NFS")
        end

        # @macro seeCustomWidget
        def contents
          # The CWM machinery calls #contents several times on each page switch,
          # so some caching is required
          return @contents if @contents

          @contents = VBox(
            Left(
              HBox(
                Image(Icons::NFS, ""),
                # TRANSLATORS: Heading for the expert partitioner page
                Heading(_("Network File System (NFS)"))
              )
            ),
            nfs_client.init_ui || fallback_ui
          )
        end

        def help
          columns = [:nfs_server, :nfs_directory, :nfs_mount_point, :nfs_type, :nfs_options]

          help_text = columns.map { |c| helptext_for(c) }

          help_text.join
        end

        # @macro seeAbstractWidget
        def store
          # Invalidate the cache when abandoning the page, so the content gets
          # refreshed (but only calculated once) everytime the NFS page is visited
          @contents = nil

          # Invalidate also the cached content of other pages listing NFS
          # devices, even if that breaks encapsulation a bit
          pager.invalidated_pages << :system unless pager.invalidated_pages.include?(:system)
        end

        # @macro seeAbstractWidget
        def handle(event)
          nfs_client.handle_input(event)
          nil
        end

        private

        # @return [CWM::TreePager]
        attr_reader :pager

        # User interface to display if the NFS client is not available
        #
        # @return [Yast::Term]
        def fallback_ui
          pkg = nfs_client.package_name

          VBox(
            VSpacing(0.6),
            Left(
              Label(
                # TRANSLATORS: %s is the name of a package (i.g. 'yast2-nfs-client')
                _("NFS configuration is not available. Check %s package installation.") % pkg
              )
            ),
            VStretch()
          )
        end

        # @return [NfsClient]
        def nfs_client
          @nfs_client ||= YastNfsClient.new
        end
      end
    end
  end
end
