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

require_relative "spec_helper"
require "y2storage"
require "y2storage/storage_env"

describe Y2Storage::StorageEnv do
  before do
    mock_env(env_vars)
  end

  describe "#activate_luks?" do
    context "YAST_ACTIVATE_LUKS is not set" do
      let(:env_vars) do
        {}
      end

      it "returns true" do
        expect(Y2Storage::StorageEnv.instance.activate_luks?).to be true
      end
    end

    context "YAST_ACTIVATE_LUKS is empty" do
      let(:env_vars) do
        { "YAST_ACTIVATE_LUKS" => "" }
      end

      it "returns true" do
        expect(Y2Storage::StorageEnv.instance.activate_luks?).to be true
      end
    end

    context "YAST_ACTIVATE_LUKS is set to '1'" do
      let(:env_vars) do
        { "YAST_ACTIVATE_LUKS" => "1" }
      end

      it "returns true" do
        expect(Y2Storage::StorageEnv.instance.activate_luks?).to be true
      end
    end

    context "YAST_ACTIVATE_LUKS is set to '0'" do
      let(:env_vars) do
        { "YAST_ACTIVATE_LUKS" => "0" }
      end

      it "returns false" do
        expect(Y2Storage::StorageEnv.instance.activate_luks?).to be false
      end
    end
  end
end
