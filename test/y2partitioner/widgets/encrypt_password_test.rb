#!/usr/bin/env rspec

#
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
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "cwm/rspec"
require "y2partitioner/widgets/encrypt_password"

describe Y2Partitioner::Widgets::EncryptPassword do
  subject(:widget) { described_class.new(controller) }

  include_examples "CWM::AbstractWidget"

  let(:controller) { double("FilesystemController", blk_device_name: "/dev/sda1") }
  let(:pw1) { "password1" }
  let(:pw2) { "password2" }
  let(:password_checker) { Y2Storage::EncryptPasswordChecker.new }

  before do
    allow(Y2Storage::EncryptPasswordChecker).to receive(:new).and_return(password_checker)
    allow(Yast::UI).to receive(:QueryWidget).with(Id(:pw1), :Value).and_return(pw1)
    allow(Yast::UI).to receive(:QueryWidget).with(Id(:pw2), :Value).and_return(pw2)
  end

  describe "#contents" do
    it "includes two password fields" do
      contents = widget.contents
      pw1 = contents.nested_find { |i| i.is_a?(Yast::Term) && i.params == [:pw1] }
      expect(pw1).to_not be_nil
      pw2 = contents.nested_find { |i| i.is_a?(Yast::Term) && i.params == [:pw2] }
      expect(pw2).to_not be_nil
    end
  end

  describe "#validate" do
    it "checkes the password" do
      expect(password_checker).to receive(:error_msg).with(pw1, pw2)
      widget.validate
    end

    context "when a good password is chosen" do
      before do
        allow(password_checker).to receive(:error_msg)
          .and_return(nil)
      end

      it "returns true" do
        expect(widget.validate).to eq(true)
      end
    end

    context "when a bad password is chosen" do
      before do
        allow(password_checker).to receive(:error_msg)
          .and_return("some error")
      end

      it "returns false" do
        expect(widget.validate).to eq(false)
      end

      it "displays an error message" do
        expect(Yast::Report).to receive(:Error).with("some error")
        widget.validate
      end
    end
  end

  describe "#help" do
    it "returns a string" do
      expect(widget.help).to be_a(String)
    end
  end

  describe "#store" do
    it "assigns password to the controller" do
      expect(controller).to receive(:encrypt_password=).with(pw1)
      widget.store
    end
  end

  describe "#cleanup" do
    it "cleans up the password checker" do
      expect(password_checker).to receive(:tear_down)
      widget.cleanup
    end
  end
end
