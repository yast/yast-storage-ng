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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/main_menu_bar"

describe Y2Partitioner::Widgets::MainMenuBar do
  subject(:menu_bar) { described_class.new }

  describe "#contents" do
    def menu_entries(menu)
      menu.params[1]
    end

    def entry_id(entry)
      id_term = entry.params.find { |param| param.is_a?(Yast::Term) && param.value.to_sym == :id }
      return nil unless id_term

      id_term.params.first
    end

    before do
      allow(Yast::WFM).to receive(:ClientExists) do |name|
        !missing_clients.include?(name)
      end
      allow(Yast::Arch).to receive(:s390).and_return s390
    end

    let(:all_clients) { %w[iscsi-client fcoe-client dasd zfcp xpram] }
    let(:missing_clients) { [] }

    let(:menus) { menu_bar.contents.params[1] }
    let(:all_entries) { menus.flat_map { |menu| menu_entries(menu) } }

    context "during installation" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return true
      end

      context "in s390" do
        let(:s390) { true }

        it "contains an entry for rescanning devices" do
          entry = all_entries.find { |e| entry_id(e) == :rescan_devices }
          expect(entry).to_not be_nil
        end

        it "contains an entry for importing mount points" do
          entry = all_entries.find { |e| entry_id(e) == :import_mount_points }
          expect(entry).to_not be_nil
        end

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "contains entries for crypt, iSCI, FCoE, DASD, zFCP and XPRAM" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe, :configure_dasd,
              :configure_zfcp, :configure_xpram
            )
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client", "dasd"] }

          it "contains entries only for the available clients" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(
              :provide_crypt_passwords, :configure_fcoe, :configure_zfcp, :configure_xpram
            )
            expect(ids).to_not include(:configure_iscsi)
            expect(ids).to_not include(:configure_dasd)
          end
        end

        context "if no client is available" do
          let(:missing_clients) { all_clients }

          it "contains 'Crypt Passwords' as the only configuration option" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include :provide_crypt_passwords
            expect(ids).to_not include(
              :configure_iscsi, :configure_fcoe, :configure_dasd, :configure_zfcp, :configure_xpram
            )
          end
        end
      end

      context "in a non-s390 system" do
        let(:s390) { false }

        it "contains an entry for rescanning devices" do
          entry = all_entries.find { |e| entry_id(e) == :rescan_devices }
          expect(entry).to_not be_nil
        end

        it "contains an entry for importing mount points" do
          entry = all_entries.find { |e| entry_id(e) == :import_mount_points }
          expect(entry).to_not be_nil
        end

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "contains entries for crypt, iSCI and FCoE" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe
            )
            expect(ids).to_not include(
              :configure_dasd, :configure_zfcp, :configure_xpram
            )
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client"] }

          it "contains entries only for the available clients" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(:provide_crypt_passwords, :configure_fcoe)
            expect(ids).to_not include(:configure_iscsi)
          end
        end

        context "if no client is available" do
          let(:missing_clients) { all_clients }

          it "contains 'Crypt Passwords' as the only configuration option" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include :provide_crypt_passwords
            expect(ids).to_not include(
              :configure_iscsi, :configure_fcoe, :configure_dasd, :configure_zfcp, :configure_xpram
            )
          end
        end
      end
    end

    context "in an already installed system" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return false
      end

      context "in s390" do
        let(:s390) { true }

        it "contains an entry for rescanning devices" do
          entry = all_entries.find { |e| entry_id(e) == :rescan_devices }
          expect(entry).to_not be_nil
        end

        it "does not contain an entry for importing mount points" do
          entry = all_entries.find { |e| entry_id(e) == :import_mount_points }
          expect(entry).to be_nil
        end

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "contains entries for all the configure actions" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe, :configure_dasd,
              :configure_zfcp, :configure_xpram
            )
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client", "dasd"] }

          it "contains entries for all the configure actions" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(
              :provide_crypt_passwords, :configure_iscsi, :configure_fcoe, :configure_dasd,
              :configure_zfcp, :configure_xpram
            )
          end
        end
      end

      context "in a non-s390 system" do
        let(:s390) { false }

        it "contains an entry for rescanning devices" do
          entry = all_entries.find { |e| entry_id(e) == :rescan_devices }
          expect(entry).to_not be_nil
        end

        it "does not contain an entry for importing mount points" do
          entry = all_entries.find { |e| entry_id(e) == :import_mount_points }
          expect(entry).to be_nil
        end

        context "if all the possible clients are available" do
          let(:missing_clients) { [] }

          it "contains entries for all the supported actions (crypt, iSCI and FCoE)" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(:provide_crypt_passwords, :configure_iscsi, :configure_fcoe)
            expect(ids).to_not include(:configure_dasd, :configure_zfcp, :configure_xpram)
          end
        end

        context "if some clients are not available" do
          let(:missing_clients) { ["iscsi-client"] }

          it "contains entries for all the supported actions (crypt, iSCI and FCoE)" do
            ids = all_entries.map { |e| entry_id(e) }
            expect(ids).to include(:provide_crypt_passwords, :configure_iscsi, :configure_fcoe)
            expect(ids).to_not include(:configure_dasd, :configure_zfcp, :configure_xpram)
          end
        end
      end
    end
  end
end
