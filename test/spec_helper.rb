# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact Novell about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

# Set the paths
SRC_PATH = File.expand_path("../../src", __FILE__)
DATA_PATH = File.expand_path("../data", __FILE__)
ENV["Y2DIR"] = SRC_PATH

require "yast"
require_relative "support/storage_matchers"
require_relative "support/storage_helpers"

RSpec.configure do |c|
  c.include Yast::RSpec::StorageMatchers
  c.include Yast::RSpec::StorageHelpers
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  # for coverage we need to load all ruby files
  Dir["#{SRC_PATH}/lib/**/*.rb"].each { |f| require_relative f }

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end
