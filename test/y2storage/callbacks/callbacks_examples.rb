#!/usr/bin/env rspec
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

RSpec.shared_examples "general #error examples" do
  it "displays the error and the details to the user" do
    expect(Yast::Report).to receive(:yesno_popup) do |message, options|
      expect(message).to include "the message"
      expect(options[:details]).to eq "the what"
    end
    subject.error("the message", "the what")
  end

  # SWIG returns ASCII-8BIT encoded strings even if they contain UTF-8 characters
  # see https://sourceforge.net/p/swig/feature-requests/89/
  it "handles ASCII-8BIT encoded messages with UTF-8 characters" do
    expect(Yast::Report).to receive(:yesno_popup) do |message, options|
      expect(message).to include "🍺"
      expect(options[:details]).to include "🍻"
    end
    subject.error(
      "testing UTF-8 message: 🍺".force_encoding("ASCII-8BIT"),
      "details: 🍻".force_encoding("ASCII-8BIT")
    )
  end

  context "with an unknown error" do
    let(:what) { "Some error\nexit code:\n 2." }

    it "displays a generic error message to the user" do
      expect(Yast::Report).to receive(:yesno_popup) do |message|
        expect(message).to include "the message"
        expect(message).to include "Unexpected situation found"
      end
      subject.error("the message", what)
    end
  end

  context "with an empty what" do
    it "displays a generic error message to the user without hint about details" do
      expect(Yast::Report).to receive(:yesno_popup) do |message|
        expect(message).to include "the message"
        expect(message).not_to include "below to see more details"
      end
      subject.error("the message", "")
    end
  end

  context "with an error produced by a duplicated PV" do
    let(:what) do
      <<~FAILED_CMD
        What: command '/sbin/vgchange --activate y' failed:

        stdout:
          0 logical volume(s) in volume group "vg0" now active

        stderr:
          WARNING: Failed to connect to lvmetad. Falling back to device scanning.
          WARNING: PV uecMW2-1Qgu-b367-WBKL-uM2h-BRDB-nYva0a on /dev/sda4 was already found on /dev/sda2.
          WARNING: PV uecMW2-1Qgu-b367-WBKL-uM2h-BRDB-nYva0a prefers device /dev/sda2 because device size is correct.
          Cannot activate LVs in VG vg0 while PVs appear on duplicate devices.

        exit code:
        5.
      FAILED_CMD
    end

    before { allow(Yast::Mode).to receive(:auto).and_return auto }

    context "in a normal installation" do
      let(:auto) { false }
      before { mock_env(env_vars) }

      context "if LIBSTORAGE_MULTIPATH_AUTOSTART was not used" do
        let(:env_vars) { {} }

        it "displays a tip about LIBSTORAGE_MULTIPATH_AUTOSTART" do
          expect(Yast::Report).to receive(:yesno_popup) do |message|
            expect(message).to include "the message"
            expect(message).to include "LIBSTORAGE_MULTIPATH_AUTOSTART=ON"
          end
          subject.error("the message", what)
        end
      end

      context "if LIBSTORAGE_MULTIPATH_AUTOSTART was used" do
        let(:env_vars) { { "LIBSTORAGE_MULTIPATH_AUTOSTART" => "on" } }

        it "displays an error with no tip about the solution" do
          expect(Yast::Report).to receive(:yesno_popup) do |message|
            expect(message).to include "the message"
            expect(message).to_not include "LIBSTORAGE_MULTIPATH_AUTOSTART"
            expect(message).to_not include "start_multipath"
          end
          subject.error("the message", what)
        end
      end
    end

    context "in an AutoYaST installation" do
      let(:auto) { true }

      it "displays a tip about using start_multipath in the profile" do
        expect(Yast::Report).to receive(:yesno_popup) do |message|
          expect(message).to include "the message"
          expect(message).to include "start_multipath"
        end
        subject.error("the message", what)
      end
    end
  end

  it "asks the user whether to continue and returns the answer" do
    allow(Yast::Report).to receive(:yesno_popup).and_return(false, false, true)
    expect(subject.error("", "yes?")).to eq false
    expect(subject.error("", "please")).to eq false
    expect(subject.error("", "pretty please")).to eq true
  end
end

RSpec.shared_examples "default #error true examples" do
  it "defaults to true" do
    expect(Yast::Report).to receive(:yesno_popup) do |_message, options|
      expect(options[:focus]).to eq :yes
    end
    subject.error("msg", "what")
  end
end

RSpec.shared_examples "default #error false examples" do
  it "defaults to false" do
    expect(Yast::Report).to receive(:yesno_popup) do |_message, options|
      expect(options[:focus]).to eq :no
    end
    subject.error("msg", "what")
  end
end
