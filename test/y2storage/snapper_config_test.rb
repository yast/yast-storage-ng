#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2storage"
require "y2storage/snapper_config.rb"

describe Y2Storage::SnapperConfig do
  subject { Y2Storage::SnapperConfig }

  describe ".execute_on_target" do
    it "executes commands by default" do
      expect(subject.execute_on_target("ls /wrglbrmpf")).to eq(2)
      expect(subject.execute_on_target("/usr/bin/false")).to eq(1)
      expect(subject.execute_on_target("/usr/bin/wrglbrmpf")).to eq(127)
    end

    it "does not execute commands if execute_commands? returns false" do
      allow(subject).to receive(:execute_commands?).and_return(false)
      expect(subject.execute_on_target("/usr/bin/wrglbrmpf --force")).to eq(0)
    end

    it "sets last_cmd" do
      allow(subject).to receive(:execute_commands?).and_return(false)
      cmd = "do_something --quickly  --force"
      subject.execute_on_target(cmd)
      expect(subject.last_cmd).to eq(cmd)
    end
  end

  describe ".configure_snapper" do
    it "is false by default" do
      expect(subject.configure_snapper?).to be false
    end

    it "keeps a value once set" do
      subject.configure_snapper = true
      expect(subject.configure_snapper?).to be true
    end
  end

  context "smoke test" do
    before do
      allow(subject).to receive(:execute_commands?).and_return(false)
    end

    describe ".post_rpm_install" do
      it "does not crash" do
        subject.configure_snapper = true
        subject.post_rpm_install
        expect(subject.last_cmd).to start_with("/usr/bin")
      end
    end
  end
end
