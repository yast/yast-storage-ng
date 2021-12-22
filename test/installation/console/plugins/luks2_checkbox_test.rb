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

require_relative "../../../spec_helper"

# mock the "installation/console/menu_plugin" content (from yast2-installation)
module Installation
  module Console
    class MenuPlugin
    end
  end
end

require "installation/console/plugins/luks2_checkbox"
require "cwm/rspec"

describe Installation::Console::Plugins::LUKS2CheckBox do
  subject(:widget) { described_class.new }

  include_examples "CWM::CheckBox"

  describe "#init" do
    before do
      expect(Y2Storage::StorageEnv.instance).to receive(:luks2_available?)
        .and_return(luks2_available)
    end

    context "LUKS2 available" do
      let(:luks2_available) { true }

      it "sets the initial state to checked" do
        expect(widget).to receive(:check)
        widget.init
      end
    end

    context "LUKS2 not available" do
      let(:luks2_available) { false }

      it "sets the initial state to unchecked" do
        expect(widget).to_not receive(:check)
        widget.init
      end
    end
  end

  describe "#store" do
    before do
      allow(Y2Storage::StorageEnv.instance).to receive(:reset_cache)
      allow(ENV).to receive(:delete)
      allow(ENV).to receive(:[]=)

      allow(widget).to receive(:checked?).and_return(checked)
    end

    context "the checkbox is checked" do
      let(:checked) { true }

      it "sets the YAST_LUKS2_AVAILABLE env variable to 1" do
        expect(Y2Storage::StorageEnv.instance).to receive(:reset_cache)
        expect(ENV).to receive(:[]=).with("YAST_LUKS2_AVAILABLE", "1")
        widget.store
      end
    end

    context "the checkbox is not checked" do
      let(:checked) { false }

      it "deletes the YAST_LUKS2_AVAILABLE env variable" do
        expect(Y2Storage::StorageEnv.instance).to receive(:reset_cache)
        expect(ENV).to receive(:delete).with("YAST_LUKS2_AVAILABLE")
        widget.store
      end
    end
  end
end

describe Installation::Console::Plugins::LUKS2CheckBoxPlugin do
  describe "#order" do
    it "returns a positive number" do
      expect(subject.order).to be_a(Numeric)
      expect(subject.order).to be > 0
    end
  end

  describe "#widget" do
    it "returns a CWM widget" do
      expect(subject.widget).to be_a(CWM::AbstractWidget)
    end
  end
end
