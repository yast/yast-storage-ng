require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/format_and_mount"

describe Y2Partitioner::Widgets::FormatOptions do
  let(:format_options) do
    double("Format Options", filesystem_type: Y2Storage::Filesystems::Type::XFS,
           format: false, encrypt: false)
  end
  subject { described_class.new(format_options) }

  include_examples "CWM::CustomWidget"
end

describe Y2Partitioner::Widgets::MountOptions do
  let(:format_options) do
    double("Format Options", filesystem_mountpoint: "/foo",
                             filesystem_type:       Y2Storage::Filesystems::Type::XFS)
  end
  subject { described_class.new(format_options) }

  include_examples "CWM::CustomWidget"
end

describe Y2Partitioner::Widgets::FstabOptionsButton do
  let(:format_options) do
    double("Format Options")
  end

  before do
    allow(Y2Partitioner::Dialogs::FstabOptions)
      .to receive(:new).and_return(double(run: :next))
  end

  subject { described_class.new(format_options) }

  include_examples "CWM::PushButton"
end

describe Y2Partitioner::Widgets::BlkDeviceFilesystem do
  let(:format_options) do
    double("Format Options")
  end

  subject { described_class.new(format_options) }

  include_examples "CWM::AbstractWidget"
end

describe Y2Partitioner::Widgets::MountPoint do
  let(:format_options) do
    double("Format Options")
  end

  subject { described_class.new(format_options) }

  include_examples "CWM::AbstractWidget"
end

describe Y2Partitioner::Widgets::InodeSize do
  let(:format_options) do
    double("Format Options")
  end

  subject { described_class.new(format_options) }

  include_examples "CWM::AbstractWidget"
end

describe Y2Partitioner::Widgets::BlockSize do
  let(:format_options) do
    double("Format Options")
  end

  subject { described_class.new(format_options) }

  include_examples "CWM::AbstractWidget"
end

describe Y2Partitioner::Widgets::PartitionId do
  let(:format_options) do
    double("Format Options")
  end

  subject { described_class.new(format_options) }

  include_examples "CWM::AbstractWidget"
end
