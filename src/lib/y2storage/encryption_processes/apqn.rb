# Copyright (c) [2020] SUSE LLC
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

require "yast2/execute"

module Y2Storage
  module EncryptionProcesses
    # Class representing an APQN used for generating a new secure key, see {SecureKey}.
    #
    # For more information, see
    # https://www.ibm.com/support/knowledgecenter/linuxonibm/com.ibm.linux.z.lxdc/lxdc_zkey_reference.html
    class Apqn
      # Location of the lszcrypt command
      LSZCRYPT = "/sbin/lszcrypt".freeze
      private_constant :LSZCRYPT

      class << self
        # All APQNs found in the system
        #
        # @return [Array<Apqn>]
        def all
          read_apqns
        end

        # All online APQNs found in the system
        #
        # @return [Array<Apqn>]
        def online
          all.select(&:online?)
        end

        private

        # Reads APQNs data from the system and creates APQNs objects
        #
        # @return [Array<Apqn>]
        def read_apqns
          apqns_data.map do |data|
            name, type, mode, status, = data

            new(name, type, mode, status).tap do |apqn|
              apqn.read_master_keys
            end
          end
        end

        # Data of the APQNs found in the system
        #
        # For each APQN, it returns its name (card.domain), type, mode, status and requests, see
        # {#execute_lszcrypt}.
        #
        # @return [Array<Array<String>>]
        def apqns_data
          data = execute_lszcrypt.split("\n").map(&:split)
          return [] if data.size == 2

          # remove header
          data.shift(2)

          # select card.domain entries
          data.select { |d| d.first.match?(/.+\..+/) }
        end

        # Executes lszcrypt command
        #
        # Example of lszcrypt output:
        #
        #   "CARD.DOMAIN TYPE  MODE        STATUS  REQUESTS\n" \
        #   "----------------------------------------------\n" \
        #   "01          CEX5C CCA-Coproc  online         1\n" \
        #   "01.0001     CEX5C CCA-Coproc  online         1\n" \
        #   "01.0004     CEX5C CCA-Coproc  online         0\n" \
        #   "01.0005     CEX5C CCA-Coproc  online         0"
        #
        # @return [String]
        def execute_lszcrypt
          return File.read("/home/ags/projects/yast/yast-storage-ng/pervasive/lszcrypt.out")
          Yast::Execute.locally!(LSZCRYPT, stdout: :capture)
        rescue Cheetah::ExecutionFailed
          ""
        end
      end

      # Card number
      #
      # @return [String] e.g., "01"
      attr_reader :card

      # Domain number
      #
      # @return [String] e.g., "0001"
      attr_reader :domain

      # Card type
      #
      # @return [String] e.g., "CEX5C"
      attr_reader :type

      # Card mode
      #
      # @return [String] e.g., "CCA-Coproc"
      attr_reader :mode

      # APQN status
      #
      # @return [String] e.g., "online", "offline"
      attr_reader :status

      attr_reader :aes_master_key

      # Constructor
      #
      # @param name [String]
      # @param type [String]
      # @param mode [String]
      # @param status [String]
      # @param _others [Array<String>]
      def initialize(name, type, mode, status, *_others)
        @card, @domain = name.split(".")
        @type = type
        @mode = mode
        @status = status
      end

      # APQN name
      #
      # @return [String]
      def name
        "#{card}.#{domain}"
      end

      # Whether the APQN is online
      #
      # @return [Boolean]
      def online?
        status == "online"
      end

      def read_master_keys
        @aes_master_key = aes_key_from_file
      end

      private

      def aes_key_from_file
        content = File.read(master_key_file)
        return nil if content&.empty?

        entry = content.lines.grep(/^AES CUR: valid/).first
        return nil unless entry

        entry.split.last
      rescue SystemCallError
        nil
      end

      def master_key_file
        return "/home/ags/projects/yast/yast-storage-ng/pervasive/cat.#{card}.#{domain}.out"
        "/sys/bus/ap/devices/card#{card}/#{name}/mkvps"
      end
    end
  end
end
