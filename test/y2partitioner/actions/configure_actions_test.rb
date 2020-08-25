#!/usr/bin/env rspec
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
require "y2partitioner/actions/configure_actions"

describe Y2Partitioner::Actions::ConfigureActions do
  subject(:actions) { described_class.new }

  def menu_item_ids(items)
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

  describe "#menu_items" do
    before do
      allow(Yast::WFM).to receive(:ClientExists) do |name|
        !missing_clients.include?(name)
      end
      allow(Yast::Arch).to receive(:s390).and_return s390
    end

    let(:all_clients) { %w[iscsi-client fcoe-client dasd zfcp xpram] }

    context "during installation" do
      let(:install) { true }

      context "in s390" do
        let(:s390) { true }

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "returns menu items for crypt, iSCI, FCoE, DASD, zFCP and XPRAM" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to contain_exactly(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe, :configure_dasd, :configure_zfcp, :configure_xpram
            )
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client", "dasd"] }

          it "returns menu items only for the available clients" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to contain_exactly(
              :provide_crypt_passwords, :configure_fcoe, :configure_zfcp, :configure_xpram
            )
            expect(menu_item_ids(items)).to_not include(:configure_iscsi, :configure_dasd)
          end
        end

        context "if no client is available" do
          let(:missing_clients) { all_clients }

          it "returns a menu button with 'Crypt Passwords' as the only option" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to eq [:provide_crypt_passwords]
          end
        end
      end

      context "in a non-s390 system" do
        let(:s390) { false }

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "returns menu items for crypt, iSCI and FCoE" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to contain_exactly(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe
            )
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client"] }

          it "returns menu items only for the available clients" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to eq [:provide_crypt_passwords, :configure_fcoe]
            expect(menu_item_ids(items)).to_not include(:configure_iscsi)
          end
        end

        context "if no client is available" do
          let(:missing_clients) { all_clients }

          it "returns a menu button with 'Crypt Passwords' as the only option" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to eq [:provide_crypt_passwords]
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

          it "returns menu items for all actions" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to contain_exactly(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe, :configure_dasd, :configure_zfcp, :configure_xpram
            )
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client", "dasd"] }

          it "returns menu items for all actions" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to contain_exactly(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe, :configure_dasd, :configure_zfcp, :configure_xpram
            )
          end
        end
      end

      context "in a non-s390 system" do
        let(:s390) { false }

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "returns menu items for all supported actions (crypt, iSCI and FCoE)" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to contain_exactly(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe
            )
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client"] }

          it "returns menu items for all supported actions (crypt, iSCI and FCoE)" do
            items = actions.menu_items
            expect(menu_item_ids(items)).to contain_exactly(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe
            )
          end
        end
      end
    end
  end

  describe "#run" do
    before do
      allow(Yast::Popup).to receive(:YesNo).and_return accepted
      allow(manager).to receive(:probe).and_return true
    end

    let(:accepted) { false }
    let(:manager) { Y2Storage::StorageManager.instance }
    let(:id) { :configure_iscsi }

    RSpec.shared_examples "configure nothing" do
      it "returns nil" do
        expect(actions.run(id)).to be_nil
      end

      it "does not call any other YaST client" do
        expect(Yast::WFM).to_not receive(:call)
        actions.run(id)
      end

      it "does not run activation again" do
        expect(manager).to_not receive(:activate)
        actions.run(id)
      end

      it "does not probe again" do
        expect(manager).to_not receive(:probe)
        actions.run(id)
      end
    end

    RSpec.shared_examples "show configure warning" do
      it "displays the corresponding warning message" do
        expect(Yast::Popup).to receive(:YesNo).with(/FCoE/).ordered
        expect(Yast::Popup).to receive(:YesNo).with(/iSCSI/).ordered
        actions.run(:configure_fcoe)
        actions.run(:configure_iscsi)
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

        context "for an action performed via a separate client" do
          it "calls the corresponding YaST client" do
            expect(Yast::WFM).to receive(:call).with("iscsi-client")
            actions.run(:configure_iscsi)
          end
        end

        context "for activation of crypt devices" do
          it "does not call any additional YaST client" do
            expect(Yast::WFM).to_not receive(:call)
            actions.run(:provide_crypt_passwords)
          end
        end
      end
    end

    context "in an already installed system" do
      let(:install) { false }
      # Ensure all actions are available
      before { allow(Yast::Arch).to receive(:s390).and_return true }

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
          actions.run(:configure_dasd)
          actions.run(:configure_fcoe)
        end

        context "if the packages were not installed" do
          let(:installed_pkgs) { false }

          include_examples "configure nothing"
        end

        context "if the packages were installed or already there" do
          let(:installed_pkgs) { true }

          context "for an action performed via a separate client" do

            it "calls the corresponding YaST client" do
              expect(Yast::WFM).to receive(:call).with("iscsi-client")
              actions.run(:configure_iscsi)
            end

            it "does not run activation" do
              expect(manager).to_not receive(:activate)
              actions.run(:configure_iscsi)
            end
          end

          context "for activation of crypt devices" do
            before { allow(manager).to receive(:activate).and_return true }

            it "does not call any additional YaST client" do
              expect(Yast::WFM).to_not receive(:call)
              actions.run(:provide_crypt_passwords)
            end
          end
        end
      end
    end
  end
end
