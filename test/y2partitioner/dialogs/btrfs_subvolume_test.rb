#!/usr/bin/env rspec

# Copyright (c) [2017-2020] SUSE LLC
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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/btrfs_subvolume"
require "y2partitioner/actions/controllers/btrfs_subvolume"

describe Y2Partitioner::Dialogs::BtrfsSubvolume do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(controller) }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::BtrfsSubvolume.new(filesystem, subvolume: subvolume)
  end

  let(:filesystem) { current_graph.find_by_name(device_name).filesystem }

  let(:subvolume) { nil }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device_name) { "/dev/sda2" }

  let(:scenario) { "mixed_disks_btrfs" }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "has an input field for the subvolume path" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumePath).to receive(:new)
      subject.contents
    end

    it "has a checkbox for the subvolume noCoW attribute" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeNocow).to receive(:new)
      subject.contents
    end

    it "has a widget to set the subvolume referenced limit" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimit).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumePath do
    subject { described_class.new(controller) }

    before do
      allow(subject).to receive(:value).and_return(value)

      allow(Yast2::Popup).to receive(:show)
    end

    let(:value) { "" }

    include_examples "CWM::AbstractWidget"

    describe "#store" do
      let(:value) { "@/foo" }

      it "saves the given value in the controller" do
        subject.store
        expect(controller.subvolume_path).to eq(value)
      end
    end

    describe "#validate" do
      shared_examples "common validations" do
        context "when no path is given" do
          let(:value) { "" }

          it "shows an error message" do
            expect(Yast2::Popup).to receive(:show).with(/Empty .* path .*/, anything)
            subject.validate
          end

          it "returns false" do
            expect(subject.validate).to be(false)
          end
        end

        context "when a path with unsafe characters is given" do
          let(:value) { "@/foo,bar" }

          it "shows an error message" do
            expect(Yast2::Popup).to receive(:show).with(/contains unsafe characters/, anything)
            subject.validate
          end

          it "returns false" do
            expect(subject.validate).to be(false)
          end
        end

        context "and the filesystem does not have a specific subvolumes prefix" do
          let(:device_name) { "/dev/sdd1" }

          let(:value) { "///foo" }

          it "does not modify the given path" do
            expect(subject).to_not receive(:value=)
            subject.validate
          end
        end

        context "and the filesystem has a specific subvolumes prefix" do
          let(:device_name) { "/dev/sda2" }

          context "and the path does not start with the subvolumes prefix" do
            let(:value) { "///foo" }

            it "removes extra slashes and prepend the subvolumes prefix" do
              expect(subject).to receive(:value=).with("@/foo")

              subject.validate
            end
          end
        end

        context "and there is a subvolume with the resulting path" do
          let(:value) { "@/home" }

          it "shows an error message" do
            expect(Yast2::Popup).to receive(:show).with(/already exists/, anything)
            subject.validate
          end

          it "returns false" do
            expect(subject.validate).to be(false)
          end
        end

        context "and there is not a subvolume with the resulting path" do
          context "and there already are subvolumes on disk under the given path" do
            let(:value) { "@/var" }

            it "shows an error message" do
              expect(Yast2::Popup).to receive(:show).with(/Cannot create/, anything)
              subject.validate
            end

            it "returns false" do
              expect(subject.validate).to be(false)
            end
          end

          context "and there are not subvolumes on disk under the given path" do
            let(:value) { "@/foo" }

            it "does not show an error message" do
              expect(Yast2::Popup).to_not receive(:show)
              subject.validate
            end

            it "returns true" do
              expect(subject.validate).to be(true)
            end
          end
        end
      end

      context "when creating a subvolume" do
        include_examples "common validations"
      end

      context "when editing a subvolume" do
        context "when the subvolume exists on disk" do
          let(:subvolume) { filesystem.btrfs_subvolumes.first }

          it "does not try to fix the path" do
            expect(subject).to_not receive(:fix_path)

            subject.validate
          end

          it "returns true" do
            expect(subject.validate).to eq(true)
          end
        end

        context "when the subvolume does not exist on disk yet" do
          let(:subvolume) { filesystem.create_btrfs_subvolume("@/foo", false) }

          context "and the path is not modifed" do
            let(:value) { "@/foo" }

            it "does not try to fix the path" do
              expect(subject).to_not receive(:fix_path)

              subject.validate
            end

            it "returns true" do
              expect(subject.validate).to eq(true)
            end
          end

          context "and the path is modifed" do
            include_examples "common validations"
          end
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeNocow do
    subject { described_class.new(controller) }

    before do
      allow(subject).to receive(:value).and_return(value)
    end

    let(:value) { false }

    include_examples "CWM::AbstractWidget"

    describe "#store" do
      let(:value) { true }

      it "saves the given value" do
        subject.store

        expect(controller.subvolume_nocow).to eq(value)
      end
    end
  end

  describe Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimit do
    subject { described_class.new(controller) }

    let(:size_widget) { double("SubvolumeRferLimitSize", disable: nil) }
    let(:check_box_widget) { double("SubvolumeRferLimitCheckBox", disable: nil) }

    include_examples "CWM::AbstractWidget"

    describe "#contents" do
      it "contains a check box to enable/disable the quota" do
        expect(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimitCheckBox).to receive(:new)
        subject.contents
      end

      it "contains an input to enter the size of the quota" do
        expect(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimitSize)
          .to receive(:new).and_return size_widget
        subject.contents
      end
    end

    describe "#store" do
      before do
        allow(subject).to receive(:value).and_return(value)
      end

      let(:value) { Y2Storage::DiskSize.MiB(500) }

      it "saves the given value" do
        subject.store

        expect(controller.subvolume_referenced_limit).to eq(value)
      end
    end

    describe "#value" do
      before do
        allow(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimitCheckBox)
          .to receive(:new).and_return check_box_widget
        allow(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimitSize)
          .to receive(:new).and_return size_widget
      end

      context "if quotas are disabled for the filesystem" do
        before do
          expect(controller).to receive(:quota?).and_return false
        end

        it "returns unlimited" do
          expect(subject.value).to be_unlimited
        end
      end

      context "if quotas are enabled for the filesystem" do
        before do
          expect(controller).to receive(:quota?).and_return true
        end

        context "and the checkbox is disabled" do
          before do
            allow(check_box_widget).to receive(:value).and_return false
          end

          it "returns unlimited" do
            expect(subject.value).to be_unlimited
          end
        end

        context "and the checkbox is enabled" do
          before do
            allow(check_box_widget).to receive(:value).and_return true
            allow(size_widget).to receive(:value).and_return size_value
          end

          let(:size_value) { Y2Storage::DiskSize.MiB(22) }

          it "returns unlimited" do
            expect(subject.value).to eq size_value
          end
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimitSize do
    let(:initial) { Y2Storage::DiskSize.MiB(25) }
    subject { described_class.new(initial) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      it "writes to the UI the string representation of the initial value" do
        expect(Yast::UI).to receive(:ChangeWidget).with(anything, :Value, "25.00 MiB")
        subject.init
      end
    end
  end

  describe Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeRferLimitCheckBox do
    let(:initial) { true }
    let(:size_widget) { double("SubvolumeRferLimitSize", disable: nil, enable: nil) }

    subject { described_class.new(true, size_widget) }

    include_examples "CWM::AbstractWidget"
  end
end
