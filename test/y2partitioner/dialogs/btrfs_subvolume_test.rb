#!/usr/bin/env rspec
# Copyright (c) [2017-2018] SUSE LLC
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

describe Y2Partitioner::Dialogs::BtrfsSubvolume do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  subject { described_class.new(filesystem) }

  let(:filesystem) do
    device_graph = Y2Partitioner::DeviceGraphs.instance.current
    Y2Storage::BlkDevice.find_by_name(device_graph, dev_name).filesystem
  end

  let(:dev_name) { "/dev/sda2" }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "has an input field for the subvolume path" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumePath).to receive(:new)
      subject.contents
    end

    it "has a checkbox for the subvolume nocow attribute" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeNocow).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumePath do
    subject { described_class.new(form, filesystem: filesystem) }

    let(:form) { Y2Partitioner::Dialogs::BtrfsSubvolume::Form.new }

    before do
      allow(subject).to receive(:value).and_return(value)
    end

    let(:value) { "" }

    include_examples "CWM::AbstractWidget"

    describe "#store" do
      let(:value) { "@/foo" }

      it "saves the entered value" do
        subject.store
        expect(form.path).to eq(value)
      end
    end

    describe "#validate" do
      context "when no path is entered" do
        let(:value) { "" }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to be(false)
        end
      end

      context "when a path with unsafe characters is entered" do
        let(:value) { "@/foo,bar" }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error).with(/contains unsafe characters/)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to be(false)
        end
      end

      context "when a path is entered" do
        context "and the filesystem does not have a specific subvolumes prefix" do
          let(:dev_name) { "/dev/sdd1" }

          context "and the entered path is an absolute path" do
            let(:value) { "///foo" }

            it "removes extra slashes" do
              expect(subject).to receive(:value=).with("foo").ordered
              subject.validate
            end
          end
        end

        context "and the filesystem has a specific subvolumes prefix" do
          let(:dev_name) { "/dev/sda2" }

          context "and the path does not start with the subvolumes prefix" do
            let(:value) { "///foo" }

            it "removes extra slashes and prepend the subvolumes prefix" do
              expect(subject).to receive(:value=).with("foo").ordered
              expect(subject).to receive(:value=).with(/^@\/.*/).ordered
              subject.validate
            end
          end
        end

        context "and there is no subvolume with that path" do
          context "and the mount point already exists" do
            let(:value) { "@/home" }

            it "shows an error message" do
              expect(Yast::Popup).to receive(:Error).at_least(:once)
              subject.validate
            end

            it "returns false" do
              expect(subject.validate).to be(false)
            end
          end

          context "and the mount point does not exist yet" do
            let(:value) { "@/foo" }

            it "returns true" do
              expect(subject.validate).to be(true)
            end
          end
        end

        context "and there is a subvolume with that path" do
          let(:value) { "@/home" }

          it "shows an error message" do
            expect(Yast::Popup).to receive(:Error)
            subject.validate
          end

          it "returns false" do
            expect(subject.validate).to be(false)
          end
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::BtrfsSubvolume::SubvolumeNocow do
    subject { described_class.new(form) }

    let(:form) { Y2Partitioner::Dialogs::BtrfsSubvolume::Form.new }

    before do
      allow(subject).to receive(:value).and_return(value)
    end

    let(:value) { false }

    include_examples "CWM::AbstractWidget"

    describe "#store" do
      let(:value) { true }

      it "saves the entered value" do
        subject.store
        expect(form.nocow).to eq(value)
      end
    end
  end
end
