#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/summary_text"

describe Y2Partitioner::Widgets::SummaryText do
  before do
    devicegraph_stub("complex-lvm-encrypt")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject(:widget) { described_class.new }

  include_examples "CWM::RichText"

  describe "#init" do
    before do
      allow(Yast::Mode).to receive(:installation).and_return install
      allow(Y2Storage::PackageHandler).to receive(:new).and_return handler
    end

    let(:handler) do
      double("PackageHandler", add_feature_packages: packages, pkg_list: packages)
    end
    let(:packages) { [] }

    context "during installation" do
      let(:install) { true }

      before do
        allow(Y2Storage::PackageHandler).to receive(:new).and_return handler
      end

      let(:handler) do
        double("PackageHandler", add_feature_packages: packages, pkg_list: packages)
      end
      let(:packages) { [] }

      it "checks the packages to install" do
        expect(handler).to receive(:add_feature_packages).with current_graph
        widget.init
      end

      context "if there are no actions to perform" do
        context "and no packages will be installed" do
          let(:packages) { [] }

          it "updates the value with the corresponding headers" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "No changes to partitioning"
              expect(new_value).to include "No packages"
            end

            widget.init
          end
        end

        context "and some packages must be installed" do
          let(:packages) { ["btrfsprogs", "snapper", "btrfsprogs"] }

          it "updates the value including the corresponding headers" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "No changes to partitioning"
              expect(new_value).to include "Packages to install:"
            end

            widget.init
          end

          it "updates the value including the list of packages" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "<li>btrfsprogs</li>"
              expect(new_value).to include "<li>snapper</li>"
            end

            widget.init
          end
        end
      end

      context "if there are some actions to perform" do
        before do
          ptable = current_graph.find_by_name("/dev/sda").partition_table
          ptable.delete_partition("/dev/sda1")
          ptable.delete_partition("/dev/sda2")
        end

        context "and no packages will be installed" do
          let(:packages) { [] }

          it "updates the value including the corresponding headers" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "Changes to partitioning:"
              expect(new_value).to include "No packages"
            end

            widget.init
          end

          it "updates the value including the list of actions" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "Delete partition /dev/sda1"
              expect(new_value).to include "Delete partition /dev/sda2"
            end

            widget.init
          end
        end

        context "and some packages must be installed" do
          let(:packages) { ["btrfsprogs", "snapper", "btrfsprogs"] }

          it "updates the value including the corresponding headers" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "Changes to partitioning:"
              expect(new_value).to include "Packages to install:"
            end

            widget.init
          end

          it "updates the value including the list of packages" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "<li>btrfsprogs</li>"
              expect(new_value).to include "<li>snapper</li>"
            end

            widget.init
          end

          it "updates the value including the list of actions" do
            expect(widget).to receive(:value=) do |new_value|
              expect(new_value).to include "Delete partition /dev/sda1"
              expect(new_value).to include "Delete partition /dev/sda2"
            end

            widget.init
          end
        end
      end
    end

    context "in an installed system" do
      let(:install) { false }

      it "does not check the packages to install" do
        expect(Y2Storage::PackageHandler).to_not receive(:new)
        widget.init
      end

      context "if there are no actions to perform" do
        it "updates the value with the corresponding header" do
          expect(widget).to receive(:value=).with(/No changes/)
          widget.init
        end

        it "includes no header about packages in the new value" do
          expect(widget).to receive(:value=) do |new_value|
            expect(new_value).to_not include "ackages"
          end

          widget.init
        end
      end

      context "if there are some actions to perform" do
        before do
          ptable = current_graph.find_by_name("/dev/sda").partition_table
          ptable.delete_partition("/dev/sda1")
          ptable.delete_partition("/dev/sda2")
        end

        it "updates the value with the corresponding header" do
          expect(widget).to receive(:value=).with(/Changes to partitioning:/)
          widget.init
        end

        it "updates the value including the list of actions" do
          expect(widget).to receive(:value=) do |new_value|
            expect(new_value).to include "Delete partition /dev/sda1"
            expect(new_value).to include "Delete partition /dev/sda2"
          end

          widget.init
        end

        it "includes no header about packages in the new value" do
          expect(widget).to receive(:value=) do |new_value|
            expect(new_value).to_not include "ackages"
          end

          widget.init
        end
      end
    end
  end

  describe "#help" do
    before do
      allow(Yast::Mode).to receive(:installation).and_return install
    end

    context "during installation" do
      let(:install) { true }

      it "shows a specific help message for installation" do
        expect(subject.help).to match(/confirm the installation/)
      end
    end

    context "in an installed system" do
      let(:install) { false }

      it "shows a specific help message for a running system" do
        expect(subject.help).to match(/finish the partitioner/)
      end
    end
  end
end
