#!/usr/bin/env rspec
# Copyright (c) [2017-2019] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../spec_helper"
require "y2partitioner/bidi"

# Removes the :sortKey term from a :cell term, possibly returning only
# the single param of the term.
#
# Checking the sort-key in the testsuite would not be future-proof
# since libstorage-ng is allowed to change the sort-key anytime.
def remove_sort_key(term)
  return term if term.value != :cell

  term.params.delete_if { |param| param.is_a?(Yast::Term) && param.value == :sortKey }
  return term if term.params.size > 1

  Bidi.bidi_strip(term.params[0])
end

# Removes the :sortKey term from :cell terms somewhere inside (to the
# extent needed so far) of value. Also see remove_sort_key.
def remove_sort_keys(value)
  return remove_sort_key(value) if value.is_a?(Yast::Term)

  return value.map { |subvalue| remove_sort_keys(subvalue) } if value.is_a?(Array)

  value
end

# Content of the given table, with each row represented as an array of values
#
# @param table [CWM::Table]
# @return [Array<Array>]
def table_values(table)
  table.items.flat_map { |i| table_item_values(i) }
end

# All values for the given column of a table
#
# @param table [CWM::Table]
# @param index [Integer] position of the column in the table
# @return [Array]
def column_values(table, index)
  table_values(table).map { |p| p[index] }
end

# @see #table_values
def table_item_values(item)
  return [remove_sort_keys(item)] if item.is_a?(Array)

  [
    remove_sort_keys(item.values),
    *item.children.flat_map { |i| table_item_values(i) }
  ]
end
