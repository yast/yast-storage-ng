#!/usr/bin/env rspec

# Copyright (c) [2023] SUSE LLC
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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::AutoinstProposal do
  before do
    fake_scenario(scenario)

    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  let(:scenario) { "empty_disks" }
  let(:issues_list) { ::Installation::AutoinstIssues::List.new }

  let(:partitioning) do
    [
      {
        "device" => "/dev/sda",
        "type" => :CT_DISK, "use" => "all", "initialize" => true, "disklabel" => "gpt",
        "partitions" => partitions
      }
    ]
  end

  let(:partitions) { [partition] }

  describe "#propose" do
    context "when creating a LUKS2 device with default options" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2 }
      end

      it "encrypts the device with LUKS2 as encryption method" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.method).to eq Y2Storage::EncryptionMethod::LUKS2
      end

      it "does not set any LUKS label" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.label).to eq ""
      end

      it "does not set any derivation function, cipher or key size" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.pbkdf).to be_nil
        expect(enc.cipher).to eq ""
        expect(enc.key_size).to be_zero
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end
    end

    context "when creating a LUKS2 device with a given password derivation function" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2, "crypt_pbkdf" => :argon2i }
      end

      it "uses the corresponding derivation function" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.pbkdf).to eq Y2Storage::PbkdFunction::ARGON2I
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end
    end

    context "when creating a LUKS2 device with an unsupported password derivation function" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2, "crypt_pbkdf" => :wrong }
      end

      it "does not enforce any derivation function" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.pbkdf).to be_nil
      end

      it "register an AutoinstIssues::InvalidValue warning" do
        proposal.propose
        expect(issues_list).to_not be_empty
        issue = issues_list.first
        expect(issue.class).to eq Y2Storage::AutoinstIssues::InvalidValue
        expect(issue.attr).to eq :crypt_pbkdf
      end
    end

    context "when creating a LUKS2 device with given cipher and key size" do
      let(:partition) do
        {
          "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2,
          "crypt_cipher" => "aes-xts-plain64", "crypt_key_size" => 512
        }
      end

      it "uses the corresponding cipher and key size" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.cipher).to eq "aes-xts-plain64"
        # libstorage-ng uses bytes instead of bits to represent the key size, contrary to all LUKS
        # documentation and to cryptsetup
        expect(enc.key_size).to eq 64
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end
    end

    context "when creating a LUKS2 device with an invalid key size" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2, "crypt_key_size" => 12 }
      end

      it "does not enforce any key size" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.key_size).to be_zero
      end

      it "register an AutoinstIssues::InvalidValue warning" do
        proposal.propose
        expect(issues_list).to_not be_empty
        issue = issues_list.first
        expect(issue.class).to eq Y2Storage::AutoinstIssues::InvalidValue
        expect(issue.attr).to eq :crypt_key_size
      end
    end

    context "when creating a LUKS2 device with a given LUKS label" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2, "crypt_label" => "crpt" }
      end

      it "sets the label in the LUKS device" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.label).to eq "crpt"
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end
    end

    context "when creating a LUKS1 device with a given password derivation function" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks1, "crypt_pbkdf" => :argon2i }
      end

      it "does not enforce any derivation function" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.method).to eq Y2Storage::EncryptionMethod::LUKS1
        expect(enc.pbkdf).to be_nil
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end
    end

    context "when creating a LUKS1 device with a LUKS label" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks1, "crypt_label" => "crpt" }
      end

      it "does not set the label" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.method).to eq Y2Storage::EncryptionMethod::LUKS1
        expect(enc.label).to be_empty
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end
    end

    context "when creating a SECURE_SWAP device with given cipher and key size" do
      before do
        allow_any_instance_of(Y2Storage::EncryptionMethod::SecureSwap).to receive(:available?)
          .and_return(true)
      end

      let(:partitions) do
        [
          { "mount" => "/" },
          {
            "mount" => "swap", "crypt_method" => :secure_swap,
            "crypt_cipher" => "aes-xts-plain64", "crypt_key_size" => 512
          }
        ]
      end

      it "ignores the given cipher and key size" do
        proposal.propose
        enc = proposal.devices.encryptions.first
        expect(enc.method).to eq Y2Storage::EncryptionMethod::SECURE_SWAP
        expect(enc.cipher).to eq ""
        expect(enc.key_size).to be_zero
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end
    end

    context "when encrypting the root partition using LUKS2 with the default derivation function" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2 }
      end

      it "adds an extra /boot partition since we cannot ensure Grub2 can open the root volume" do
        proposal.propose
        mount_points = proposal.devices.filesystems.map(&:mount_path)
        expect(mount_points).to contain_exactly("/boot", "/")
      end
    end

    context "when encrypting the root partition using LUKS2 with PBKDF2 as derivation function" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2, "crypt_pbkdf" => :pbkdf2 }
      end

      it "does not add an extra /boot partition since Grub2 can open the root volume" do
        proposal.propose
        mount_points = proposal.devices.filesystems.map(&:mount_path)
        expect(mount_points).to contain_exactly("/")
      end
    end

    context "when encrypting the root partition using LUKS2 with Argon2i as derivation function" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :luks2, "crypt_pbkdf" => :argon2i }
      end

      it "adds an extra /boot partition since Grub2 cannot open the root volume" do
        proposal.propose
        mount_points = proposal.devices.filesystems.map(&:mount_path)
        expect(mount_points).to contain_exactly("/boot", "/")
      end
    end

    context "when using pervasive LUKS2 method" do
      let(:partition) do
        { "mount" => "/", "crypt_key" => "s3cr3t", "crypt_method" => :pervasive_luks2, "..." => :todo }
      end

      xit "does not register any issue" do
        proposal.propose
        # todo: fails as the method is unavailable, I haven't mocked any apqns
        expect(issues_list).to be_empty
      end
    end
  end
end
