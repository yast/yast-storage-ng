#!/usr/bin/env rspec

# Copyright (c) [2021] SUSE LLC
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

require "y2storage/dialogs/issue"

describe Y2Storage::Dialogs::Issue do
  subject { described_class.new(issue, options) }

  let(:issue) { Y2Storage::Issue.new("Issue 1", description: description, details: details) }

  let(:description) { nil }

  let(:details) { nil }

  let(:options) { { timeout: 10 } }

  before do
    allow(Yast2::Popup).to receive(:show)
  end

  describe ".show" do
    it "creates a dialog with the given issue and options" do
      expect(described_class).to receive(:new).with(issue, options).and_call_original

      described_class.show(issue, options)
    end

    it "shows a popup" do
      expect(Yast2::Popup).to receive(:show)

      described_class.show(issue, options)
    end
  end

  describe "#show" do
    it "shows a popup" do
      expect(Yast2::Popup).to receive(:show)

      subject.show
    end

    it "includes the message of the issue" do
      expect(Yast2::Popup).to receive(:show).with(/Issue 1/, anything)

      subject.show
    end

    context "if the issue has a description" do
      let(:description) { "Issue description" }

      it "includes the description of the issue" do
        expect(Yast2::Popup).to receive(:show).with(/Issue description/, anything)

        subject.show
      end
    end

    context "if the issue does not have a description" do
      let(:description) { nil }

      it "includes a generic description" do
        expect(Yast2::Popup).to receive(:show).with(/Unexpected situation/, anything)

        subject.show
      end
    end

    context "if the issue has details" do
      let(:details) { "Issue details" }

      it "includes a hint for the details" do
        expect(Yast2::Popup).to receive(:show).with(/Click below/, anything)

        subject.show
      end

      it "shows a popup with the details" do
        expect(Yast2::Popup).to receive(:show) do |_, options|
          expect(options[:details]).to include("Issue details")
        end

        subject.show
      end

      # see https://bugzilla.suse.com/show_bug.cgi?id=1085468
      context "and the details are too long" do
        let(:max_length) { 80 }

        let(:details) do
          "command '/usr/sbin/parted --script '/dev/sda' mklabel gpt' failed:\n\n\n" \
          "stderr:\n"\
          "Error: Partition(s) 1 on /dev/sda have been written, but we have been unable to inform the " \
          "kernel of the change, probably because it/they are in use.  As a result, the old " \
          "partition(s) will remain in use.  You should reboot now before making further changes.\n\n" \
          "exit code:\n" \
          "1"
        end

        it "wraps the details" do
          expect(Yast2::Popup).to receive(:show) do |_, options|
            max_line = options[:details].lines.max_by(&:size)
            expect(max_line.size < max_length).to eq(true), "Line '#{max_line}' is too long"
          end

          subject.show
        end
      end

      context "if the issue has no details" do
        let(:details) { nil }

        it "does not include a hint for the details" do
          expect(Yast2::Popup).to receive(:show) do |text, _|
            expect(text).to_not include("Click below")
          end

          subject.show
        end

        it "shows a popup without the details" do
          expect(Yast2::Popup).to receive(:show) do |_, options|
            expect(options[:details]).to eq("")
          end

          subject.show
        end
      end

      context "if a footer is given" do
        let(:options) { { footer: "Issue footer" } }

        it "includes the footer" do
          expect(Yast2::Popup).to receive(:show).with(/Issue footer/, anything)

          subject.show
        end
      end

      context "if a headline is given" do
        let(:options) { { headline: "Issue headline" } }

        it "does not include the headline" do
          expect(Yast2::Popup).to receive(:show) do |text, _|
            expect(text).to_not include("Issue headline")
          end

          subject.show
        end
      end
    end
  end
end
