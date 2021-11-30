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
require "y2storage/issues_manager"

describe Y2Storage::IssuesManager do
  subject { described_class.new(devicegraph) }

  let(:devicegraph) { devicegraph_from(scenario) }

  let(:scenario) { "mixed_disks" }

  describe "#probing_issues" do
    it "returns a list of Y2Issues" do
      expect(subject.probing_issues).to be_a(Y2Issues::List)
    end
  end

  describe "#report_probing_issues" do
    before do
      subject.probing_issues = probing_issues
    end

    context "when there are no probing issues" do
      let(:probing_issues) { Y2Issues::List.new }

      it "does not report issues" do
        expect_any_instance_of(Y2Storage::IssuesReporter).to_not receive(:report)

        subject.report_probing_issues
      end

      it "returns true" do
        expect(subject.report_probing_issues).to eq(true)
      end
    end

    context "when there are probing issues" do
      let(:probing_issues) { Y2Issues::List.new([Y2Storage::Issue.new("Issue 1")]) }

      before do
        allow_any_instance_of(Y2Storage::StorageEnv)
          .to receive(:ignore_probe_errors?).and_return(ignore_errors)
      end

      context "and the probing issues should be ignored" do
        let(:ignore_errors) { true }

        it "does not report issues" do
          expect_any_instance_of(Y2Storage::IssuesReporter).to_not receive(:report)

          subject.report_probing_issues
        end

        it "returns true" do
          expect(subject.report_probing_issues).to eq(true)
        end
      end

      context "and the probing issues should not be ignored" do
        let(:ignore_errors) { false }

        before do
          allow(Y2Storage::IssuesReporter).to receive(:new).with(subject.probing_issues)
            .and_return(reporter)

          allow(reporter).to receive(:report).and_return(acepted)
        end

        let(:reporter) { Y2Storage::IssuesReporter.new(subject.probing_issues) }

        let(:acepted) { true }

        it "reports the issues" do
          expect(reporter).to receive(:report) do |args|
            expect(args[:message]).to include("errors were found")
          end

          subject.report_probing_issues
        end

        context "and the report is acepted" do
          let(:acepted) { true }

          it "returns true" do
            expect(subject.report_probing_issues).to eq(true)
          end
        end

        context "and the report is rejected" do
          let(:acepted) { false }

          it "returns false" do
            expect(subject.report_probing_issues).to eq(false)
          end
        end
      end
    end
  end
end
