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
  let(:luks2) { Y2Storage::EncryptionMethod.find(:luks2) }
  let(:pervasive) { Y2Storage::EncryptionMethod.find(:pervasive_luks2) }

  before do
    devicegraph_stub("empty_hard_disk_50GiB.yml")
  end

  include_examples "CWM::CustomWidget"

  describe "#refresh" do
    let(:fake_random_swap_options) { CWM::Empty.new("__fake_plain_options__") }
    let(:fake_luks1_options) { CWM::Empty.new("__fake_luks1_options__") }
    let(:fake_luks2_options) { CWM::Empty.new("__fake_luks2_options__") }
    let(:fake_pervasive_options) { CWM::Empty.new("__fake_pervasive_options__") }

    before do
      allow(Y2Partitioner::Widgets::SwapOptions).to receive(:new).and_return(fake_random_swap_options)
      allow(Y2Partitioner::Widgets::LuksOptions).to receive(:new).and_return(fake_luks1_options)
      allow(Y2Partitioner::Widgets::Luks2Options).to receive(:new).and_return(fake_luks2_options)
      allow(Y2Partitioner::Widgets::PervasiveOptions).to receive(:new).and_return(fake_pervasive_options)
    end

    it "generates the new content based on the selected method" do
      expect(Y2Partitioner::Widgets::SwapOptions).to receive(:new)
      subject.refresh(random_swap)

      expect(Y2Partitioner::Widgets::LuksOptions).to receive(:new)
      subject.refresh(luks1)

      expect(Y2Partitioner::Widgets::PervasiveOptions).to receive(:new)
      subject.refresh(pervasive)

      expect(Y2Partitioner::Widgets::Luks2Options).to receive(:new)
      subject.refresh(luks2)
    end

    it "replaces the content using the new generated content" do
      expect(subject).to receive(:replace).with(fake_random_swap_options)
      subject.refresh(random_swap)

      expect(subject).to receive(:replace).with(fake_luks1_options)
      subject.refresh(luks1)

      expect(subject).to receive(:replace).with(fake_pervasive_options)
      subject.refresh(pervasive)

      expect(subject).to receive(:replace).with(fake_luks2_options)
      subject.refresh(luks2)
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

  describe Y2Partitioner::Widgets::Luks2Options do
    subject { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#contents" do
      it "displays widgets for the password, the PBKDF and the LUKS2 label" do
        passwd = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::EncryptPassword) }
        pbkdf = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::PbkdfSelector) }
        label = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::EncryptLabel) }

        expect([passwd, pbkdf, label]).to_not include nil
      end
    end
  end

  describe Y2Partitioner::Widgets::PervasiveOptions do
    subject { described_class.new(controller) }

    before do
      allow(Yast2::Popup).to receive(:show)
      allow(controller).to receive(:online_apqns).and_return(apqns)
      allow(Y2Partitioner::Widgets::PervasiveKeySelector).to receive(:new).and_return(master_key_widget)
    end

    let(:master_key_widget) do
      instance_double(
        Y2Partitioner::Widgets::PervasiveKeySelector, widget_id: "mkw", value: selected_master_key
      )
    end

    let(:apqns) { [apqn1, apqn2, apqn3, apqn4] }
    let(:apqn1) { apqn_mock("01.0001", "0x123") }
    let(:apqn2) { apqn_mock("01.0002", "0x456") }
    let(:apqn3) { apqn_mock("02.0001", "0x123") }
    let(:apqn4) { apqn_mock("03.0001", "0xabcdefg", ep11: true) }
    let(:selected_master_key) { apqn4.master_key_pattern }

    include_examples "CWM::CustomWidget"

    describe "#contents" do
      it "displays the encryption password widget" do
        widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::EncryptPassword) }

        expect(widget).to_not be_nil
      end

      context "when there are more than one online APQNs" do
        context "and some APQN is already selected" do
          before { controller.apqns = [apqn1] }

          it "displays the APQN selector widget" do
            widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::ApqnSelector) }

            expect(widget).to_not be_nil
          end
        end

        context "and no APQNs has been selected yet" do
          before { controller.apqns = [] }

          it "displays the APQN selector widget" do
            widget = subject.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::ApqnSelector) }

            expect(widget).to_not be_nil
          end
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

    describe "#handle" do
      before do
        allow(Y2Partitioner::Widgets::PervasiveKey).to receive(:new).and_return(full_key_widget)
      end

      let(:full_key_widget) do
        instance_double(Y2Partitioner::Widgets::PervasiveKey)
      end

      it "refreshes all internal widgets if the master key changes" do
        expect(full_key_widget).to receive(:refresh)

        subject.handle({ "ID" => master_key_widget.widget_id })
      end
    end

    describe "#validate" do
      before do
        allow(Y2Partitioner::Widgets::ApqnSelector).to receive(:new).and_return(apqn_widget)
        allow(controller).to receive(:secure_key)
        allow(controller).to receive(:test_secure_key_generation).and_return(generation_test_error)
      end

      let(:apqn_widget) { instance_double(Y2Partitioner::Widgets::ApqnSelector, value: selected_apqns) }
      let(:selected_apqns) { [apqn4] }
      let(:selected_master_key) { apqn4.master_key_pattern }

      context "and the secure key cannot be generated" do
        let(:generation_test_error) { "error" }

        it "returns false" do
          expect(subject.validate).to eq(false)
        end

        it "shows an specific error" do
          expect(Yast2::Popup).to receive(:show)
            .with(/secure key cannot be generated/, headline: :error, details: "error")

          subject.validate
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
