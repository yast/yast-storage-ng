#!/usr/bin/env rspec
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

require_relative "spec_helper"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

RSpec::Matchers.define :be_start_aligned do
  match do |partition|
    grain = partition.partition_table.align_grain
    block_size = partition.region.block_size
    sector = partition.region.start
    overhead = (block_size * sector) % grain
    overhead.zero?
  end
end

RSpec::Matchers.define :be_end_aligned do
  match do |partition|
    grain = partition.partition_table.align_grain
    block_size = partition.region.block_size
    sector = partition.region.end
    overhead = (block_size * sector + block_size) % grain
    overhead.zero?
  end
end

describe Y2Storage::GuidedProposal do
  include_context "proposal"

  subject(:proposal) { described_class.new(settings: settings) }
  let(:architecture) { :s390 }

  describe "#propose" do
    before do
      allow_any_instance_of(Y2Storage::Dasd).to receive(:type).and_return(type)
      allow_any_instance_of(Y2Storage::Dasd).to receive(:format).and_return(format)
    end

    let(:type) { Y2Storage::DasdType::UNKNOWN }
    let(:format) { Y2Storage::DasdFormat::NONE }

    context "with a zfcp disk" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:expected_scenario) { "s390_zfcp_zipl" }

      include_examples "proposed layout"
    end

    context "with a FBA DASD disk" do
      let(:scenario) { "empty_dasd_50GiB" }
      let(:type) { Y2Storage::DasdType::FBA }

      it "fails to make a proposal" do
        expect { proposal.propose }.to raise_error Y2Storage::Error
      end
    end

    context "with a (E)CKD DASD disk" do
      let(:scenario) { "empty_dasd_50GiB" }
      let(:expected_scenario) { "s390_dasd_zipl" }

      let(:type) { Y2Storage::DasdType::ECKD }

      context "formated as LDL" do
        let(:format) { Y2Storage::DasdFormat::LDL }

        it "fails to make a proposal" do
          expect { proposal.propose }.to raise_error Y2Storage::Error
        end
      end

      context "formated as CDL" do
        let(:format) { Y2Storage::DasdFormat::CDL }

        context "not using LVM" do
          let(:lvm) { false }

          context "when try to create three partitions" do
            let(:separate_home) { false }

            it "proposes the expected layout" do
              proposal.propose
              expect(proposal.devices.to_str).to eq expected.to_str
            end

            it "proposes partitions starting with correct alignment" do
              proposal.propose
              expect(proposal.devices.partitions).to all(be_start_aligned)
            end

            it "proposes partitions ending with correct alignment" do
              proposal.propose
              expect(proposal.devices.partitions).to all(be_end_aligned)
            end

            context "and a partition already exists" do
              let(:scenario) { "dasd_50GiB" }

              it "proposes the expected layout" do
                proposal.propose
                expect(proposal.devices.to_str).to eq expected.to_str
              end
            end
          end

          context "when try to create more than three partitions" do
            let(:separate_home) { true }

            it "fails to make a proposal" do
              expect { proposal.propose }.to raise_error Y2Storage::Error
            end
          end
        end

        include_examples "LVM-based proposed layouts"
      end
    end
  end
end
