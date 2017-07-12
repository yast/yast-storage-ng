#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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
require_relative "support/proposed_partitions_examples"
require_relative "support/boot_requirements_context"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  describe "#needed_partitions in a S/390 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :s390 }
    let(:use_lvm) { false }

    before do
      allow(dev_sda).to receive(:is?).with(:dasd).and_return(dasd)
      allow(dev_sda).to receive(:type).and_return(type)
      allow(dev_sda).to receive(:format).and_return(format)
    end

    context "trying to install in a zfcp disk" do
      let(:dasd) { false }
      let(:type) { Y2Storage::DasdType::UNKNOWN }
      let(:format) { Y2Storage::DasdFormat::NONE }

      context "with a partitions-based proposal" do
        let(:use_lvm) { false }

        it "requires only a /boot/zipl partition" do
          expect(checker.needed_partitions).to contain_exactly(
            an_object_having_attributes(mount_point: "/boot/zipl")
          )
        end
      end

      context "with a LVM-based proposal" do
        let(:use_lvm) { true }

        it "requires only a /boot/zipl partition" do
          expect(checker.needed_partitions).to contain_exactly(
            an_object_having_attributes(mount_point: "/boot/zipl")
          )
        end
      end

      context "with an encrypted proposal" do
        let(:use_lvm) { false }
        let(:use_encryption) { true }

        it "requires only a /boot/zipl partition" do
          expect(checker.needed_partitions).to contain_exactly(
            an_object_having_attributes(mount_point: "/boot/zipl")
          )
        end
      end
    end

    context "trying to install in a FBA DASD disk" do
      let(:dasd) { true }
      let(:type) { Y2Storage::DasdType::FBA }
      # Format and LVM are irrelevant
      let(:format) { Y2Storage::DasdFormat::NONE }
      let(:use_lvm) { false }

      it "raises an error" do
        expect { checker.needed_partitions }
          .to raise_error Y2Storage::BootRequirementsChecker::Error
      end
    end

    context "trying to install in a (E)CKD DASD disk" do
      let(:dasd) { true }
      let(:type) { Y2Storage::DasdType::ECKD }

      context "if the disk is formatted as LDL" do
        let(:format) { Y2Storage::DasdFormat::LDL }
        # LVM is irrelevant
        let(:use_lvm) { false }

        it "raises an error" do
          expect { checker.needed_partitions }
            .to raise_error Y2Storage::BootRequirementsChecker::Error
        end
      end

      context "if the disk is formatted as CDL" do
        let(:format) { Y2Storage::DasdFormat::CDL }

        context "with a partitions-based proposal" do
          let(:use_lvm) { false }

          it "requires only a /boot/zipl partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/zipl")
            )
          end
        end

        context "with a LVM-based proposal" do
          let(:use_lvm) { true }

          it "requires only a /boot/zipl partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/zipl")
            )
          end
        end

        context "with an encrypted proposal" do
          let(:use_lvm) { false }
          let(:use_encryption) { true }

          it "requires only a /boot/zipl partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/zipl")
            )
          end
        end
      end
    end

    context "when proposing a /boot/zipl partition" do
      let(:zipl_part) { find_vol("/boot/zipl", checker.needed_partitions(target)) }
      # Default values to ensure the partition is proposed
      let(:dasd) { false }
      let(:type) { Y2Storage::DasdType::UNKNOWN }
      let(:format) { Y2Storage::DasdFormat::NONE }
      let(:use_lvm) { false }

      include_examples "proposed /boot/zipl partition"
    end
  end
end
