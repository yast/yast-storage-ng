#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/encrypt"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/encryption"

describe Y2Partitioner::Widgets::Encrypt do
  subject { described_class.new(controller) }

  let(:fs_controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(device, "The title") }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:dev_name) { "/dev/sda" }

  let(:controller) { Y2Partitioner::Actions::Controllers::Encryption.new(fs_controller) }
  let(:random_password) { Y2Storage::EncryptionMethod::RANDOM_SWAP }
  let(:luks1) { Y2Storage::EncryptionMethod::LUKS1 }
  let(:methods) { [luks1] }

  let(:encrypt_method) { "ENCRYPT METHOD SELECTOR" }
  let(:encrypt_method_options) { double(Y2Partitioner::Widgets::EncryptMethodOptions) }

  before do
    devicegraph_stub("empty_hard_disk_50GiB.yml")

    allow(Y2Partitioner::Widgets::EncryptMethodOptions).to receive(:new)
      .and_return(encrypt_method_options)
    allow(Y2Partitioner::Widgets::EncryptMethod).to receive(:new)
      .and_return(encrypt_method)

    allow(controller).to receive(:methods).and_return(methods)
  end

  describe "#init" do
    it "refreshes the encrypt method options widget" do
      expect(encrypt_method_options).to receive(:refresh)

      subject.init
    end
  end

  describe "#handle" do
    let(:event) { { "ID" => widget_id } }
    let(:encrypt_method) do
      double(Y2Partitioner::Widgets::EncryptMethod, widget_id: :encrypt_method_id, value: luks1.to_sym)
    end

    context "when triggered by an encrypt method selector event" do
      let(:widget_id) { :encrypt_method_id }

      it "refreshes the encrypt method options widget" do
        expect(encrypt_method_options).to receive(:refresh)

        subject.handle(event)
      end
    end

    context "when not triggered by an encrypt method selector event" do
      let(:widget_id) { :not_encrypt_method_id }

      it "does not refresh the encrypt method options widget" do
        expect(encrypt_method_options).to_not receive(:refresh)

        subject.handle(event)
      end
    end
  end

  describe "#contents" do
    let(:encrypt_method_term) do
      subject.contents.nested_find { |e| e.is_a?(Yast::Term) && e.params.include?(encrypt_method) }
    end

    context "when there is only one encryption method" do
      let(:methods) { [luks1] }

      it "does not include the encryption method selector" do
        expect(encrypt_method_term).to be_nil
      end
    end

    context "when there are more than one encryption method" do
      let(:methods) { [luks1, random_password] }

      it "includes the encryption method selector" do
        expect(encrypt_method_term).to_not be_nil
      end
    end
  end

  describe "#help" do
    before do
      allow(controller).to receive(:several_encrypt_methods?).and_return(several_encrypt_methods)

      allow(controller).to receive(:methods).and_return(encrypt_methods)
    end

    let(:several_encrypt_methods) { false }

    let(:encrypt_methods) { [] }

    context "when there is only one encryption method" do
      let(:several_encrypt_methods) { false }

      it "states that the method will be applied" do
        expect(subject.help).to match(/will be used/)
      end
    end

    context "when there are available several encryption methods" do
      let(:several_encrypt_methods) { true }

      it "includes an introduction to the available methods" do
        expect(subject.help).to match(/can be chosen/)
      end
    end

    context "when :luks1 encryption method is availabale" do
      let(:encrypt_methods) { [luks1] }

      let(:luks1) { Y2Storage::EncryptionMethod.find(:luks1) }

      it "includes help for :luks1 encryption method" do
        expect(subject.help).to include(luks1.to_human_string)
      end
    end

    context "when :pervasive_luks2 encryption method is availabale" do
      let(:encrypt_methods) { [pervasive_luks2] }

      let(:pervasive_luks2) { Y2Storage::EncryptionMethod.find(:pervasive_luks2) }

      it "includes help for :pervasive_luks2 encryption method" do
        expect(subject.help).to include(pervasive_luks2.to_human_string)
      end
    end

    context "when :random_swap encryption method is availabale" do
      let(:encrypt_methods) { [random_swap] }

      let(:random_swap) { Y2Storage::EncryptionMethod.find(:random_swap) }

      it "includes help for :random_swap encryption method" do
        expect(subject.help).to include(random_swap.to_human_string)
      end
    end

    context "when :protected_swap encryption method is availabale" do
      let(:encrypt_methods) { [protected_swap] }

      let(:protected_swap) { Y2Storage::EncryptionMethod.find(:protected_swap) }

      it "includes help for :protected_swap encryption method" do
        expect(subject.help).to include(protected_swap.to_human_string)
      end
    end

    context "when :secure_swap encryption method is availabale" do
      let(:encrypt_methods) { [secure_swap] }

      let(:secure_swap) { Y2Storage::EncryptionMethod.find(:secure_swap) }

      it "includes help for :secure_swap encryption method" do
        expect(subject.help).to include(secure_swap.to_human_string)
      end
    end
  end
end
