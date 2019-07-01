# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/device_graphs"

Yast.import "Event"
Yast.import "Stage"
Yast.import "PackageCallbacks"
Yast.import "PackageSystem"
Yast.import "Popup"

module Y2Partitioner
  # This class handles the interaction between the partitioner and
  # yast2-nfs-client, making it possible to embed the dialogs from the later into
  # the corresponding section of the former.
  class YastNfsClient
    include Yast::Logger
    include Yast::I18n

    # Name of the corresponding client in yast2-nfs-client
    YAST_CLIENT = "nfs-client4part".freeze
    private_constant :YAST_CLIENT

    # Name of the yast2-nfs-client package
    PACKAGE = "yast2-nfs-client".freeze
    private_constant :PACKAGE

    def initialize
      textdomain "storage"
    end

    # Whether the client at yast2-nfs-client has read the related system
    # configuration.
    #
    # This is a class method to ensure the configuration is only read once
    # during the whole partitioner execution.
    #
    # @return [Boolean]
    def self.client_configured?
      @client_configured
    end

    # Marks the client configuration as already read.
    #
    # @see .client_configured?
    def self.mark_client_configured
      @client_configured = true
    end

    # Resets the information checked by {.client_configured?}
    #
    # This is a public class method for testing purposes
    def self.reset
      @client_configured = false
    end

    # Initialize class attributes used by .client_configured?
    reset

    # Generates user interface from yast2-nfs-client, populated with the NFS
    # information from the current devicegraph
    #
    # If the client is not available, it tries to install it first (with
    # user confirmation).
    #
    # @return [Yast::Term, nil] a term defining the UI, nil if the client is
    #   not available and was not installed
    def init_ui
      return nil unless try_to_ensure_client

      configure_client
      set_client_list
      call_client("CreateUI")
    end

    # Handles an event coming from the UI, consolidating in the current
    # devicegraph the changes reported by yast2-nfs-client
    #
    # @param event [Hash]
    def handle_input(event)
      return unless client_exists?

      # It should be already done at this point, but just in case...
      configure_client

      widget_id = Yast::Event.IsWidgetActivated(event)
      return if widget_id.nil?

      client_result = call_client("HandleEvent", "widget_id" => widget_id)
      # FIXME: Note copied from old partitioner (y2-storage) - Take care that
      # non-fstab settings of nfs-client (firewall, sysconfig, idmapd) get
      # written on closing partitioner
      process_result(widget_id, client_result)
    end

    # Name of the package containing the YaST client
    #
    # @return [String] a frozen string
    def package_name
      PACKAGE
    end

    protected

    # Checks whether the client is available and, if not, tries to install it of
    # possible
    def try_to_ensure_client
      client_exists? || install_client
    end

    # Checks whether the client is available
    #
    # @return [Boolean]
    def client_exists?
      Yast::WFM.ClientExists(YAST_CLIENT)
    end

    # Installs the package that provides the required client, if possible
    #
    # The installation requires confirmation from the user.
    #
    # @return [Boolean] true if installation succeeded, false if it was not
    #   possible to install the package or the user rejected to do it.
    def install_client
      if in_inst_sys?
        log.info "Is not possible to install nfs-client"
        return false
      end

      pkgs = [package_name]
      log.info "Trying to install #{pkgs}"
      Yast::PackageCallbacks.RegisterEmptyProgressCallbacks
      res = Yast::PackageSystem.CheckAndInstallPackages(pkgs)
      Yast::PackageCallbacks.RestorePreviousProgressCallbacks
      log.info "Installation result: #{res}"
      res
    end

    # Configures the client if it's possible and it's not already configured
    def configure_client
      return if self.class.client_configured?
      # This is not an installed system, so no configuration to read
      return if in_inst_sys?

      log.info "Reading NFS settings"
      call_client("Read")
      self.class.mark_client_configured
    end

    # Checks whether the partitioner is being executed in the inst-sys (i.e.
    # during system installation)
    #
    # @return [Boolean]
    def in_inst_sys?
      Yast::Stage.initial
    end

    # Initialize the list of NFS mounts in the client with the information from
    # the current devicegraph
    def set_client_list
      nfs_list = current_graph.nfs_mounts.map(&:to_legacy_hash)
      call_client("FromStorage", "shares" => nfs_list)
    end

    # Executes the client and returns the result
    def call_client(function, arguments = nil)
      return nil unless function

      Yast::WFM.CallFunction(YAST_CLIENT, [function, arguments].compact)
    end

    # Consolidates in the current devicegraph the changes reported by the client
    #
    # This method mimics closely the behavior of the old (y2-storage)
    # partitioner
    def process_result(widget_id, client_result)
      log.info "Processing y2-nfs-client result for #{widget_id}: #{client_result}"

      # Do something only if y2-nfs-client returns some reasonable data
      if client_result.nil? || client_result.empty?
        log.info "Nothing to do"
        return
      end

      method = :"#{widget_id}_handler"
      if !respond_to?(method, true)
        log.info "Unhandled event #{widget_id} from y2-nfs-client"
      else
        legacy_nfs = Y2Storage::Filesystems::LegacyNfs.new_from_hash(client_result)
        legacy_nfs.default_devicegraph = current_graph
        send(method, legacy_nfs)
      end
    end

    # Handler for the 'add' button
    #
    # @see #process_result
    def newbut_handler(legacy)
      log.info "Adding NFS to current graph: #{legacy.inspect}"
      nfs = legacy.create_nfs_device
      return if nfs.reachable?

      # TRANSLATORS: pop-up message. %s is replaced for something like 'server:/path'
      msg = _("Test mount of NFS share '%s' failed.\nSave it anyway?") % legacy.share
      # Rollback only if user does not want to save (bsc#450060)
      if Yast::Popup.YesNo(msg)
        log.warn "Test mount of NFS share #{nfs.inspect} failed, but user decided to save it anyway"
        return
      end

      log.info "Test mount failed, so removing NFS from current graph: #{nfs.inspect}"
      current_graph.remove_nfs(nfs)
      set_client_list
    end

    # Handler for the 'edit' button
    #
    # @see #process_result
    def editbut_handler(legacy)
      if !legacy.share_changed?
        log.info "Updating NFS based on #{legacy.inspect}"
        legacy.update_nfs_device
        return
      end

      # The connection-related information has changed, so do the same the old
      # partitioner used to do - deleting the NFS and calling the handler for
      # adding a new one. Of course, if the new one cannot be saved (see
      # #newbut_handler) that means the original NFS share is lost.
      nfs = legacy.find_nfs_device
      log.info "Removing NFS from current graph, it will be replaced: #{nfs.inspect}"
      current_graph.remove_nfs(nfs)
      newbut_handler(legacy)
    end

    # Handler for the 'delete' button
    #
    # @see #process_result
    def delbut_handler(legacy)
      nfs = legacy.find_nfs_device
      log.info "Removing NFS from current graph: #{nfs.inspect}"
      current_graph.remove_nfs(nfs)
    end

    def current_graph
      DeviceGraphs.instance.current
    end
  end
end
