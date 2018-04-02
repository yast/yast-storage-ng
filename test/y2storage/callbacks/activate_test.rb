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
require_relative "callbacks_examples"
require "y2storage/callbacks/activate"

describe Y2Storage::Callbacks::Activate do
  subject { described_class.new }

  describe "#error" do
    include_examples "general #error examples"
    include_examples "default #error true examples"
  end

  describe "#luks" do
    let(:dialog) { instance_double(Y2Storage::Dialogs::Callbacks::ActivateLuks) }

    before do
      allow(dialog).to receive(:run).and_return(action)
      allow(dialog).to receive(:encryption_password).and_return(encryption_password)
      allow(Y2Storage::Dialogs::Callbacks::ActivateLuks).to receive(:new).and_return dialog
    end

    let(:uuid) { "11111111-1111-1111-1111-11111111" }
    let(:attempts) { 1 }
    let(:action) { nil }
    let(:encryption_password) { "123456" }

    it "opens a dialog to request the password" do
      expect(dialog).to receive(:run).once
      subject.luks(uuid, attempts)
    end

    it "returns an object of the expected type" do
      expect(subject.luks(uuid, attempts)).to be_a(Storage::PairBoolString)
    end

    context "when the dialog is accepted" do
      let(:action) { :accept }

      it "returns the pair (true, password)" do
        result = subject.luks(uuid, attempts)
        expect(result.first).to eq(true)
        expect(result.second).to eq(encryption_password)
      end
    end

    context "when the dialog is not accepted" do
      let(:action) { :cancel }

      it "returns the pair (false, \"\")" do
        result = subject.luks(uuid, attempts)
        expect(result.first).to eq(false)
        expect(result.second).to eq("")
      end
    end
  end

  describe "#multipath" do
    before { mock_env(env_vars) }

    context "if libstorage-ng found no multipath in the system" do
      let(:mp_detected) { false }

      context "and LIBSTORAGE_MULTIPATH_AUTOSTART was activated on boot" do
        let(:env_vars) do
          {
            # Upcase one has precedence
            "LIBSTORAGE_MULTIPATH_AUTOSTART" => "on",
            "libstorage_multipath_autostart" => "no"
          }
        end

        it "does not ask the user" do
          expect(Yast::Popup).to_not receive(:YesNo)
          subject.multipath(mp_detected)
        end

        it "returns true" do
          expect(subject.multipath(mp_detected)).to eq true
        end
      end

      context "and LIBSTORAGE_MULTIPATH_AUTOSTART was deactivated on boot" do
        let(:env_vars) do
          { "LIBSTORAGE_MULTIPATH_AUTOSTART" => "off" }
        end

        it "does not ask the user" do
          expect(Yast::Popup).to_not receive(:YesNo)
          subject.multipath(mp_detected)
        end

        it "returns false" do
          expect(subject.multipath(mp_detected)).to eq false
        end
      end

      context "and LIBSTORAGE_MULTIPATH_AUTOSTART was not specified on boot" do
        let(:env_vars) { {} }

        it "does not ask the user" do
          expect(Yast::Popup).to_not receive(:YesNo)
          subject.multipath(mp_detected)
        end

        it "returns false" do
          expect(subject.multipath(mp_detected)).to eq false
        end
      end
    end

    context "if libstorage-ng detected a multipath setup the system" do
      let(:mp_detected) { true }

      before do
        allow(Yast::Popup).to receive(:YesNo).and_return answer
      end
      let(:answer) { true }

      RSpec.shared_examples "ask user about multipath" do
        it "asks the user whether to activate multipath" do
          expect(Yast::Popup).to receive(:YesNo).once
          subject.multipath(mp_detected)
        end

        context "if the user accepts" do
          let(:answer) { true }

          it "returns true" do
            expect(subject.multipath(mp_detected)).to eq true
          end
        end

        context "if the user rejects" do
          let(:answer) { false }

          it "returns false" do
            expect(subject.multipath(mp_detected)).to eq false
          end
        end
      end

      context "and LIBSTORAGE_MULTIPATH_AUTOSTART was activated on boot" do
        let(:env_vars) do
          { "LIBSTORAGE_MULTIPATH_AUTOSTART" => "1" }
        end

        it "does not ask the user" do
          expect(Yast::Popup).to_not receive(:YesNo)
          subject.multipath(mp_detected)
        end

        it "returns true" do
          expect(subject.multipath(mp_detected)).to eq true
        end
      end

      context "and LIBSTORAGE_MULTIPATH_AUTOSTART was deactivated on boot" do
        let(:env_vars) do
          { "LIBSTORAGE_MULTIPATH_AUTOSTART" => "off" }
        end

        include_examples "ask user about multipath"
      end

      context "and LIBSTORAGE_MULTIPATH_AUTOSTART was not specified on boot" do
        let(:env_vars) { {} }

        include_examples "ask user about multipath"
      end
    end
  end
end
