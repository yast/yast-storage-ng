# Copyright (c) [2016-2019] SUSE LLC
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

# Set the paths
SRC_PATH = File.expand_path("../src", __dir__)
DATA_PATH = File.expand_path("data", __dir__)
TEST_PATH = File.expand_path(__dir__)
ENV["Y2DIR"] = SRC_PATH

# make sure we run the tests in English locale
# (some tests check the output which is marked for translation)
ENV["LC_ALL"] = "en_US.UTF-8"
# fail fast if a class does not declare textdomain (bsc#1130822)
ENV["Y2STRICTTEXTDOMAIN"] = "1"

LIBS_TO_SKIP = [
  "installation/console/menu_plugin",
  "installation/proposal_runner",
  "installation/proposal_store",
  "y2packager/repository"
]

# Hack to avoid to require some files
#
# This is here to avoid a cyclic dependency with yast-installation at build time.
# Storage-ng does not include a BuildRequires for yast-installation, so the require
# for files defined by that package must be avoided.
module Kernel
  alias_method :old_require, :require

  def require(path)
    old_require(path) unless LIBS_TO_SKIP.include?(path)
  end
end

require "yast"
require "yast/rspec"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  # track all ruby files under src
  SimpleCov.track_files("#{SRC_PATH}/lib/**/*.rb")

  # additionally use the LCOV format for on-line code coverage reporting at CI
  if ENV["CI"] || ENV["COVERAGE_LCOV"]
    require "simplecov-lcov"

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      # this is the default Coveralls GitHub Action location
      # https://github.com/marketplace/actions/coveralls-github-action
      c.single_report_path = "coverage/lcov.info"
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter
    ]
  end
end

require_relative "support/storage_helpers"

module Installation
  # The Installation::ProposalStore and Installation::ProposalRunner classes are not loaded in the
  # tests to avoid cyclic dependencies with yast2-installation at build time.
  class ProposalStore; end

  class ProposalRunner
    def run; end
  end
end

# Yast::Profile, AutoinstStorage and AutoinstConfig might be missing in RPM
# build to avoid cyclic dependencies with the autoyast2-installation package at build time.
Yast::RSpec::Helpers.define_yast_module("Profile", methods: [:current, :ReadXML])
Yast::RSpec::Helpers.define_yast_module("AutoinstStorage", methods: [:Import])
Yast::RSpec::Helpers.define_yast_module("AutoinstConfig", methods: [:Confirm=])

RSpec.configure do |c|
  c.mock_with :rspec do |config|
    # verify that the mocked methods actually exist
    config.verify_partial_doubles = true
  end

  c.include Yast::RSpec::StorageHelpers

  c.before do
    # Y2Packager is not loaded in tests to avoid cyclic dependencies with
    # yast-installation package at build time. Here, all usage of Y2Packager
    # is mocked.
    stub_const("Y2Packager::Repository", double("Y2Packager::Repository"))
    allow(Y2Packager::Repository).to receive(:all).and_return([])

    allow(Y2Storage::DumpManager.instance).to receive(:dump)

    if respond_to?(:architecture) # Match mocked architecture in Arch module
      # In a test, define a symbol :architecture accordingly:
      #   let(:architecture) { :aarch64 }
      allow(Yast::Arch).to receive(:x86_64).and_return(architecture == :x86_64)
      allow(Yast::Arch).to receive(:i386).and_return(architecture == :i386)
      allow(Yast::Arch).to receive(:ppc).and_return(architecture == :ppc)
      allow(Yast::Arch).to receive(:s390).and_return(architecture == :s390)
      allow(Yast::Arch).to receive(:aarch64).and_return(architecture == :aarch64)

      # If :storage_arch is defined, the Storage::Arch object is used instead of Yast::Arch.
      if respond_to?(:storage_arch)
        arch = Y2Storage::Arch.new(storage_arch)

        allow(Y2Storage::Arch).to receive(:new).and_return(arch)

        allow(storage_arch).to receive(:x86?).and_return(architecture == :x86)
        allow(storage_arch).to receive(:ppc?).and_return(architecture == :ppc)
        allow(storage_arch).to receive(:s390?).and_return(architecture == :s390)
      end
    end

    allow(Y2Storage::HWInfoReader.instance).to receive(:for_device)
      .and_return Y2Storage::HWInfoDisk.new

    # Bcache is only supported for x86_64 architecture. Probing the devicegraph complains if Bcache is
    # used with another architecture. Bcache error is avoided here. Otherwise, x86_84 architecture must
    # to be set for every test using Bcache (which has demonstrated to be quite error prone).
    #
    # This should be properly unmocked in the tests where real Bcache checking needs to be performed
    # (e.g., for ProbedDevicegraphChecker tests).
    allow_any_instance_of(Y2Storage::ProbedDevicegraphChecker)
      .to receive(:unsupported_bcache?).and_return(false)
  end

  # Some tests use ProposalSettings#new_for_current_product to initialize
  # the settings. That method sets some default values when there is not
  # imported features (i.e., when control.xml is not found).
  #
  # The product features could be modified during testing. Due to there are
  # tests relying on settings with pristine default values, it is necessary to
  # reset the product features to not interfere in the results.
  c.after(:all) do
    Yast::ProductFeatures.Import({})
  end
end
