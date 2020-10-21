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

    context "without LIBSTORAGE_IGNORE_PROBE_ERRORS" do
      before { mock_env(env_vars) }
      let(:env_vars) { {} }
      it "it displays an error pop-up" do
        expect(Yast::Report).to receive(:yesno_popup)
        subject.error("probing failed", "")
      end
    end

    context "with LIBSTORAGE_IGNORE_PROBE_ERRORS set" do
      before { mock_env(env_vars) }
      after { mock_env({}) } # clean up for future tests
      let(:env_vars) { { "LIBSTORAGE_IGNORE_PROBE_ERRORS" => "1" } }
      it "does not display an error pop-up and returns true" do
        expect(Yast::Report).not_to receive(:yesno_popup)
        expect(subject.error("probing failed", "")).to be true
      end
    end
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
    before do
      allow(Yast::Mode).to receive(:normal).and_return normal_mode
    end

    let(:msg) { "the message" }
    let(:what) { "the what" }
    let(:cmd) { "the command" }

    RSpec.shared_examples "generic error" do
      it "just displays the error and the details" do
        expect(Yast::Report).to receive(:yesno_popup) do |message, options|
          expect(message).to include msg
          expect(options[:details]).to eq what
        end
        subject.missing_command(msg, what, cmd, features)
      end
    end

    context "during (auto)installation" do
      let(:normal_mode) { false }

      context "if features is 0" do
        let(:features) { 0 }

        include_examples "generic error"
      end

      context "if features is not 0" do
        let(:features) { Storage::UF_BTRFS }

        include_examples "generic error"
      end
    end

    context "during normal execution" do
      let(:normal_mode) { true }

      context "if features is 0" do
        let(:features) { 0 }

        include_examples "generic error"
      end

      context "if features is not 0" do
        let(:features) { Storage::UF_BTRFS }

        it "displays a pop-up with the list of packages to install" do
          expect(Yast2::Popup).to receive(:show) do |message, options|
            expect(message).to include "btrfsprogs, e2fsprogs"
            expect(options[:buttons].keys).to contain_exactly(:ignore, :install)
            :ignore
          end

          subject.missing_command(msg, what, cmd, features)
        end

        context "if the user clicks on :install" do
          before do
            allow(Yast2::Popup).to receive(:show).and_return :install
            allow(Y2Storage::PackageHandler).to receive(:new).and_return pkg_handler
          end

          let(:pkg_handler) { double("PackageHandler", commit: true) }

          it "returns false" do
            expect(subject.missing_command(msg, what, cmd, features)).to eq false
          end

          it "installs the packages" do
            expect(Y2Storage::PackageHandler).to receive(:new).with(["btrfsprogs", "e2fsprogs"])
            expect(pkg_handler).to receive(:commit)

            subject.missing_command(msg, what, cmd, features)
          end

          it "sets #again? to true" do
            subject.begin
            expect(subject.again?).to eq false

            subject.missing_command(msg, what, cmd, features)
            expect(subject.again?).to eq true
          end
        end

        context "if the user clicks on :ignore" do
          before { allow(Yast2::Popup).to receive(:show).and_return :ignore }

          it "returns true" do
            expect(subject.missing_command(msg, what, cmd, features)).to eq true
          end

          it "does not install the packages" do
            expect(Y2Storage::PackageHandler).to_not receive(:new)
            subject.missing_command(msg, what, cmd, features)
          end

          it "does not set #again?" do
            subject.begin
            expect(subject.again?).to eq false

            subject.missing_command(msg, what, cmd, features)
            expect(subject.again?).to eq false
          end
        end
      end
    end
  end
end
