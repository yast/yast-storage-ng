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

require_relative "../../spec_helper.rb"
require_relative "#{TEST_PATH}/support/guided_setup_context"

RSpec.shared_examples "wrong password" do
  it "shows an error message" do
    expect(Yast::Report).to receive(:Warning)
    subject.run
  end

  it "does not save password in settings" do
    subject.run
    expect(subject.settings.encryption_password).to eq(nil)
  end
end

describe Y2Storage::Dialogs::GuidedSetup::SelectScheme do
  include_context "guided setup requirements"

  subject { described_class.new(guided_setup) }

  describe "skip?" do
    it "returns false" do
      expect(subject.skip?).to eq(false)
    end
  end

  describe "#run" do
    let(:password) { "" }
    let(:repeat_password) { password }

    context "when settings has not LVM" do
      before do
        settings.use_lvm = false
      end

      it "does not select lvm by default" do
        expect_not_select(:lvm)
        subject.run
      end
    end

    context "when settings has LVM" do
      before do
        settings.use_lvm = true
      end

      it "selects lvm by default" do
        expect_select(:lvm)
        subject.run
      end
    end

    describe "checkbox for #separate_vgs" do
      before do
        allow(settings).to receive(:ng_format?).and_return ng_format
        allow(subject).to receive(:CheckBox)
      end

      context "when legacy settings are used" do
        let(:ng_format) { false }

        it "does not include an option for separate LVM groups" do
          expect(subject).to_not receive(:CheckBox).with(Id(:separate_vgs), any_args)

          subject.run
        end
      end

      context "when ng settings are used" do
        let(:ng_format) { true }

        before { allow(settings).to receive(:volumes).and_return volumes }

        let(:volumes) do
          [
            double("VolumeSpecification", mount_point: "/", separate_vg_name: separate_vg_name),
            double("VolumeSpecification", mount_point: "swap", separate_vg_name: separate_vg_name)
          ]
        end

        context "and no volume specifies a separate_vg_name" do
          let(:separate_vg_name) { nil }

          it "does not include an option for separate LVM groups" do
            expect(subject).to_not receive(:CheckBox).with(Id(:separate_vgs), any_args)

            subject.run
          end

          it "does not includes a clarification in the label used for the :lvm option" do
            expect(subject).to_not receive(:CheckBox).with(Id(:lvm), /for the Base System/)

            subject.run
          end
        end

        context "and some volume specifies a separate_vg_name" do
          let(:separate_vg_name) { "fake_separate_vg_name" }

          it "includes an option to use separate LVM volumes" do
            expect(subject).to receive(:CheckBox).with(Id(:separate_vgs), any_args)

            subject.run
          end

          it "includes a clarification in the label used for the :lvm option" do
            expect(subject).to receive(:CheckBox).with(Id(:lvm), /for the Base System/)

            subject.run
          end

          context "and settings does not set separate volume groups" do
            before { settings.separate_vgs = false }

            it "does not select separate_vgs by default" do
              expect_not_select(:separate_vgs)
              subject.run
            end
          end

          context "and settings sets separate volume groups" do
            before { settings.separate_vgs = true }

            it "selects separate_vgs by default" do
              expect_select(:separate_vgs)
              subject.run
            end
          end
        end
      end
    end

    context "when settings has not encryption password" do
      before do
        settings.encryption_password = nil
      end

      it "does not select encryption by default" do
        expect_not_select(:encryption)
        subject.run
      end
    end

    context "when settings has encryption password" do
      before do
        settings.encryption_password = "12345678"
      end

      it "selects encryption by default" do
        expect_select(:encryption)
        subject.run
      end
    end

    context "when encryption is not selected" do
      before do
        settings.encryption_password = "12345678"
        not_select_widget(:encryption)
      end

      it "disables password fields" do
        expect_disable(:password)
        expect_disable(:repeat_password)
        subject.run
      end

      it "sets password to nil" do
        subject.run
        expect(settings.encryption_password).to be_nil
      end
    end

    context "when encryption is selected" do
      before do
        select_widget(:encryption)
        select_widget(:password, password)
        select_widget(:repeat_password, repeat_password)
        settings.encryption_password = nil
      end

      it "enables password fields" do
        expect_enable(:password)
        expect_enable(:repeat_password)
        subject.run
      end

      context "and password is valid" do
        let(:password) { "Val1d_pass" }

        it "does not show an error message" do
          expect(Yast::Report).not_to receive(:Warning)
          subject.run
        end

        it "saves password in settings" do
          subject.run
          expect(subject.settings.encryption_password).to eq(password)
        end
      end

      context "but password is missing" do
        let(:password) { "" }
        include_examples("wrong password")
      end

      context "but passwords do not match" do
        let(:password) { "pass1" }
        let(:repeat_password) { "pass2" }
        include_examples("wrong password")
      end

      context "but password is short" do
        let(:password) { "pass" }
        include_examples("wrong password")
      end

      context "but password contains forbidden chars" do
        let(:password) { "pássw0rd1" }
        include_examples("wrong password")
      end

      context "and password is weak" do
        before do
          allow(Yast::InstExtensionImage).to receive(:LoadExtension)
            .with(/cracklib/, anything).and_return(true)
          allow(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".crack"), password)
            .and_return("an error message")
          allow(Yast::Popup).to receive(:AnyQuestion).and_return(password_accepted)
        end

        let(:password) { "12345678" }
        let(:password_accepted) { false }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:AnyQuestion)
          subject.run
        end

        context "and password is accepted" do
          let(:password_accepted) { true }

          it "saves password in settings" do
            subject.run
            expect(subject.settings.encryption_password).to eq(password)
          end
        end

        context "and password is not accepted" do
          let(:password_accepted) { false }

          it "does not save password in settings" do
            subject.run
            expect(subject.settings).not_to receive(:encryption_password=)
            expect(subject.settings.encryption_password).to eq(nil)
          end
        end
      end
    end

    context "when encryption is clicked" do
      before do
        select_widget(:encryption)
        allow(Yast::UI).to receive(:UserInput).and_return(:encryption, :abort)
      end

      it "focuses password field" do
        expect(Yast::UI).to receive(:SetFocus)
        subject.run
      end
    end

    context "when settings are valid" do
      before do
        select_widget(:lvm)
        select_widget(:encryption)
        select_widget(:password, password)
        select_widget(:repeat_password, password)
      end

      let(:password) { "Val1d_pass" }

      it "saves settings correctly" do
        subject.run
        expect(subject.settings.use_lvm).to eq(true)
        expect(subject.settings.encryption_password).to eq(password)
      end
    end
  end
end
