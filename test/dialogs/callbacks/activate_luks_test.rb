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

require_relative "../../spec_helper"
require "y2storage/dialogs/callbacks/activate_luks"

describe Y2Storage::Dialogs::Callbacks::ActivateLuks do
  include Yast::UIShortcuts

  before do
    allow(Yast::UI).to receive(:OpenDialog).and_return(true)
    allow(Yast::UI).to receive(:CloseDialog).and_return(true)
    allow(Yast::UI).to receive(:UserInput).and_return(action)
    allow(Yast::UI).to receive(:QueryWidget).with(Id(:password), :Value)
      .and_return(password)
  end

  subject { described_class.new(uuid, attempts) }

  let(:uuid) { "11111111-1111-1111-1111-11111111" }
  let(:attempts) { 1 }
  let(:action) { :abort }
  let(:password) { nil }

  describe "#run" do
    context "when a password is entered" do
      let(:password) { "123456" }

      it "enables accept button" do
        expect(Yast::UI).to receive(:ChangeWidget).once.with(Id(:accept), :Enabled, true)
        subject.run
      end

      context "and dialog is accepted" do
        let(:action) { :accept }

        it "returns that password as encryption password" do
          subject.run
          expect(subject.encryption_password).to eq(password)
        end
      end

      context "and dialog is not accepted" do
        let(:action) { :cancel }

        it "returns nil as encryption password" do
          subject.run
          expect(subject.encryption_password).to be_nil
        end
      end
    end

    context "when a password is not entered" do
      let(:password) { nil }

      it "does not enable accept button" do
        expect(Yast::UI).to receive(:ChangeWidget).once.with(Id(:accept), :Enabled, false)
        subject.run
      end

      context "and dialog is not accepted" do
        let(:action) { :cancel }

        it "returns nil as encryption password" do
          subject.run
          expect(subject.encryption_password).to be_nil
        end
      end
    end
  end
end
