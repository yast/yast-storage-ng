#!/usr/bin/env rspec
# Copyright (c) [2017,2020] SUSE LLC
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

require_relative "../spec_helper"
require_relative "callbacks_examples"
require "y2storage/callbacks/probe"

describe Y2Storage::Callbacks::Probe do
  subject(:callbacks) { described_class.new }

  describe "#error" do
    include_examples "general #error examples"
    include_examples "default #error true examples"
  end

  describe "#begin" do
    it "clears again flag" do
      subject.begin
      expect(subject.again?).to be false
    end
  end

  describe "#again?" do
    context "when #begin has been called" do
      before { subject.begin }

      it "returns false" do
        expect(subject.again?).to be false
      end
    end
  end

  describe "#missing_command" do
    it "just displays the error and the details if used_features is 0" do
      expect(Yast::Report).to receive(:yesno_popup) do |message, options|
        expect(message).to include "the message"
        expect(options[:details]).to eq "the what"
      end
      subject.missing_command("the message", "the what", "the command", 0)
    end

    let(:packages) { ["btrfsprogs", "e2fsprogs"] }

    let(:package_handler) do
      double("PackageHandler", add_feature_packages: packages, pkg_list: packages)
    end

    before do
      allow(Yast::Mode).to receive(:installation).and_return false
      allow(Y2Storage::PackageHandler).to receive(:new).and_return package_handler
    end

    it "displays the error and the details including missing packages if used_features is not 0" do
      expect(Yast2::Popup).to receive(:show) do |message, options|
        expect(message).to include "the message"
        expect(options[:details]).to include "the what"
        expect(options[:details]).to include "btrfsprogs, e2fsprogs"
      end
      subject.missing_command("the message", "the what", "the command", 8)
    end
  end

  describe "#missing_command_handle_user_decision" do
    before do
      allow(Y2Storage::PackageHandler).to receive(:new).and_return package_handler
    end

    let(:package_handler) do
      double("PackageHandler")
    end

    context "when user selected install" do
      it "returns false" do
        allow(package_handler).to receive(:commit)
        expect(subject.send(:missing_command_handle_user_decision,
          :install, package_handler)).to be false
      end

      it "sets again flag" do
        allow(package_handler).to receive(:commit)
        subject.send(:missing_command_handle_user_decision, :install, package_handler)
        expect(subject.again?).to be true
      end

      it "installs packages" do
        expect(package_handler).to receive(:commit)
        subject.send(:missing_command_handle_user_decision, :install, package_handler)
      end
    end

    context "when user selected continue" do
      it "returns true" do
        expect(subject.send(:missing_command_handle_user_decision,
          :continue, package_handler)).to be true
      end

      it "clears again flag" do
        subject.send(:missing_command_handle_user_decision, :continue, package_handler)
        expect(subject.again?).to be false
      end
    end

    context "when user selected abort" do
      it "returns false" do
        expect(subject.send(:missing_command_handle_user_decision,
          :abort, package_handler)).to be false
      end

      it "clears again flag" do
        subject.send(:missing_command_handle_user_decision, :abort, package_handler)
        expect(subject.again?).to be false
      end
    end
  end
end
