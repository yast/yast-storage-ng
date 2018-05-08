#!/usr/bin/env rspec
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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/configure"
require_relative "reprobe"

describe Y2Partitioner::Widgets::Configure do
  subject(:widget) { described_class.new }

  def menu_button_item_ids(button)
    items = button.params.last
    items.map do |item|
      id = item.params.find { |param| param.is_a?(Yast::Term) && param.value == :id }
      id.params.first
    end
  end

  before do
    Y2Storage::StorageManager.create_test_instance
    allow(Yast::Stage).to receive(:initial).and_return install
  end
  let(:install) { false }

  include_examples "CWM::AbstractWidget"

  describe "#contents" do
    before do
      allow(Yast::WFM).to receive(:ClientExists) do |name|
        !missing_clients.include?(name)
      end
      allow(Yast::Arch).to receive(:s390).and_return s390
    end

    let(:all_clients) { %w(iscsi-client fcoe-client dasd zfcp xpram) }

    context "during installation" do
      let(:install) { true }

      context "in s390" do
        let(:s390) { true }

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "returns a menu button with buttons for iSCI, FCoE, DASD, zFCP and XPRAM" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to contain_exactly(:iscsi, :fcoe, :dasd, :zfcp, :xpram)
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client", "dasd"] }

          it "returns a menu button with buttons only for the available clients" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to contain_exactly(:fcoe, :zfcp, :xpram)
            expect(menu_button_item_ids(term)).to_not include(:iscsi, :dasd)
          end
        end

        context "if no client is available" do
          let(:missing_clients) { all_clients }

          it "returns an empty term" do
            term = widget.contents
            expect(term.value).to eq :Empty
          end
        end
      end

      context "in a non-s390 system" do
        let(:s390) { false }

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "returns a menu button with buttons for iSCI and FCoE" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to contain_exactly(:iscsi, :fcoe)
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client"] }

          it "returns a menu button with buttons only for the available clients" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to eq [:fcoe]
            expect(menu_button_item_ids(term)).to_not include(:iscsi)
          end
        end

        context "if no client is available" do
          let(:missing_clients) { all_clients }

          it "returns an empty term" do
            term = widget.contents
            expect(term.value).to eq :Empty
          end
        end
      end
    end

    context "in an already installed system" do
      let(:install) { false }

      context "in s390" do
        let(:s390) { true }

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "returns a menu button with buttons for all clients (iSCI, FCoE, DASD, zFCP and XPRAM)" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to contain_exactly(:iscsi, :fcoe, :dasd, :zfcp, :xpram)
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client", "dasd"] }

          it "returns a menu button with buttons for all clients (iSCI, FCoE, DASD, zFCP and XPRAM)" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to contain_exactly(:iscsi, :fcoe, :dasd, :zfcp, :xpram)
          end
        end
      end

      context "in a non-s390 system" do
        let(:s390) { false }

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "returns a menu button with buttons for all supported clients (iSCI and FCoE)" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to contain_exactly(:iscsi, :fcoe)
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client"] }

          it "returns a menu button with buttons for all supported clients (iSCI and FCoE)" do
            term = widget.contents
            expect(term.value).to eq :MenuButton
            expect(menu_button_item_ids(term)).to contain_exactly(:iscsi, :fcoe)
          end
        end
      end
    end
  end

  describe "#handle" do
    def event_for(id)
      { "ID" => id }
    end

    before do
      allow(Yast::Popup).to receive(:YesNo).and_return accepted
      allow(manager).to receive(:probe).and_return true
    end
    let(:accepted) { false }

    let(:handle_args) { [event_for(:fcoe)] }
    let(:manager) { Y2Storage::StorageManager.instance }
    let(:event) { event_for(:iscsi) }

    RSpec.shared_examples "configure nothing" do
      it "returns nil" do
        expect(widget.handle(event)).to be_nil
      end

      it "does not call any other YaST client" do
        expect(Yast::WFM).to_not receive(:call)
        widget.handle(event)
      end

      it "does not run activation again" do
        expect(manager).to_not receive(:activate)
        widget.handle(event)
      end

      it "does not probe again" do
        expect(manager).to_not receive(:probe)
        widget.handle(event)
      end
    end

    RSpec.shared_examples "show configure warning" do
      it "displays the corresponding warning message" do
        expect(Yast::Popup).to receive(:YesNo).with(/FCoE/).ordered
        expect(Yast::Popup).to receive(:YesNo).with(/iSCSI/).ordered
        widget.handle(event_for(:fcoe))
        widget.handle(event_for(:iscsi))
      end

      context "if the user rejects the warning" do
        let(:accepted) { false }

        include_examples "configure nothing"
      end
    end

    context "during installation" do
      let(:install) { true }
      before { allow(manager).to receive(:activate).and_return true }

      include_examples "show configure warning"

      context "if the user accepts the warning" do
        let(:accepted) { true }

        it "calls the corresponding YaST client" do
          expect(Yast::WFM).to receive(:call).with("iscsi-client")
          widget.handle(event)
        end

        include_examples "reprobing"

        it "runs activation again" do
          expect(manager).to receive(:activate).and_return true
          widget.handle(event)
        end

        it "raises an exception if activation fails" do
          allow(manager).to receive(:activate).and_return false
          expect { subject.handle(event) }.to raise_error(Y2Partitioner::ForcedAbortError)
        end
      end
    end

    context "in an already installed system" do
      let(:install) { false }

      include_examples "show configure warning"

      context "if the user accepts the warning" do
        let(:accepted) { true }

        before do
          allow(Yast::PackageCallbacks).to receive(:RegisterEmptyProgressCallbacks)
          allow(Yast::PackageCallbacks).to receive(:RestorePreviousProgressCallbacks)
          allow(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return installed_pkgs
        end
        let(:installed_pkgs) { false }

        it "checks for the corresponding packages and tries to installs them if needed" do
          expect(Yast::PackageSystem)
            .to receive(:CheckAndInstallPackages).with(["yast2-s390"]).ordered
          expect(Yast::PackageSystem)
            .to receive(:CheckAndInstallPackages).with(["yast2-fcoe-client"]).ordered
          widget.handle(event_for(:dasd))
          widget.handle(event_for(:fcoe))
        end

        context "if the packages were not installed" do
          let(:installed_pkgs) { false }

          include_examples "configure nothing"
        end

        context "if the packages were installed or already there" do
          let(:installed_pkgs) { true }

          it "calls the corresponding YaST client" do
            expect(Yast::WFM).to receive(:call).with("iscsi-client")
            widget.handle(event)
          end

          include_examples "reprobing"

          it "does not run activation" do
            expect(manager).to_not receive(:activate)
            widget.handle(event)
          end
        end
      end
    end
  end
end
