#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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

Yast.import "SlideShow"
Yast.import "Installation"
Yast.import "FileUtils"

module Y2Storage
  module Clients
    # Installation client to commit the storage changes to disk. That includes
    # partitioning, creating volumes and filesystem, writing /etc/fstab in the
    # target system and any other action handled by libstorage.
    class InstPrepdisk
      include Yast
      include Yast::Logger

      def run
        log.info("BEGIN of inst_prepdisk")
        Yast::SlideShow.MoveToStage("disk")
        commit
        log.info("END of inst_prepdisk")
        :next
      end

    protected

      # Commits the actions to disk
      def commit
        storage = Y2Storage::StorageManager.instance.storage
        storage.rootprefix = Yast::Installation.destdir
        storage.calculate_actiongraph
        storage.commit

        mount_in_target("/dev", "devtmpfs", "-t devtmpfs")
        mount_in_target("/proc", "proc", "-t proc")
        mount_in_target("/sys", "sysfs", "-t sysfs")
      end

      def mount_in_target(path, device, options)
        storage = Y2Storage::StorageManager.instance.storage
        target_path = storage.prepend_rootprefix(path)

        if !Yast::FileUtils.Exists(target_path)
          if !SCR.Execute(path(".target.mkdir"), target_path)
            raise ".target.mkdir failed"
          end
        end
        if !SCR.Execute(path(".target.mount"), [device, target_path], options)
          raise ".target.mount failed"
        end
      end
    end
  end
end
