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
    allow(filesystem.type).to receive(:codepage).and_return("437")
    allow(filesystem.type).to receive(:iocharset).and_return("utf8")
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
    let(:handled_values)  { ["ro", "rw", "auto", "noauto", "user", "nouser"] }
    let(:handled_regexps) { [/^iocharset=/, /^codepage=/] }
    let(:options_widget)  { double("FstabOptions", values:  handled_values, regexps: handled_regexps) }

    subject { described_class.new(controller, options_widget) }
    include_examples "CWM::InputField"

    it "picks up values handled in other widgets" do
      expect(subject.send(:other_values)).to eq handled_values
    end

    it "picks up regexps handled in other widgets" do
      expect(subject.send(:other_regexps)).to eq handled_regexps
    end

    describe "#handled_in_other_widget?" do
      it "detects simple values that are already handled in other widgets" do
        expect(subject.send(:handled_in_other_widget?, "auto")).to be true
        expect(subject.send(:handled_in_other_widget?, "ro")).to be true
        expect(subject.send(:handled_in_other_widget?, "nouser")).to be true
      end

      it "detects regexps that are already handled in other widgets" do
        expect(subject.send(:handled_in_other_widget?, "iocharset=none")).to be true
        expect(subject.send(:handled_in_other_widget?, "codepage=42")).to be true
      end

      it "detects values that are not already handled in other widgets" do
        expect(subject.send(:handled_in_other_widget?, "foo")).to be false
        expect(subject.send(:handled_in_other_widget?, "bar")).to be false
        expect(subject.send(:handled_in_other_widget?, "ook=yikes")).to be false
        expect(subject.send(:handled_in_other_widget?, "somecodepage=42")).to be false
      end
    end

    describe "#unhandled_options" do
      it "filters out values that are handled in other widgets" do
        expect(subject.send(:unhandled_options, [])).to eq []
        expect(subject.send(:unhandled_options, handled_values)).to eq []
        expect(subject.send(:unhandled_options, handled_values + ["foo", "bar"])).to eq ["foo", "bar"]
        expect(subject.send(:unhandled_options, ["foo", "bar"])).to eq ["foo", "bar"]
      end
    end

    describe "#clean_whitespace" do
      it "does not modify strings without any whitespace" do
        expect(subject.send(:clean_whitespace, "aaa,bbb,ccc")).to eq "aaa,bbb,ccc"
      end

      it "removes whitespace around commas" do
        expect(subject.send(:clean_whitespace, "aaa, bbb , ccc")).to eq "aaa,bbb,ccc"
      end

      it "leaves internal whitespace alone" do
        expect(subject.send(:clean_whitespace, "aa a, bb  b , ccc")).to eq "aa a,bb  b,ccc"
      end
    end
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
