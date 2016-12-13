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
require_relative "support/proposal_examples"
require_relative "support/proposal_context"

describe Y2Storage::Proposal do
  include_context "proposal"

  describe "#propose (one MBR partition table)" do
    using Y2Storage::Refinements::TestDevicegraph

    let(:expected) do
      file_name = scenario
      file_name.concat("-lvm") if lvm
      file_name.concat("-sep-home") if separate_home
      Storage::Devicegraph.new_from_file(output_file_for(file_name))
    end

    context "in a windows-only PC" do
      let(:scenario) { "windows-pc" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a windows-only PC with 256 KiB of MBR gap" do
      let(:scenario) { "windows-pc-mbr256" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a windows-only PC with 128 KiB of MBR gap" do
      let(:scenario) { "windows-pc-mbr128" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }

          it "fails to make a proposal" do
            expect { proposal.propose }.to raise_error Y2Storage::Proposal::Error
          end
        end

        context "without separate home" do
          let(:separate_home) { false }

          it "fails to make a proposal" do
            expect { proposal.propose }.to raise_error Y2Storage::Proposal::Error
          end
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a windows/linux multiboot PC" do
      let(:scenario) { "windows-linux-multiboot-pc" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a linux multiboot PC" do
      let(:scenario) { "multi-linux-pc" }
      let(:windows_partitions) { {} }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a windows/linux multiboot PC with pre-existing LVM" do
      let(:scenario) { "windows-linux-lvm-pc" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end
  end
end
