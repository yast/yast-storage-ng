#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require_relative "../../test_helper"
require_relative "examples"
require_relative "matchers"

require "y2partitioner/widgets/menus/system"

describe Y2Partitioner::Widgets::Menus::System do
  before do
    allow(Yast::Stage).to receive(:initial).and_return(install)
  end

  subject(:menu) { described_class.new }

  let(:install) { false }

  def find_menu(menu, label)
    menu.items.find { |i| i.is_a?(Yast::Term) && i.value == :menu && i.params[0] == label }
  end

  include_examples "Y2Partitioner::Widgets::Menus"

  describe "#items" do
    it "includes entries for exiting with and without saving the changes" do
      expect(subject.items).to include(item_with_id(:abort))
      expect(subject.items).to include(item_with_id(:next))
    end

    it "includes and entry for rescaning devices" do
      expect(subject.items).to include(item_with_id(:rescan_devices))
    end

    context "during installation" do
      let(:install) { true }

      it "includes the entry Import Mount Points" do
        expect(subject.items).to include(item_with_id(:import_mount_points))
      end
    end

    context "in an already installed system" do
      let(:install) { false }

      it "does not include the entry Import Mount Points" do
        expect(subject.items).to_not include(item_with_id(:import_mount_points))
      end
    end

    # All the following tests about the entries available in the configure menu are a bit
    # redundant with the tests for Actions::ConfigureAction, but we can live with that

    it "contains a Configure menu with entries for encryption, iSCSI and FCoE" do
      configure = find_menu(subject, "&Configure")
      expect(configure).to_not be_nil

      items = configure.params[1]
      expect(items).to include(item_with_id(:provide_crypt_passwords))
      expect(items).to include(item_with_id(:configure_iscsi))
      expect(items).to include(item_with_id(:configure_fcoe))
    end

    context "in a s390 system" do
      let(:architecture) { :s390 }

      it "contains entries for DASD, zFCP and XPRAM in the configure menu" do
        configure = find_menu(subject, "&Configure")
        items = configure.params[1]

        expect(items).to include(item_with_id(:configure_dasd))
        expect(items).to include(item_with_id(:configure_zfcp))
        expect(items).to include(item_with_id(:configure_xpram))
      end
    end

    context "in a non-s390 system" do
      let(:architecture) { :x86_64 }

      it "contains no entries for DASD, zFCP or XPRAM in the configure menu" do
        configure = find_menu(subject, "&Configure")
        items = configure.params[1]

        expect(items).to_not include(item_with_id(:configure_dasd))
        expect(items).to_not include(item_with_id(:configure_zfcp))
        expect(items).to_not include(item_with_id(:configure_xpram))
      end
    end
  end

  describe "#disabled_items" do
    it "returns an empty array, since all present entries are always enabled" do
      expect(menu.disabled_items).to eq []
    end
  end

  describe "#handle" do
    let(:architecture) { :s390 }

    RSpec.shared_examples "handle action" do |action_class|
      # Using here something like this
      #   allow(action_class).to receive(:new).and_return a_double
      # turned to be pretty hard because action classes are memoized.
      # So this looks like a legitimate usage of allow_any_instance.
      before { allow_any_instance_of(action_class).to receive(:run).and_return action_result }
      let(:action_result) { :whatever }

      it "calls the corresponding action (#{action_class})" do
        expect_any_instance_of(action_class).to receive(:run)
        menu.handle(id)
      end

      context "if the action returns :finish" do
        let(:action_result) { :finish }

        it "returns :redraw" do
          expect(menu.handle(id)).to eq :redraw
        end
      end

      context "if the action returns any different result" do
        let(:action_result) { :next }

        it "returns nil" do
          expect(menu.handle(id)).to be_nil
        end
      end
    end

    context "when :rescan_devices was selected" do
      let(:id) { :rescan_devices }
      include_examples "handle action", Y2Partitioner::Actions::RescanDevices
    end

    context "when :import_mount_points was selected" do
      let(:id) { :import_mount_points }
      include_examples "handle action", Y2Partitioner::Actions::ImportMountPoints
    end

    context "when :provide_crypt_passwords was selected" do
      let(:id) { :provide_crypt_passwords }
      include_examples "handle action", Y2Partitioner::Actions::ProvideCryptPasswords
    end

    context "when :configure_iscsi was selected" do
      let(:id) { :configure_iscsi }
      include_examples "handle action", Y2Partitioner::Actions::ConfigureIscsi
    end

    context "when :configure_fcoe was selected" do
      let(:id) { :configure_fcoe }
      include_examples "handle action", Y2Partitioner::Actions::ConfigureFcoe
    end

    context "when :configure_dasd was selected" do
      let(:id) { :configure_dasd }
      include_examples "handle action", Y2Partitioner::Actions::ConfigureDasd
    end

    context "when :configure_zfcp was selected" do
      let(:id) { :configure_zfcp }
      include_examples "handle action", Y2Partitioner::Actions::ConfigureZfcp
    end

    context "when :configure_xpram was selected" do
      let(:id) { :configure_xpram }
      include_examples "handle action", Y2Partitioner::Actions::ConfigureXpram
    end
  end
end
