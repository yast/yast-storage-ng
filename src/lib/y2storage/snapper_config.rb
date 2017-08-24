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
require "shellwords"

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

      Yast.import "Installation"
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
          "--device", root_device.name,
          "--description", snapshot_description)
      end

      def step2
        installation_helper(2,
          "--device", root_device.name,
          "--root-prefix", dest_dir,
          "--default-subvolume-name", default_subvolume_name)
      end

      def step3
        installation_helper(3,
          "--root-prefix", dest_dir,
          "--default-subvolume-name", default_subvolume_name)
      end

      def step4
        return unless installation_helper(4) == 0

        bash_log_output(SNAPPER_COMMAND,
          "--no-dbus set-config",
          "NUMBER_CLEANUP=yes",
          "NUMBER_LIMIT=2-10",
          "NUMBER_LIMIT_IMPORTANT=4-10",
          "TIMELINE_CREATE=no")

        SCR.Write(path(".sysconfig.yast2.USE_SNAPPER"), "yes")
        SCR.Write(path(".sysconfig.yast2"), nil)
      end

      # There is no step 5 in installation-helper, so this is missing here as well

      def step6
        log.info("configuring snapper for root fs - step 6")

        bash_log_output(SNAPPER_COMMAND, "--no-dbus setup-quota")
      end

    private

      # Return the device of the root filesystem from the staging devicegraph.
      def root_device
        # FIXME: Use storage-ng calls
        part = Storage.GetEntryForMountpoint("/")
        part["device"]
      end

      # Return the destination directory, i.e. the path of the mount point of
      # the installation target system (the system that is currently being
      # installed).
      #
      # @return [String]
      def dest_dir
        # FIXME: Use storage-ng calls (?)
        Installation.destdir
      end

      # Return the name of the default subvolume.
      #
      # @return [String]
      def default_subvolume_name
        Storage.default_subvolume_name
      end

      # Call the installation_helper command with one of its steps and optional
      # additional arguments.
      #
      # @param step [Integer] step number
      # @param args [Array<String>] additional arguments
      # @return [Integer] command exit status
      #
      def installation_helper(step, *args)
        log.info("configuring snapper for root fs - step #{step}")
        args = ["--step", step.to_s] + args

        cmd_exit = bash_log_output(INSTALLATION_HELPER_COMMAND, args)
        log.error("configuring snapper for root fs failed") unless cmd_exit == 0
        cmd_exit
      end

      # Execute a command with arguments on the target system (the machine that
      # is currently being installed). The arguments will be shell-quoted,
      # i.e. quotes and blanks are escaped with a backslash.
      #
      # @param cmd [String] command binary to execute
      # @param args [Array<String>] additional arguments
      # @return [Integer] command exit status
      #
      def bash_log_output(cmd, *args)
        words = [cmd]
        words << args.map { |arg| Shellwords.escape(arg) }
        cmd_line = args.join(" ")
        log.info("Executing #{cmd_line}")
        cmd_result = SCR.Execute(path(".target.bash_output"), cmd_line)
        log_cmd_result(cmd_result)
      end

      # Write the result of an executed command to the log.
      #
      # @param cmd_line [String] command line to be logged in case of error
      # @param cmd_result [Hash] stdout and stderr output and exit value
      # @return [Integer] command exit status
      #
      def log_cmd_result(cmd_line, cmd_result)
        cmd_stdout = cmd_result["stdout"] || ""
        cmd_stderr = cmd_result["stderr"] || ""
        cmd_exit   = cmd_result["exit"]
        log.error("Command failed with exit value #{cmd_exit}: #{cmd_line}") unless cmd_exit == 0

        cmd_stdout.each_line { |line| log.info("stdout: #{line}") }
        cmd_stderr.each_line { |line| log.info("stderr: #{line}") }
        cmd_exit
      end
    end
  end
end
