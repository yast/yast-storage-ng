require_relative "spec_helper"
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts
  let(:architecture) { :x86 }

  include_context "proposal"

  describe "#propose" do
    subject(:proposal) { described_class.new(settings: settings) }

    context "when in the same scenario than bsc#1078691" do
      let(:scenario) { "bug_1078691.xml" }
      let(:settings_format) { :ng }
      let(:control_file) { "bug_1078691.xml" }
      let(:windows_partitions) { {} }

      it "includes a partition for '/'" do
        settings.candidate_devices = ["/dev/sda"]
        proposal.propose
        filesystems = proposal.devices.filesystems
        expect(filesystems.map { |x| x.mount_point && x.mount_point.path }).to include "/"
      end
    end
  end
end
