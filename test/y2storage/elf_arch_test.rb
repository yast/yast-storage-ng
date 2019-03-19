#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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

require_relative "spec_helper"
require "y2storage/elf_arch"

describe Y2Storage::ELFArch do
  subject { described_class.new("/") }

  describe "#value" do
    context "when the 'elf-arch' command successes" do
      before do
        allow(Yast::Execute).to receive(:locally!)
          .with(/elf-arch/, /bash/, anything).and_return("ppc")
      end

      it "returns the architecture from the ELF of bash binary" do
        expect(subject.value).to eq("ppc")
      end
    end

    context "when the 'elf-arch' command fails" do
      before do
        allow(Yast::Execute).to receive(:locally!)
          .with(/elf-arch/, /bash/, anything).and_raise(cheetah_error)
      end

      let(:cheetah_error) { Cheetah::ExecutionFailed.new([], "", nil, nil) }

      it "returns 'unknown'" do
        expect(subject.value).to eq("unknown")
      end
    end
  end
end
