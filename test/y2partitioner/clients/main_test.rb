#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../test_helper"

require "y2partitioner/clients/main"

describe Y2Partitioner::Clients::Main do
  subject { described_class.new }

  describe "#run" do
    before do
      Y2Storage::StorageManager.create_test_instance

      allow(Yast2::Popup).to receive(:show).with(/you are familiar/, anything)
        .and_return(warning_answer)

      allow(Y2Storage::StorageManager).to receive(:setup).with(mode: :rw)
        .and_return(storage_setup)
    end

    let(:warning_answer) { nil }

    let(:storage_setup) { nil }

    it "shows an initial warning popup" do
      expect(Yast2::Popup).to receive(:show).with(/you are familiar/, anything)

      subject.run
    end

    context "when the initial warning popup is not accepted" do
      let(:warning_answer) { :no }

      it "does not run the partitioner dialog" do
        expect(Y2Partitioner::Dialogs::Main).to_not receive(:new)

        subject.run
      end

      it "returns nil" do
        expect(subject.run).to be_nil
      end
    end

    context "when the initial warning popup is accepted" do
      let(:warning_answer) { :yes }

      context "and storage system cannot be initialized as read-write" do
        let(:storage_setup) { false }

        it "does not run the partitioner dialog" do
          expect(Y2Partitioner::Dialogs::Main).to_not receive(:new)

          subject.run
        end

        it "returns nil" do
          expect(subject.run).to be_nil
        end
      end

      context "and storage system can be initialized as read-write" do
        let(:storage_setup) { true }

        before do
          allow(Y2Partitioner::Dialogs::Main).to receive(:new)
            .and_return(partitioner_dialog, other_partitioner_dialog)
          allow(partitioner_dialog).to receive(:run).and_return(partitioner_result)

          allow(Yast::Execute).to receive(:locally!)
            .with("/sbin/udevadm", any_args)
          allow(Yast::Execute).to receive(:locally!)
            .with("/usr/lib/YaST2/bin/mask-systemd-units", any_args)
        end

        let(:partitioner_dialog) { instance_double(Y2Partitioner::Dialogs::Main) }

        let(:other_partitioner_dialog) { instance_double(Y2Partitioner::Dialogs::Main) }

        let(:partitioner_result) { nil }

        let(:storage_manager) { Y2Storage::StorageManager.instance }

        context "but probing fails" do
          before { allow(storage_manager).to receive(:probed).and_return nil }

          it "does not run the partitioner dialog" do
            expect(Y2Partitioner::Dialogs::Main).to_not receive(:new)

            subject.run
          end

          it "returns nil" do
            expect(subject.run).to be_nil
          end
        end

        it "runs the partitioner dialog" do
          expect(partitioner_dialog).to receive(:run)

          expect(Yast::Execute).to receive(:locally!).with("/sbin/udevadm", "control",
            "--property=ANACONDA=yes").ordered
          expect(Yast::Execute).to receive(:locally!).with("/usr/lib/YaST2/bin/mask-systemd-units",
            "--mask").ordered
          expect(Yast::Execute).to receive(:locally!).with("/usr/lib/YaST2/bin/mask-systemd-units",
            "--unmask").ordered
          expect(Yast::Execute).to receive(:locally!).with("/sbin/udevadm", "control",
            "--property=ANACONDA=").ordered

          subject.run
        end

        context "and the user accepts the partitioner changes" do
          let(:partitioner_result) { :next }

          before do
            allow(partitioner_dialog).to receive(:device_graph).and_return(device_graph)
          end

          let(:device_graph) { instance_double(Y2Storage::Devicegraph) }

          context "and it is allowed to commit" do
            let(:allow_commit) { true }

            it "commits the changes" do
              expect(storage_manager).to receive(:"staging=").with(device_graph)
              # this also blocks the real #commit call
              expect(storage_manager).to receive(:commit)

              subject.run(allow_commit: allow_commit)
            end
          end

          context "and it is not allowed to commit" do
            let(:allow_commit) { false }

            it "shows a message" do
              expect(Yast2::Popup).to receive(:show).with(/commit is not allowed/)

              subject.run(allow_commit: allow_commit)
            end

            it "does not commit" do
              allow(Yast2::Popup).to receive(:show)

              expect(storage_manager).to_not receive(:commit)

              subject.run(allow_commit: allow_commit)
            end
          end
        end
      end
    end
  end
end
