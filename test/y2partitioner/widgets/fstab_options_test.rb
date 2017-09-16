require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/fstab_options"

RSpec.shared_examples "CWM::AbstractWidget#init#store" do
  describe "#init" do
    it "does not crash" do
      next unless subject.respond_to?(:init)
      expect { subject.init }.to_not raise_error
    end
  end

  describe "#store" do
    it "does not crash" do
      next unless subject.respond_to?(:store)
      expect { subject.store }.to_not raise_error
    end
  end
end

RSpec.shared_examples "CWM::InputField" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ValueBasedWidget"
  include_examples "CWM::AbstractWidget#init#store"
end

RSpec.shared_examples "CWM::CheckBox" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ValueBasedWidget"
  include_examples "CWM::AbstractWidget#init#store"
end

RSpec.shared_examples "FstabCheckBox" do
  include_examples "CWM::CheckBox"
end

describe Y2Partitioner::Widgets do
  let(:controller) { double("FilesystemController", filesystem: filesystem) }
  let(:fs_type) { double("Type", supported_fstab_options: [], to_sym: :type) }
  let(:filesystem) do
    double("BlkFilesystem", fstab_options: [], type: fs_type, label: nil, mount_by: nil)
  end

  before do
    allow(filesystem).to receive(:fstab_options=)
    allow(filesystem).to receive(:label=)
    allow(filesystem).to receive(:mount_by=)
  end

  subject { described_class.new(controller) }

  describe Y2Partitioner::Widgets::FstabOptions do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::VolumeLabel do
    include_examples "CWM::InputField"
  end

  describe Y2Partitioner::Widgets::MountBy do
    include_examples "CWM::CustomWidget"
    include_examples "CWM::AbstractWidget#init#store"
  end

  describe Y2Partitioner::Widgets::GeneralOptions do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::Noauto do
    include_examples "FstabCheckBox"
  end

  describe Y2Partitioner::Widgets::ReadOnly do
    include_examples "FstabCheckBox"
  end

  describe Y2Partitioner::Widgets::Noatime do
    include_examples "FstabCheckBox"
  end

  describe Y2Partitioner::Widgets::MountUser do
    include_examples "FstabCheckBox"
  end

  describe Y2Partitioner::Widgets::Quota do
    include_examples "CWM::CheckBox"
  end

  describe Y2Partitioner::Widgets::JournalOptions do
    include_examples "CWM::ComboBox"
    include_examples "CWM::AbstractWidget#init#store"
  end

  describe Y2Partitioner::Widgets::AclOptions do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::ArbitraryOptions do
    include_examples "CWM::InputField"
  end

  describe Y2Partitioner::Widgets::FilesystemsOptions do
    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::SwapPriority do
    include_examples "CWM::InputField"
  end

  describe Y2Partitioner::Widgets::IOCharset do
    include_examples "CWM::ComboBox"
    include_examples "CWM::AbstractWidget#init#store"
  end

  describe Y2Partitioner::Widgets::Codepage do
    include_examples "CWM::ComboBox"
    include_examples "CWM::AbstractWidget#init#store"
  end
end
