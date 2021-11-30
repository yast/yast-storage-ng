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
require "y2storage/issues_reporter"

describe Y2Storage::IssuesReporter do
  subject { described_class.new(issues) }

  describe "#report" do
    before do
      allow(Y2Storage::Dialogs::Issues).to receive(:show)
    end

    shared_examples "buttons" do |dialog|
      context "during installation" do
        before do
          allow(Yast::Mode).to receive(:installation).and_return(true)
        end

        it "includes Continue and Abort Installation buttons" do
          expect(dialog).to receive(:show) do |_, options|
            expect(options[:buttons][:yes]).to eq(Yast::Label.ContinueButton)
            expect(options[:buttons][:no]).to eq(Yast::Label.AbortInstallationButton)
          end

          subject.report
        end
      end

      context "in a running system" do
        before do
          allow(Yast::Mode).to receive(:installation).and_return(false)
        end

        it "includes Continue and Abort buttons" do
          expect(dialog).to receive(:show) do |_, options|
            expect(options[:buttons][:yes]).to eq(Yast::Label.ContinueButton)
            expect(options[:buttons][:no]).to eq(Yast::Label.AbortButton)
          end

          subject.report
        end
      end
    end

    shared_examples "focus" do |dialog|
      it "sets the focus when a focus button is given" do
        expect(dialog).to receive(:show) do |_, options|
          expect(options[:focus]).to eq(:yes)
        end

        subject.report(focus: :yes)
      end

      it "does not set the focus when a focus button is not given" do
        expect(dialog).to receive(:show) do |_, options|
          expect(options[:focus]).to be_nil
        end

        subject.report
      end
    end

    context "when there is only an issue" do
      let(:issues) { Y2Issues::List.new([Y2Storage::Issue.new("Issue 1")]) }

      it "shows a dialog for a single issue" do
        expect(Y2Storage::Dialogs::Issue).to receive(:show).with(issues.first, anything)

        subject.report
      end

      it "includes the footer for a single error" do
        expect(Y2Storage::Dialogs::Issue).to receive(:show) do |_, options|
          expect(options[:footer]).to match(/despite the error\?/)
        end

        subject.report
      end

      include_examples "buttons", Y2Storage::Dialogs::Issue

      include_examples "focus", Y2Storage::Dialogs::Issue
    end

    context "when there are several issues" do
      let(:issues) do
        Y2Issues::List.new(
          [
            Y2Storage::Issue.new("Issue 1"),
            Y2Storage::Issue.new("Issue 2")
          ]
        )
      end

      it "shows a dialog for multiple issues" do
        expect(Y2Storage::Dialogs::Issues).to receive(:show).with(issues, anything)

        subject.report
      end

      it "includes the given message" do
        expect(Y2Storage::Dialogs::Issues).to receive(:show) do |_, options|
          expect(options[:message]).to eq("List of issues")
        end

        subject.report(message: "List of issues")
      end

      it "includes the footer for several errors" do
        expect(Y2Storage::Dialogs::Issues).to receive(:show) do |_, options|
          expect(options[:footer]).to match(/despite the errors\?/)
        end

        subject.report
      end

      include_examples "buttons", Y2Storage::Dialogs::Issues

      include_examples "focus", Y2Storage::Dialogs::Issues
    end
  end
end
