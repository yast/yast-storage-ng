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

require "y2partitioner/actions/import_mount_points"

describe Y2Partitioner::Actions::ImportMountPoints do
  subject { described_class.new }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show)

      allow(subject).to receive(:controller).and_return(controller)

      allow(controller).to receive(:fstabs).and_return(fstabs)
    end

    let(:controller) { Y2Partitioner::Actions::Controllers::Fstabs.new }

    context "when there are no fstab files in the system" do
      let(:fstabs) { [] }

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/no fstab/, anything)
        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when there are fstab files in the system" do
      let(:fstabs) { [instance_double(Y2Storage::Fstab)] }

      before do
        allow(Y2Partitioner::Dialogs::ImportMountPoints).to receive(:new).and_return(dialog)

        allow(dialog).to receive(:run).and_return(result)
      end

      let(:dialog) { instance_double(Y2Partitioner::Dialogs::ImportMountPoints) }

      let(:result) { :abort }

      it "shows the dialog for importing mount points" do
        expect(dialog).to receive(:run)

        subject.run
      end

      context "and the dialog is not accepted" do
        let(:result) { :cancel }

        it "returns the result of the dialog" do
          expect(subject.run).to eq(:cancel)
        end

        it "does not import mount points" do
          expect(controller).to_not receive(:import_mount_points)

          subject.run
        end
      end

      context "and the dialog is accepted" do
        let(:result) { :ok }

        before do
          allow(controller).to receive(:import_mount_points)
        end

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end

        it "imports mount points" do
          expect(controller).to receive(:import_mount_points)

          subject.run
        end
      end
    end
  end
end
