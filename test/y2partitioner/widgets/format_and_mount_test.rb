require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/format_and_mount"

describe Y2Partitioner::Widgets::FormatOptions do
  let(:controller) { double("FilesystemController", filesystem: nil) }
  let(:parent) { double("FormatMountOptions") }
  subject { described_class.new(controller, parent) }

  include_examples "CWM::CustomWidget"
end

describe Y2Partitioner::Widgets::MountOptions do
  let(:controller) { double("FilesystemController", filesystem: nil) }
  let(:parent) { double("FormatMountOptions") }
  subject { described_class.new(controller, parent) }

  include_examples "CWM::CustomWidget"
end

describe Y2Partitioner::Widgets::FstabOptionsButton do
  let(:controller) { double("FilesystemController", filesystem: nil) }

  before do
    allow(Y2Partitioner::Dialogs::FstabOptions)
      .to receive(:new).and_return(double(run: :next))
  end

  subject { described_class.new(controller) }

  include_examples "CWM::PushButton"
end

describe Y2Partitioner::Widgets::BlkDeviceFilesystem do
  let(:controller) { double("FilesystemController", filesystem: nil) }
  subject { described_class.new(controller) }

  include_examples "CWM::AbstractWidget"
end

describe Y2Partitioner::Widgets::MountPoint do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:controller) { double("FilesystemController", filesystem: nil) }

  subject { described_class.new(controller) }

  include_examples "CWM::AbstractWidget"

  describe "#validate" do

    before do
      allow(subject).to receive(:enabled?).and_return(enabled)
      allow(subject).to receive(:value).and_return(value)
    end

    let(:value) { nil }

    context "when the widget is not enabled" do
      let(:enabled) { false }

      it "returns true" do
        expect(subject.validate).to be(true)
      end
    end

    context "when the widget is enabled" do
      let(:enabled) { true }

      context "and the mount point is not indicated" do
        let(:value) { "" }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to be(false)
        end
      end

      context "and the mount point already exists" do
        let(:value) { "/home" }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to be(false)
        end
      end

      context "and the mount point does not exist" do
        context "and the mount point does not shadow any subvolume" do
          let(:value) { "/foo" }

          it "returns true" do
            expect(subject.validate).to be(true)
          end
        end

        context "and the mount point shadows a subvolume" do
          let(:value) { "/foo" }

          before do
            device_graph = Y2Partitioner::DeviceGraphs.instance.current
            device = Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/sda2")
            filesystem = device.filesystem
            subvolume = filesystem.create_btrfs_subvolume("@/foo", false)
            subvolume.can_be_auto_deleted = can_be_auto_deleted
          end

          context "and the subvolume cannot be shadowed" do
            let(:can_be_auto_deleted) { false }

            it "shows an error message" do
              expect(Yast::Popup).to receive(:Error)
              subject.validate
            end

            it "returns false" do
              expect(subject.validate).to be(false)
            end
          end

          context "and the subvolume can be shadowed" do
            let(:can_be_auto_deleted) { true }

            it "returns true" do
              expect(subject.validate).to be(true)
            end
          end
        end
      end
    end
  end
end

describe Y2Partitioner::Widgets::InodeSize do
  let(:format_options) do
    double("Format Options")
  end

  subject { described_class.new(format_options) }

  include_examples "CWM::AbstractWidget"
end

describe Y2Partitioner::Widgets::BlockSize do
  let(:controller) { double("FilesystemController", filesystem: nil) }
  subject { described_class.new(controller) }

  include_examples "CWM::AbstractWidget"
end

describe Y2Partitioner::Widgets::PartitionId do
  let(:controller) { double("FilesystemController", filesystem: nil) }
  subject { described_class.new(controller) }

  include_examples "CWM::AbstractWidget"
end
