#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "pp"

# This file can be invoked separately for minimal testing.

module Yast
  module Storage
    #
    # Class to handle disk sizes in the MB/GB/TB range with readable output.
    #
    class DiskSize
      attr_accessor :size_k
      
      def initialize(size_k=0)
        @size_k = size_k
      end

      #
      # Factory methods
      #
      def self.kiB(kb_size)
        DiskSize.new(kb_size)
      end

      def self.MiB(mb_size)
        DiskSize.new(mb_size*1024)
      end
      
      def self.GiB(gb_size)
        DiskSize.new(gb_size*1024*1024)
      end
      
      def self.TiB(tb_size)
        DiskSize.new(tb_size*1024*1024*1024)
      end

      def to_kiB
        @size_k
      end

      def to_MiB
        @size_k/1024.0
      end

      def to_GiB
        @size_k/(1024.0*1024.0)
      end

      def to_TiB
        @size_k/(1024.0*1024.0*1024.0)
      end

      def to_s
        unit = ["kiB", "MiB", "GiB", "TiB"] # FIXME: translate!
        unit_index = 0
        size = @size_k.to_f

        while (size > 1024.0 && unit_index < unit.size-1)
          size /= 1024.0
          unit_index += 1
        end
          
        "#{size} #{unit[unit_index]}"
      end
    end
  end
end


if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  size = Yast::Storage::DiskSize.new(42)
  print "42 kiB: #{size} (#{size.size_k} kiB)\n"
  
  size = Yast::Storage::DiskSize.MiB(43)
  print "43 MiB: #{size} (#{size.size_k} kiB)\n"
  
  size = Yast::Storage::DiskSize.GiB(44)
  print "44 GiB: #{size} (#{size.size_k} kiB)\n"
  
  size = Yast::Storage::DiskSize.TiB(45)
  print "45 TiB: #{size} (#{size.size_k} kiB)\n"
  
  size = Yast::Storage::DiskSize.TiB(46*1024)
  print "46*1024 TiB: #{size} (#{size.size_k} kiB)\n"
  
  size = Yast::Storage::DiskSize.TiB(47*1024*1024*1024*1024*1024)
  print "Huge: #{size} (#{size.size_k} kiB)\n"
end
