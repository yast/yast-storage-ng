#!/usr/bin/env ruby
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

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "y2storage"

size = Y2Storage::DiskSize.new(0)
print "0 B: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.new(511) - Y2Storage::DiskSize.new(512)
print "too bad: 511 B - 512 B: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.new(42)
print "42 B: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.new(512)
print "512 B: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.KiB(42)
print "42 KiB: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.MiB(43)
print "43 MiB: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.GiB(44)
print "44 GiB: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.TiB(45)
print "45 TiB: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.PiB(46)
print "46 PiB: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.EiB(47)
print "47 EiB: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.TiB(48 * (1024**5))
print "Huge: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.unlimited
print "Hugest: #{size} (#{size.size})\n"

size = Y2Storage::DiskSize.MiB(12) * 3
print "3*12 MiB: #{size} (#{size.size})\n"

size2 = size + Y2Storage::DiskSize.MiB(20)
print "3*12+20 MiB: #{size2} (#{size2.size})\n"

size2 /= 13
print "(3*12+20)/7 MiB: #{size2} (#{size2.size})\n"

print "#{size} < #{size2} ? -> #{size < size2}\n"
print "#{size} > #{size2} ? -> #{size > size2}\n"
