#!/usr/bin/env rspec

# Copyright (c) [2018-2021] SUSE LLC
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

describe Y2Partitioner::Actions::ConfigureAction do
  describe "#run" do
    before do
      Y2Storage::StorageManager.create_test_instance
      allow(Yast::Stage).to receive(:initial).and_return install

      allow(Yast::Popup).to receive(:YesNo).and_return accepted
      allow(manager).to receive(:probe).and_return true
    end

    let(:accepted) { false }
    let(:manager) { Y2Storage::StorageManager.instance }

    RSpec.shared_examples "configure nothing" do
      it "returns nil" do
        expect(subject.run).to be_nil
      end

      it "does not call any other YaST client" do
        expect(Yast::WFM).to_not receive(:call)
        subject.run
      end

      it "does not reset the activation cache" do
        expect(Y2Storage::Luks).to_not receive(:reset_activation_infos)
        subject.run
      end

      it "does not run activation again" do
        expect(manager).to_not receive(:activate)
        subject.run
      end

      it "does not probe again" do
        expect(manager).to_not receive(:probe)
        subject.run
      end
    end

    RSpec.shared_examples "configure with a separate client" do
      it "calls the corresponding YaST client" do
        expect(Yast::WFM).to receive(:call).with(client_name)
        subject.run
      end

      it "does not reset the activation cache" do
        expect(Y2Storage::Luks).to_not receive(:reset_activation_infos)
        subject.run
      end

      it "probes again" do
        expect(manager).to receive(:probe)
        subject.run
      end
    end

    RSpec.shared_examples "show configure warning" do
      it "displays the corresponding warning message" do
        expect(Yast::Popup).to receive(:YesNo).with(warning_regexp)
        subject.run
      end

      context "if the user rejects the warning" do
        let(:accepted) { false }

        include_examples "configure nothing"
      end
    end

    RSpec.shared_examples "try packages installation" do
      before do
        allow(Yast::PackageCallbacks).to receive(:RegisterEmptyProgressCallbacks)
        allow(Yast::PackageCallbacks).to receive(:RestorePreviousProgressCallbacks)
        allow(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return installed_pkgs
      end
      let(:installed_pkgs) { false }

      it "checks for the corresponding packages and tries to installs them if needed" do
        expect(Yast::PackageSystem)
          .to receive(:CheckAndInstallPackages).with(packages)
        subject.run
      end

      context "if the packages were not installed" do
        let(:installed_pkgs) { false }

        include_examples "configure nothing"
      end
    end

    RSpec.shared_examples "action with a separate client" do
      context "during installation" do
        let(:install) { true }
        before { allow(manager).to receive(:activate).and_return true }

        include_examples "show configure warning"

        context "if the user accepts the warning" do
          let(:accepted) { true }

          include_examples "configure with a separate client"
        end
      end

      context "in an already installed system" do
        let(:install) { false }

        include_examples "show configure warning"

        context "if the user accepts the warning" do
          let(:accepted) { true }

          include_examples "try packages installation"

          context "if the packages were installed or already there" do
            let(:installed_pkgs) { true }

            include_examples "configure with a separate client"
          end
        end
      end
    end

    describe Y2Partitioner::Actions::ConfigureIscsi do
      let(:warning_regexp) { /iSCSI/ }
      let(:packages) { ["yast2-iscsi-client"] }
      let(:client_name) { "iscsi-client" }

      include_examples "action with a separate client"
    end

    describe Y2Partitioner::Actions::ConfigureDasd do
      let(:warning_regexp) { /DASD configuration/ }
      let(:packages) { ["yast2-s390"] }
      let(:client_name) { "dasd" }

      include_examples "action with a separate client"
    end

    describe Y2Partitioner::Actions::ConfigureFcoe do
      let(:warning_regexp) { /FCoE/ }
      let(:packages) { ["yast2-fcoe-client"] }
      let(:client_name) { "fcoe-client" }

      include_examples "action with a separate client"
    end

    describe Y2Partitioner::Actions::ConfigureZfcp do
      let(:warning_regexp) { /zFCP/ }
      let(:packages) { ["yast2-s390"] }
      let(:client_name) { "zfcp" }

      include_examples "action with a separate client"
    end

    describe Y2Partitioner::Actions::ConfigureXpram do
      let(:warning_regexp) { /XPRAM configuration/ }
      let(:packages) { ["yast2-s390"] }
      let(:client_name) { "xpram" }

      include_examples "action with a separate client"
    end

    describe Y2Partitioner::Actions::ProvideCryptPasswords do
      let(:warning_regexp) { /crypt devices/ }
      let(:packages) { ["cryptsetup"] }

      RSpec.shared_examples "configure provide passwords" do
        it "does not call any additional YaST client" do
          expect(Yast::WFM).to_not receive(:call)
          subject.run
        end

        it "resets the activation cache" do
          expect(Y2Storage::Luks).to receive(:reset_activation_infos)
          subject.run
        end

        it "probes again" do
          expect(manager).to receive(:probe)
          subject.run
        end
      end

      context "during installation" do
        let(:install) { true }
        before { allow(manager).to receive(:activate).and_return true }

        include_examples "show configure warning"

        context "if the user accepts the warning" do
          let(:accepted) { true }

          include_examples "configure provide passwords"
        end
      end

      context "in an already installed system" do
        let(:install) { false }

        include_examples "show configure warning"

        context "if the user accepts the warning" do
          let(:accepted) { true }

          include_examples "try packages installation"

          context "if the packages were installed or already there" do
            let(:installed_pkgs) { true }

            include_examples "configure provide passwords"
          end
        end
      end
    end
  end
end
