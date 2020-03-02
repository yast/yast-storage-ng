#!/usr/bin/env rspec

# Copyright (c) [2019-2020] SUSE LLC
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
require "y2partitioner/widgets/encrypt_method_options"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/encryption"

describe Y2Partitioner::Widgets::EncryptMethodOptions do
  subject { described_class.new(controller) }

  let(:fs_controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(device, "The title") }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:dev_name) { "/dev/sda" }

  let(:controller) { Y2Partitioner::Actions::Controllers::Encryption.new(fs_controller) }
  let(:random_swap) { Y2Storage::EncryptionMethod.find(:random_swap) }
  let(:luks1) { Y2Storage::EncryptionMethod.find(:luks1) }
  let(:pervasive) { Y2Storage::EncryptionMethod.find(:pervasive_luks2) }

  before do
    devicegraph_stub("empty_hard_disk_50GiB.yml")
  end

  include_examples "CWM::CustomWidget"

  describe "#refresh" do
    let(:fake_random_swap_options) { CWM::Empty.new("__fake_plain_options__") }
    let(:fake_luks1_options) { CWM::Empty.new("__fake_luks1_options__") }
    let(:fake_pervasive_options) { CWM::Empty.new("__fake_pervasive_options__") }

    before do
      allow(Y2Partitioner::Widgets::SwapOptions).to receive(:new).and_return(fake_random_swap_options)
      allow(Y2Partitioner::Widgets::LuksOptions).to receive(:new).and_return(fake_luks1_options)
      allow(Y2Partitioner::Widgets::PervasiveOptions).to receive(:new).and_return(fake_pervasive_options)
    end

    it "generates the new content based on the selected method" do
      expect(Y2Partitioner::Widgets::SwapOptions).to receive(:new)
      subject.refresh(random_swap)

      expect(Y2Partitioner::Widgets::LuksOptions).to receive(:new)
      subject.refresh(luks1)

      expect(Y2Partitioner::Widgets::PervasiveOptions).to receive(:new)
      subject.refresh(pervasive)
    end

    it "replaces the content using the new generated content" do
      expect(subject).to receive(:replace).with(fake_random_swap_options)
      subject.refresh(random_swap)

      expect(subject).to receive(:replace).with(fake_luks1_options)
      subject.refresh(luks1)

      expect(subject).to receive(:replace).with(fake_pervasive_options)
      subject.refresh(pervasive)
    end
  end

  describe Y2Partitioner::Widgets::SwapOptions do
    subject { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#contents" do
      it "displays a warning message" do
        texts = subject.contents.nested_find { |el| el.is_a?(Yast::Term) && el.value == :Label }.to_a

        expect(texts).to include(/careful/)
      end
    end
  end

  describe Y2Partitioner::Widgets::LuksOptions do
    subject { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#contents" do
      it "displays the encryption password widget" do
        widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::EncryptPassword) }

        expect(widget).to_not be_nil
      end
    end
  end

  describe Y2Partitioner::Widgets::PervasiveOptions do
    subject { described_class.new(controller) }

    before do
      allow(Yast2::Popup).to receive(:show)
    end

    include_examples "CWM::CustomWidget"

    describe "#contents" do
      before do
        allow(controller).to receive(:online_apqns).and_return(apqns)
      end

      let(:apqns) { [] }

      let(:apqn1) { instance_double(Y2Storage::EncryptionProcesses::Apqn, name: "01.0001") }

      let(:apqn2) { instance_double(Y2Storage::EncryptionProcesses::Apqn, name: "01.0002") }

      it "displays the encryption password widget" do
        widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::EncryptPassword) }

        expect(widget).to_not be_nil
      end

      context "when there are more than one online APQNs" do
        let(:apqns) { [apqn1, apqn2] }

        it "displays the APQN selector widget" do
          widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::ApqnSelector) }

          expect(widget).to_not be_nil
        end
      end

      context "when there is only one online APQN" do
        let(:apqns) { [apqn1] }

        it "does not display the APQN selector widget" do
          widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::ApqnSelector) }

          expect(widget).to be_nil
        end
      end
    end

    describe "#validate" do
      before do
        allow(Y2Partitioner::Widgets::ApqnSelector).to receive(:new).and_return(apqn_widget)

        allow(controller).to receive(:online_apqns).and_return(apqns)

        allow(controller).to receive(:test_secure_key_generation).and_return(generation_test_error)
      end

      let(:apqn_widget) { instance_double(Y2Partitioner::Widgets::ApqnSelector, value: selected_apqns) }

      let(:apqns) { [apqn1, apqn2] }

      let(:selected_apqns) { [apqn1, apqn2] }

      let(:apqn1) { instance_double(Y2Storage::EncryptionProcesses::Apqn, name: "01.0001") }

      let(:apqn2) { instance_double(Y2Storage::EncryptionProcesses::Apqn, name: "01.0002") }

      context "and the secure key cannot be generated" do
        let(:generation_test_error) { "error" }

        it "returns false" do
          expect(subject.validate).to eq(false)
        end

        context "when there are more than one selected APQNs" do
          let(:selected_apqns) { [apqn1, apqn2] }

          it "shows an specific error" do
            expect(Yast2::Popup).to receive(:show)
              .with(/all selected APQNs are configured/, headline: :error, details: "error")

            subject.validate
          end
        end

        context "when there is only one selected APQN" do
          let(:selected_apqns) { [apqn1] }

          it "shows an specific error" do
            expect(Yast2::Popup).to receive(:show)
              .with(/the selected APQN is configured/, headline: :error, details: "error")

            subject.validate
          end
        end

        context "when there is no selected APQN" do
          let(:selected_apqns) { [] }

          it "shows an specific error" do
            expect(Yast2::Popup).to receive(:show)
              .with(/all available APQNs are configured/, headline: :error, details: "error")

            subject.validate
          end
        end
      end

      context "and the secure key can be generated" do
        let(:generation_test_error) { nil }

        it "does not show an error" do
          expect(Yast2::Popup).to_not receive(:show)

          subject.validate
        end

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end
    end
  end
end
