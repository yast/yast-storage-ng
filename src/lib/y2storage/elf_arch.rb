# encoding: utf-8

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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "yast2/execute"

Yast.import "Directory"

module Y2Storage
  # Class to extract the architecture in which a filesystem was created
  class ELFArch
    # Constructor
    #
    # @param root_path [String] path where the filesystem is mounted
    def initialize(root_path = "/")
      @root_path = root_path
    end

    # Architecture extracted from the filesystem
    #
    # @return [String] e.g., "x86_64", "ppc", "s390", etc. It returns
    #   "unknown" when the check fails.
    def value
      @value ||= command_stdout
    end

  private

    # @return [String]
    attr_reader :root_path

    COMMAND_NAME = "elf-arch".freeze

    private_constant :COMMAND_NAME

    # Runs "elf-arch" command over the bash binary and returns its output
    #
    # @return [String] architecture or "unknown" in case of error
    def command_stdout
      Yast::Execute.locally!(command, bash_path, stdout: :capture).chomp
    rescue Cheetah::ExecutionFailed
      "unknown"
    end

    # Absolute path to "elf-arch" command
    #
    # @return [String]
    def command
      File.join(Yast::Directory.ybindir, COMMAND_NAME)
    end

    # Absolute path to bash binary inside the filesystem
    #
    # @return [String]
    def bash_path
      File.join(root_path, "/bin/bash")
    end
  end
end
