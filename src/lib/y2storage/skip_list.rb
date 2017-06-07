# encoding: utf-8
#
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

require "y2storage/skip_list_rule"

module Y2Storage
  # Devices skip list for AutoInstProposal
  #
  # This class determines when a device should be skipped based on a set of
  # predefined rules.
  #
  # Let's consider the following skip list in an AutoYaST profile:
  #
  #   <drive>
  #     <skip_list config:type="list">
  #       <listentry>
  #         <skip_key>driver</skip_key>
  #         <skip_value>usb-storage</skip_value>
  #       </listentry>
  #       <listentry>
  #         <skip_key>size_k</skip_key>
  #         <skip_value>1048576</skip_value>
  #         <skip_if_less_than config:type="boolean">true</skip_if_less_than>
  #       </listentry>
  #     </skip_list>
  #   </drive>
  #
  # @example Building the list of rules from a hash
  #   list #=> [ {"skip_key" => "name", "skip_value" => "/dev/sda" }
  #   SkipList.from_profile(list)
  #
  class SkipList
    # @return [Array<SkipRule>] List of rules to apply
    attr_reader :rules

    class << self
      # Creates an skip list from an AutoYaST profile
      #
      # @param profile_rules [Array<Hash>] List of profile skip rules
      # @return [SkipList]
      def from_profile(profile_rules)
        rules = profile_rules.map { |h| SkipListRule.from_profile_rule(h) }
        new(rules)
      end
    end

    # Constructor
    #
    # @param rules [Array<SkipRule>] List of rules to apply
    def initialize(rules)
      @rules = rules
    end

    # Determines whether a disk matches any of the rules on the list
    #
    # @return [Boolean] true only if it matches any rule
    def matches?(disk)
      rules.any? { |r| r.matches?(disk) }
    end
  end
end
