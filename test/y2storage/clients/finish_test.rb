#!/usr/bin/env rspec
# Copyright (c) [2018-2019] SUSE LLC
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
require "y2storage/clients/finish"
require "fileutils"

describe Y2Storage::Clients::Finish do
  subject(:client) { described_class.new }

  describe "#run" do
    before do
      allow(Yast::WFM).to receive(:Args).with(no_args).and_return(args)
      allow(Yast::WFM).to receive(:Args) { |n| n.nil? ? args : args[n] }

      allow(Yast::SCR).to receive(:Read)
      allow(Yast::SCR).to receive(:Write)
    end

    context "Info" do
      let(:args) { ["Info"] }

      it "returns a hash describing the client" do
        expect(client.run).to be_kind_of(Hash)
      end
    end

    context "Write" do
      let(:args) { ["Write"] }
      before { fake_scenario(scenario) }

      let(:scenario) { "lvm-two-vgs" }

      it "returns true" do
        expect(client.run).to eq(true)
      end

      it "updates sysconfig file" do
        mount_by_id = Y2Storage::Filesystems::MountByType::ID

        manager = Y2Storage::StorageManager.instance
        manager.default_mount_by = mount_by_id

        expect(Yast::SCR).to receive(:Write) do |path, value|
          expect(path.to_s).to match(/DEVICE_NAMES/)
          expect(value).to eq("id")
        end

        client.run
      end

      context "if Multipath is used in the target system" do
        let(:scenario) { "multipath-formatted.xml" }

        it "enables multipathd" do
          expect(Yast::Service).to receive(:Enable).with("multipathd")
          client.run
        end
      end

      context "if Multipath is not used in the target system" do
        let(:scenario) { "output/windows-pc" }

        it "does not enable any service" do
          expect(Yast::Service).to_not receive(:Enable)
          client.run
        end
      end

      context "if some device was encrypted using pervasive encryption" do
        let(:scenario) { "several-dasds" }
        let(:staging) { Y2Storage::StorageManager.instance.staging }
        let(:blk_device) { staging.find_by_name("/dev/dasdc1") }
        let(:pervasive) { Y2Storage::EncryptionMethod::PERVASIVE_LUKS2 }
        let(:secure_key) { Y2Storage::EncryptionProcesses::SecureKey }

        before do
          allow(secure_key).to receive(:for_device).with(blk_device)
            .and_return secure_key.new("key_for_dasdc1")

          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("ZKEY_REPOSITORY")
            .and_return File.join(DATA_PATH, "zkey_repository")

          blk_device.encrypt(method: pervasive)
        end

        context "if the target system contains a zkey repository" do
          around do |example|
            @tmp_dir = Dir.mktmpdir
            container = File.join(@tmp_dir, "etc", "zkey")
            FileUtils.mkdir_p(container)
            @tmp_repo = File.join(container, "repository")

            example.run
          ensure
            FileUtils.remove_entry @tmp_dir
          end

          before { allow(Yast::Installation).to receive(:destdir).and_return @tmp_dir }

          context "and is possible to create new files into it" do
            before { FileUtils.mkdir(@tmp_repo) }

            it "copies the keys to the repository of the target system" do
              client.run

              file1 = File.join(@tmp_repo, "key_for_dasdc1.skey")
              file2 = File.join(@tmp_repo, "key_for_dasdc1.info")
              expect(File.exist?(file1)).to eq true
              expect(File.exist?(file2)).to eq true
            end
          end

          context "but is no possible to create files in the target repository" do
            # Make it a regular file instead of a directory to force the failure
            before { FileUtils.touch(@tmp_repo) }

            it "raises no error" do
              expect { client.run }.to_not raise_error
            end
          end
        end

        context "if the target system contains no zkey repository" do
          before { allow(Yast::Installation).to receive(:destdir).and_return DATA_PATH }

          it "raises no error" do
            expect { client.run }.to_not raise_error
          end
        end
      end
    end
  end
end
