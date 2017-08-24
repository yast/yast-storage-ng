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

    INSTALLATION_HELPER_COMMAND = "/usr/lib/snapper/installation-helper"
    SNAPPER_COMMAND = "/usr/bin/snapper"

    # FIXME: Import stuff correctly
    def main
      textdomain "storage"

      Yast.import "String"
      Yast.import "Installation"
      Yast.import "Storage"
    end

    def configure_snapper?
      return false unless root_device.filesystem.btrfs?
      # userdata = part.fetch("userdata", {})
      # return false if userdata.fetch("/", "") != "snapshots"
      return root_device.use_snapshots?
    end

    class << self
      def step1
        # TRANSLATORS: first snapshot description
        snapshot_description = _("first root filesystem")
        installation_helper(1,
          "--device", String.Quote(root_device.name),
          "--description", String.Quote(snapshot_description))
      end

      def step2
        installation_helper(2,
          "--device", String.Quote(root_device.name),
          "--root-prefix", String.Quote(dest_dir),
          "--default-subvolume-name", String.Quote(default_subvolume_name))
      end

      def step3
        installation_helper(3,
          "--root-prefix", String.Quote(dest_dir),
          "--default-subvolume-name ", String.Quote(default_subvolume_name))
      end

      def step4
        return unless installation_helper(4) == 0

        bash_log_output("#{SNAPPER_COMMAND} --no-dbus set-config " \
          "NUMBER_CLEANUP=yes NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10 " \
          "TIMELINE_CREATE=no")

        SCR.Write(path(".sysconfig.yast2.USE_SNAPPER"), "yes")
        SCR.Write(path(".sysconfig.yast2"), nil)
      end

      # There is no step 5 in installation-helper, so this is missing here as well

      def step6
        log.info("configuring snapper for root fs - step 6")

        bash_log_output("#{SNAPPER_COMMAND} --no-dbus setup-quota")
      end

    private

      def root_device
        # FIXME: Use storage-ng calls
        part = Storage.GetEntryForMountpoint("/")
        part["device"]
      end

      def dest_dir
        # FIXME: Use storage-ng calls (?)
        Installation.destdir
      end

      def default_subvolume_name
        Storage.default_subvolume_name
      end

      def installation_helper(step, *args)
        log.info("configuring snapper for root fs - step #{step}")
        command = INSTALLATION_HELPER_COMMAND
        command << " --step #{step} "
        command << args.join(" ") unless args.nil?

        cmd_exit = bash_log_output(command)
        log.error("configuring snapper for root fs failed") unless cmd_exit == 0
        cmd_exit
      end

      def bash_log_output(command)
        log.info("Executing #{command}")
        cmd_result = SCR.Execute(path(".target.bash_output"), command)
        cmd_stdout = cmd_result["stdout"] || ""
        cmd_stderr = cmd_result["stderr"] || ""
        cmd_exit   = cmd_result["exit"]

        log.error("Command failed with exit value #{cmd_exit}") unless cmd_exit == 0

        cmd_stdout.each_line { |line| log.info("stdout: #{line}") }
        cmd_stderr.each_line { |line| log.info("stderr: #{line}") }

        cmd_exit
      end
    end
  end
end
