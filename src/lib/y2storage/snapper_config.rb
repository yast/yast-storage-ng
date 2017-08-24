# encoding: utf-8

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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"

module Y2Storage
  # Class to configure snapper for the root filesystem of a fresh installation.
  #
  # This is little more than a wrapper around the "installation-helper" program
  # which is part of snapper.
  class SnapperConfig
    include Yast::Logger

    # FIXME
    def main
      textdomain "storage"

      Yast.import "String"
      Yast.import "Installation"
      Yast.import "Storage"
    end

    def configure_snapper?
      part = Storage.GetEntryForMountpoint("/")
      if part.fetch("used_fs", :unknown) != :btrfs
        return false
      end
      userdata = part.fetch("userdata", {})
      return false if userdata.fetch("/", "") != "snapshots"
      true
    end

    class << self
      def step1
        log.info("configuring snapper for root fs - step 1")

        part = Storage.GetEntryForMountpoint("/")

        # TRANSLATORS: first snapshot description
        snapshot_description = _("first root filesystem")
        if bash_log_output("/usr/lib/snapper/installation-helper --step 1 " \
                           "--device '#{String.Quote(part["device"])}' " \
                           "--description '#{String.Quote(snapshot_description)}'") != 0
          log.error("configuring snapper for root fs failed")
        end
      end

      def step2
        log.info("configuring snapper for root fs - step 2")

        part = Storage.GetEntryForMountpoint("/")

        if bash_log_output("/usr/lib/snapper/installation-helper --step 2 " \
                           "--device '#{String.Quote(part["device"])}' " \
                           "--root-prefix '#{String.Quote(Installation.destdir)}' " \
                           "--default-subvolume-name '" \
                           "#{String.Quote(Storage.default_subvolume_name)}'") != 0
          log.error("configuring snapper for root fs failed")
        end
      end

      def step3
        log.info("configuring snapper for root fs - step 3")

        if bash_log_output("/usr/lib/snapper/installation-helper --step 3 " \
                           "--root-prefix '#{String.Quote(Installation.destdir)}' " \
                           "--default-subvolume-name " \
                           "'#{String.Quote(Storage.default_subvolume_name)}'") != 0
          log.error("configuring snapper for root fs failed")
        end
      end

      def step4
        log.info("configuring snapper for root fs - step 4")

        if bash_log_output("/usr/lib/snapper/installation-helper --step 4") != 0
          log.error("configuring snapper for root fs failed")
        end

        bash_log_output("/usr/bin/snapper --no-dbus set-config " \
                        "NUMBER_CLEANUP=yes NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10 " \
                        "TIMELINE_CREATE=no")

        SCR.Write(path(".sysconfig.yast2.USE_SNAPPER"), "yes")
        SCR.Write(path(".sysconfig.yast2"), nil)
      end

      # There is no step 5 in installation-helper, so this is missing here as well

      def step6
        log.info("configuring snapper for root fs - step 6")

        bash_log_output("/usr/bin/snapper --no-dbus setup-quota")
      end

    private

      def bash_log_output(command)
        log.info("Executing #{command}")
        cmd_result = SCR.Execute(path(".target.bash_output"), command)
        cmd_stdout = cmd_result["stdout"] || ""
        cmd_stderr = cmd_result["stderr"] || ""
        cmd_exit   = cmd_result["exit"]

        log.info("exit: #{cmd_exit}")
        cmd_stdout.each_line { |line| log.info("stdout: #{line}") }
        cmd_stderr.each_line { |line| log.info("stderr: #{line}") }

        cmd_exit
      end
    end
  end
end
