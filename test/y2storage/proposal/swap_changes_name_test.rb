require_relative "../spec_helper"
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

    # regession test for bsc#1078691:
    #   - root and swap are both logical partitions
    #   - root is before swap
    #   - swap can be reused (is big enough)
    #   - the old root will be deleted and the space reused (so swap
    #     changes its name in between)
    context "when swap is reused but changes its device name" do
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
