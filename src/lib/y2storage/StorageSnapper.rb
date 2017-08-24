# encoding: utf-8

# Copyright (c) [2012-2015] Novell, Inc.
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


module Yast

  class StorageSnapperClass < Module


    include Yast::Logger


    def main

      textdomain "storage"

      Yast.import "String"
      Yast.import "Installation"
      Yast.import "Storage"

    end


    def bash_log_output(command)
      tmp = SCR.Execute(path(".target.bash_output"), command)

      log.info("exit: #{tmp.fetch("exit")}")
      tmp.fetch("stdout").each_line { |line| log.info("stdout #{line}") }
      tmp.fetch("stderr").each_line { |line| log.info("stderr #{line}") }

      return tmp.fetch("exit")
    end


    def configure_snapper?

      part = Storage.GetEntryForMountpoint("/")

      if part.fetch("used_fs", :unknown) != :btrfs
        return false
      end

      userdata = part.fetch("userdata", {})
      if userdata.fetch("/", "") != "snapshots"
        return false
      end

      return true

    end


    def configure_snapper_step1()

      log.info("configuring snapper for root fs - step 1")

      part = Storage.GetEntryForMountpoint("/")

      # TRANSLATORS: first snapshot description
      snapshot_description = _("first root filesystem")
      if bash_log_output("/usr/lib/snapper/installation-helper --step 1 " <<
                         "--device '#{String.Quote(part["device"])}' " <<
                         "--description '#{String.Quote(snapshot_description)}'") != 0
        log.error("configuring snapper for root fs failed")
      end

    end


    def configure_snapper_step2()

      log.info("configuring snapper for root fs - step 2")

      part = Storage.GetEntryForMountpoint("/")

      if bash_log_output("/usr/lib/snapper/installation-helper --step 2 " <<
                         "--device '#{String.Quote(part["device"])}' " <<
                         "--root-prefix '#{String.Quote(Installation.destdir)}' " <<
                         "--default-subvolume-name '#{String.Quote(Storage.default_subvolume_name())}'") != 0
        log.error("configuring snapper for root fs failed")
      end

    end


    def configure_snapper_step3()

      log.info("configuring snapper for root fs - step 3")

      if bash_log_output("/usr/lib/snapper/installation-helper --step 3 " <<
                         "--root-prefix '#{String.Quote(Installation.destdir)}' " <<
                         "--default-subvolume-name '#{String.Quote(Storage.default_subvolume_name())}'") != 0
        log.error("configuring snapper for root fs failed")
      end

    end


    def configure_snapper_step4()

      log.info("configuring snapper for root fs - step 4")

      if bash_log_output("/usr/lib/snapper/installation-helper --step 4") != 0
        log.error("configuring snapper for root fs failed")
      end

      bash_log_output("/usr/bin/snapper --no-dbus set-config " <<
                      "NUMBER_CLEANUP=yes NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10 " <<
                      "TIMELINE_CREATE=no")

      SCR.Write(path(".sysconfig.yast2.USE_SNAPPER"), "yes")
      SCR.Write(path(".sysconfig.yast2"), nil)

    end


    def configure_snapper_step6()

      log.info("configuring snapper for root fs - step 6")

      bash_log_output("/usr/bin/snapper --no-dbus setup-quota")

    end

  end

  StorageSnapper = StorageSnapperClass.new
  StorageSnapper.main

end
