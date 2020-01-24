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
require "y2partitioner/widgets/fstab_options"
require "y2partitioner/actions/controllers/filesystem"

RSpec.shared_examples "CWM::AbstractWidget#init#store" do
  describe "#init" do
    it "does not crash" do
      next unless subject.respond_to?(:init)

      expect { subject.init }.to_not raise_error
    end
  end

  describe "#store" do
    it "does not crash" do
      next unless subject.respond_to?(:store)

      expect { subject.store }.to_not raise_error
    end
  end
end

RSpec.shared_examples "InputField" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ValueBasedWidget"
  include_examples "CWM::AbstractWidget#init#store"
end

RSpec.shared_examples "CheckBox" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ValueBasedWidget"
  include_examples "CWM::AbstractWidget#init#store"
end

RSpec.shared_examples "FstabCheckBox" do
  include_examples "CheckBox"
end

describe Y2Partitioner::Widgets do
  before do
    devicegraph_stub("mixed_disks.yml")

    allow(device.filesystem.type).to receive(:codepage).and_return("437")
    allow(device.filesystem.type).to receive(:iocharset).and_return("utf8")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::Filesystem.new(device, "")
  end

  let(:device) { Y2Storage::Partition.find_by_name(current_graph, "/dev/sdb2") }

  subject { described_class.new(controller) }

  describe Y2Partitioner::Widgets::FstabOptions do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::VolumeLabel do
    before do
      allow(subject).to receive(:value).and_return(label)
      allow(parent_widget).to receive(:widgets).and_return(widgets)
      allow(mount_by_widget).to receive(:value).and_return(mount_by)
    end

    let(:parent_widget) { Y2Partitioner::Widgets::FstabOptions.new(controller) }

    let(:widgets) { [mount_by_widget] }

    let(:mount_by_widget) { Y2Partitioner::Widgets::MountBy.new(controller) }

    let(:label) { "" }

    let(:mount_by) { :uuid }

    subject { described_class.new(controller, parent_widget) }

    include_examples "InputField"

    describe "#validate" do
      RSpec.shared_examples "given_label" do
        context "and a label is given" do
          context "and there is already a filesystem with the given label" do
            let(:label) { "root" }

            it "shows an popup error" do
              expect(Yast::Popup).to receive(:Error)
              subject.validate
            end

            it "returns false" do
              expect(subject.validate).to eq(false)
            end
          end

          context "and there is no a filesystem with the given label" do
            let(:label) { "foo" }

            it "returns true" do
              expect(subject.validate).to eq(true)
            end
          end
        end
      end

      context "when the device is not mounted by label" do
        let(:mount_by) { :uuid }

        context "and a label is not given" do
          let(:label) { "" }

          it "returns true" do
            expect(subject.validate).to eq(true)
          end
        end

        include_examples "given_label"
      end

      context "when the device is mounted by label" do
        let(:mount_by) { :label }

        context "and a label is not given" do
          let(:label) { "" }

          it "returns false" do
            expect(subject.validate).to eq(false)
          end
        end

        include_examples "given_label"
      end
    end
  end

  describe Y2Partitioner::Widgets::MountBy do
    before do
      allow(subject).to receive(:value).and_return(:uuid)
    end

    include_examples "CWM::ComboBox"
    include_examples "CWM::AbstractWidget#init#store"

    describe "#items" do
      before do
        allow(controller).to receive(:mount_point).and_return(mount_point)
        allow(mount_point).to receive(:suitable_mount_bys).and_return(possible_mount_bys)
      end

      let(:mount_point) { controller.filesystem.mount_point }

      let(:possible_mount_bys) do
        Y2Storage::Filesystems::MountByType.all - not_possible_mount_bys
      end

      let(:not_possible_mount_bys) do
        [
          Y2Storage::Filesystems::MountByType::LABEL,
          Y2Storage::Filesystems::MountByType::ID
        ]
      end

      it "only includes the allowed mount bys" do
        expect(subject.items).to eq [
          ["device", "Device Name"],
          ["path", "Device Path"],
          ["uuid", "UUID"]
        ]
      end
    end
  end

  describe Y2Partitioner::Widgets::GeneralOptions do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::Noauto do
    include_examples "FstabCheckBox"
  end

  describe Y2Partitioner::Widgets::ReadOnly do
    include_examples "FstabCheckBox"
  end

  describe Y2Partitioner::Widgets::MountUser do
    include_examples "FstabCheckBox"
  end

  describe Y2Partitioner::Widgets::Quota do
    include_examples "CheckBox"
  end

  describe Y2Partitioner::Widgets::JournalOptions do
    include_examples "CWM::ComboBox"
    include_examples "CWM::AbstractWidget#init#store"
  end

  describe Y2Partitioner::Widgets::ArbitraryOptions do
    let(:handled_values)  { ["ro", "rw", "auto", "noauto", "user", "nouser"] }
    let(:handled_regexps) { [/^iocharset=/, /^codepage=/] }
    let(:options_widget)  { double("FstabOptions", values: handled_values, regexps: handled_regexps) }

    subject { described_class.new(controller, options_widget) }
    include_examples "InputField"

    it "picks up values handled in other widgets" do
      expect(subject.send(:other_values)).to eq handled_values
    end

    it "picks up regexps handled in other widgets" do
      expect(subject.send(:other_regexps)).to eq handled_regexps
    end

    describe "#handled_in_other_widget?" do
      it "detects simple values that are already handled in other widgets" do
        expect(subject.send(:handled_in_other_widget?, "auto")).to be true
        expect(subject.send(:handled_in_other_widget?, "ro")).to be true
        expect(subject.send(:handled_in_other_widget?, "nouser")).to be true
      end

      it "detects regexps that are already handled in other widgets" do
        expect(subject.send(:handled_in_other_widget?, "iocharset=none")).to be true
        expect(subject.send(:handled_in_other_widget?, "codepage=42")).to be true
      end

      it "detects values that are not already handled in other widgets" do
        expect(subject.send(:handled_in_other_widget?, "foo")).to be false
        expect(subject.send(:handled_in_other_widget?, "bar")).to be false
        expect(subject.send(:handled_in_other_widget?, "ook=yikes")).to be false
        expect(subject.send(:handled_in_other_widget?, "somecodepage=42")).to be false
      end
    end

    describe "#unhandled_options" do
      it "filters out values that are handled in other widgets" do
        expect(subject.send(:unhandled_options, [])).to eq []
        expect(subject.send(:unhandled_options, handled_values)).to eq []
        expect(subject.send(:unhandled_options, handled_values + ["foo", "bar"])).to eq ["foo", "bar"]
        expect(subject.send(:unhandled_options, ["foo", "bar"])).to eq ["foo", "bar"]
      end
    end

    describe "#clean_whitespace" do
      it "does not modify strings without any whitespace" do
        expect(subject.send(:clean_whitespace, "aaa,bbb,ccc")).to eq "aaa,bbb,ccc"
      end

      it "removes whitespace around commas" do
        expect(subject.send(:clean_whitespace, "aaa, bbb , ccc")).to eq "aaa,bbb,ccc"
      end

      it "leaves internal whitespace alone" do
        expect(subject.send(:clean_whitespace, "aa a, bb  b , ccc")).to eq "aa a,bb  b,ccc"
      end
    end
  end

  describe Y2Partitioner::Widgets::FilesystemsOptions do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::SwapPriority do
    include_examples "InputField"
  end

  describe Y2Partitioner::Widgets::IOCharset do
    include_examples "CWM::ComboBox"
    include_examples "CWM::AbstractWidget#init#store"
  end

  describe Y2Partitioner::Widgets::Codepage do
    include_examples "CWM::ComboBox"
    include_examples "CWM::AbstractWidget#init#store"
  end
end
