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

  describe ".build_command_line" do
    it "builds a simple command line" do
      expect(subject.build_command_line("echo", "hello", "world")).to eq("echo hello world")
    end

    it "handles commands without arguments" do
      expect(subject.build_command_line("echo")).to eq("echo")
    end

    it "strips whitespace off arguments" do
      expect(subject.build_command_line("echo", " hello ", "  world ")).to eq("echo hello world")
    end

    it "strips whitespace off the command" do
      expect(subject.build_command_line(" echo ", "hello", "world")).to eq("echo hello world")
    end

    it "sets last_cmd_line" do
      subject.build_command_line("do_something", "--quickly ", " --force ")
      expect(subject.last_cmd_line).to eq("do_something --quickly --force")
    end
  end

  describe ".execute_on_target" do
    it "does not really execute commands if execute_commands is false" do
      subject.execute_commands = false
      expect(subject.execute_on_target("/usr/bin/wrglbrmpf", "--force")).to eq(0)
    end

    it "does execute commands if execute_commands is true" do
      subject.execute_commands = true
      expect(subject.execute_on_target("ls", "/wrglbrmpf")).to eq(2)
    end

    it "returns stdout of an executed command" do
      subject.execute_on_target("echo", "hello", "world")
      expect(subject.last_stdout).to eq("hello world\n")
      expect(subject.last_stderr).to be_empty
    end
  end

  describe ".steps" do
    before do
      subject.execute_commands = false
    end

    describe ".step4" do
      it "calls installation-helper correctly with step4" do
        subject.step4
        expect(subject.last_cmd_line).to eq("/usr/bin/snapper " \
          "--no-dbus set-config NUMBER_CLEANUP=yes " \
          "NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10 " \
          "TIMELINE_CREATE=no")
      end
    end

    describe ".step6" do
      it "calls installation-helper correctly with step6" do
        subject.step6
        expect(subject.last_cmd_line).to eq("/usr/bin/snapper --no-dbus setup-quota")
      end
    end
  end
end
