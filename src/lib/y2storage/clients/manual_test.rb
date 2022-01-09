#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2021] SUSE LLC
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
require "y2partitioner/clients/main"
require "y2storage/clients/inst_disk_proposal"
require "y2storage/clients/autoinst_manual_test"

module Y2Storage
  module Clients
    # Client that runs any of the relevant parts of yast2-storage-ng into a mocked environment
    class ManualTest
      include Yast::I18n

      # Constructor
      def initialize
        textdomain "storage"

        @action = nil
        @command_error = nil
        @devicegraph_path = nil
        @profile_path = nil
        @control_file_path = nil
      end

      # Parses the arguments and opens the corresponding dialog
      def self.run
        client = new
        client.parse_args
        client.run
      end

      # Parses the command line arguments
      def parse_args
        @action = args.first&.to_sym
        return unless validate_action

        @devicegraph_path = args[1]
        return unless validate_devicegraph_path

        case action
        when :autoinst
          @profile_path = args[2]
          @command_error = _("No AutoYaST profile provided") unless profile_path
        when :proposal
          @control_file_path = args[2]
        end
      end

      # Executes the client
      def run
        if command_error
          display_help
          return :abort
        end

        Y2Storage::StorageManager.create_test_instance
        mock

        case action
        when :partitioner
          Y2Partitioner::Clients::Main.new.run(allow_commit: false)
        when :proposal
          Y2Storage::Clients::InstDiskProposal.new.run
        when :autoinst
          Y2Storage::Clients::AutoinstManualTest.new.run
        end
      end

      private

      # @return [String, nil] error to display if the client is not invoked correctly
      attr_reader :command_error

      # @return [String, nil] path of the file containing the devicegraph to use as main mock
      attr_reader :devicegraph_path

      # @return [String, nil] path to an AutoYaST profile
      attr_reader :profile_path

      # @return [String, nil] path to a control file to influence the action behavior
      attr_reader :control_file_path

      # @return [Symbol, nil] action to test, can be :partitioner, :proposal or :autoinst
      attr_reader :action

      # Command line arguments
      def args
        Yast::WFM.Args
      end

      # Mocks the execution environment
      def mock
        load_devicegraph if devicegraph_path
        load_profile if profile_path
        load_control_file if control_file_path
      end

      # @see #parse_args
      def validate_action
        if action.nil?
          @command_error = _("No action specified")
          return false
        end

        return true if [:partitioner, :proposal, :autoinst].include?(action)

        @command_error = format(_("Unknown action '%s'"), action)
        false
      end

      # @see #parse_args
      def validate_devicegraph_path
        if devicegraph_path.nil?
          @command_error = _("No devicegraph file provided")
          return false
        end

        return true if devicegraph_path =~ /.(xml|ya?ml)$/

        @command_error = format(
          _("Wrong devicegraph path %s, expecting foo.yml, foo.yaml or foo.xml."), devicegraph_path
        )
        false
      end

      # @see #mock
      def load_devicegraph
        if devicegraph_path =~ /.ya?ml$/
          Y2Storage::StorageManager.instance(mode: :rw).probe_from_yaml(devicegraph_path)
        else
          Y2Storage::StorageManager.instance(mode: :rw).probe_from_xml(devicegraph_path)
        end
      end

      # @see #mock
      def load_profile
        Yast.import "Profile"
        Yast::Profile.ReadXML(profile_path)
      end

      # @see #mock
      def load_control_file
        Yast.import "ProductFeatures"
        features = Yast::XML.XMLToYCPFile(control_file_path)
        Yast::ProductFeatures.Import(features)
      end

      # Prints a basic help text to the standard output
      def display_help
        warn command_error
        # TRANSLATORS: help text printed in the standard output in case of wrong command
        warn _(
          "Use one of the following:\n" \
          "  yast2 storage_testing partitioner devicegraph.(xml|yml)\n" \
          "  yast2 storage_testing proposal devicegraph.(xml|yml) [control_file.xml]\n" \
          "  yast2 storage_testing autoinst devicegraph.(xml|yml) profile.xml"
        )
      end
    end
  end
end
