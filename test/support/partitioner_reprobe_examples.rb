# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
# find current contact information at www.suse.com

Yast.import "Popup"

RSpec.shared_examples "reprobing" do
  it "shows an status message" do
    expect(Yast::Popup).to receive(:Feedback)
    subject.handle(*handle_args)
  end

  it "probes again" do
    expect(manager).to receive(:probe).and_return(true)
    subject.handle(*handle_args)
  end

  it "refreshes devicegraphs for the expert partitioner" do
    expect(Y2Partitioner::DeviceGraphs).to receive(:create_instance)
    subject.handle(*handle_args)
  end

  it "returns :redraw" do
    expect(subject.handle(*handle_args)).to eq(:redraw)
  end

  context "and the probing could not be correctly performed" do
    before do
      allow(manager).to receive(:probe).and_return(false)
    end

    it "raises an exception" do
      expect { subject.handle(*handle_args) }.to raise_error(Y2Partitioner::ForcedAbortError)
    end
  end
end
