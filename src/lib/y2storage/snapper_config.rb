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
  # Part of this is done in libstorage-ng while the root filesystem is created
  # in Filesystems/BtrfsImpl.cc and Utils/SnapperConfig.cc.
  #
  # This part here is what is left to do after the package installation is
  # complete.
  class SnapperConfig
    include Yast::Logger

    class << self
      # [String] The last command line
      attr_reader :last_cmd

      # Flag that snapper should actually be configured.  The default is
      # false. Set this when marking the root btrfs to use snapshots.
      attr_writer :configure_snapper

      # Check if snapper should be configured.
      def configure_snapper?
        return @configure_snapper || false
      end

      # Do everything that has to be done to configure snapper after RPMs are
      # installed on the installation target.
      def post_rpm_install
        return unless configure_snapper?

        installation_helper_step_4
        write_snapper_config
        update_etc_sysconfig_yast2
        setup_snapper_quota
      end

      def installation_helper_step_4
        execute_on_target("/usr/lib/snapper/installation-helper --step 4")
      end

      def write_snapper_config
        execute_on_target("/usr/bin/snapper " \
          "--no-dbus " \
          "set-config " \
          "NUMBER_CLEANUP=yes " \
          "NUMBER_LIMIT=2-10 " \
          "NUMBER_LIMIT_IMPORTANT=4-10 " \
          "TIMELINE_CREATE=no")
      end

      def update_etc_sysconfig_yast2
        return unless execute_commands?
        Yast::SCR.Write(Yast.path(".sysconfig.yast2.USE_SNAPPER"), "yes")
        Yast::SCR.Write(Yast.path(".sysconfig.yast2"), nil)
      end

      def setup_snapper_quota
        execute_on_target("/usr/bin/snapper --no-dbus setup-quota")
      end

      # Execute a command line on the target system (the machine that is
      # currently being installed).
      #
      # @param cmd [String] command line
      # @return [Integer] command exit status
      #
      def execute_on_target(cmd)
        @last_cmd = cmd
        if execute_commands?
          log.info("Executing on target: #{cmd}")
          result = Yast::SCR.Execute(Yast.path(".target.bash_output"), cmd)
          log_cmd_result(cmd, result)
          result["exit"]
        else
          log.info("NOT executing on target: #{cmd}")
          0
        end
      end

      # For testing: Check if commands should actually be executed.
      # Override this to prevent undesired side effects.
      def execute_commands?
        return true
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
