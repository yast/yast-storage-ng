#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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

require_relative "../../spec_helper"
require_relative "#{TEST_PATH}/support/devices_planner_context"

require "storage"
require "y2storage"

describe Y2Storage::Proposal::DevicesPlannerStrategies::Legacy do
  describe "#planned_devices" do
    using Y2Storage::Refinements::SizeCasts

    include_context "devices planner"

    subject { described_class.new(settings, devicegraph) }

    it "returns an array of planned devices" do
      planned_devices = subject.planned_devices(:desired)
      expect(planned_devices).to be_a Array
      expect(planned_devices).to all(be_a(Y2Storage::Planned::Device))
    end

    it "includes the partitions needed by BootRequirementChecker" do
      expect(subject.planned_devices(:desired)).to include(
        an_object_having_attributes(mount_point: "/one_boot", filesystem_type: xfs),
        an_object_having_attributes(mount_point: "/other_boot", filesystem_type: vfat)
      )
    end

    # This swap sizes are currently hard-coded
    context "swap volumes" do
      before { settings.enlarge_swap_for_suspend = false }

      let(:swap_volumes) { subject.planned_devices(:desired).select { |v| v.mount_point == "swap" } }

      context "if there is no previous swap partition" do
        let(:swap_partitions) { [] }

        it "includes a brand new swap volume and no swap reusing" do
          expect(swap_volumes).to contain_exactly(an_object_having_attributes(reuse_name: nil))
        end
      end

      context "if the existing swap partition is not big enough" do
        let(:swap_partitions) { [partition_double("/dev/sdaX", 1.GiB)] }

        it "includes a brand new swap volume and no swap reusing" do
          expect(swap_volumes).to contain_exactly(an_object_having_attributes(reuse_name: nil))
        end
      end

      context "if the existing swap partition is big enough" do
        let(:swap_partitions) { [partition_double("/dev/sdaX", 3.GiB)] }

        context "if proposing an LVM setup" do
          before { settings.use_lvm = true }

          it "includes a brand new swap volume and no swap reusing" do
            expect(swap_volumes).to contain_exactly(an_object_having_attributes(reuse_name: nil))
          end
        end

        context "if proposing a partition-based setup" do
          context "without encryption" do
            it "includes a volume to reuse the existing swap and no new swap" do
              expect(swap_volumes).to contain_exactly(
                an_object_having_attributes(reuse_name: "/dev/sdaX")
              )
            end
          end

          context "with encryption" do
            before { settings.encryption_password = "12345678" }

            it "includes a brand new swap volume and no swap reusing" do
              expect(swap_volumes).to contain_exactly(
                an_object_having_attributes(reuse_name: nil)
              )
            end
          end
        end
      end

      context "if proposing a partition-based setup" do
        context "without encryption" do
          it "proposes a plain partition" do
            expect(swap_volumes).to contain_exactly(
              an_object_having_attributes(
                class: Y2Storage::Planned::Partition, encryption_password: nil
              )
            )
          end
        end

        context "with encryption" do
          before { settings.encryption_password = "12345678" }

          it "proposes an encrypted partition" do
            expect(swap_volumes).to contain_exactly(
              an_object_having_attributes(
                class: Y2Storage::Planned::Partition, encryption_password: "12345678"
              )
            )
          end
        end
      end

      context "if proposing an LVM-based setup" do
        before { settings.use_lvm = true }

        context "without encryption" do
          it "proposes a plain logical volume with the right name" do
            expect(swap_volumes).to contain_exactly(
              an_object_having_attributes(
                class:               Y2Storage::Planned::LvmLv,
                encryption_password: nil,
                logical_volume_name: "swap"
              )
            )
          end
        end

        context "with encryption" do
          before { settings.encryption_password = "12345678" }

          # Encryption is performed at PV level, not at LV one
          it "proposes a plain logical volume with the right name" do
            expect(swap_volumes).to contain_exactly(
              an_object_having_attributes(
                class:               Y2Storage::Planned::LvmLv,
                encryption_password: nil,
                logical_volume_name: "swap"
              )
            )
          end
        end
      end

      context "without enlarge_swap_for_suspend" do
        it "plans a small swap volume" do
          expect(swap_volumes.first.min).to eq 2.GiB
          expect(swap_volumes.first.max).to eq 2.GiB
        end
      end

      context "with enlarge_swap_for_suspend" do
        before do
          settings.enlarge_swap_for_suspend = true
        end

        it "plans a bigger swap volume" do
          expect(swap_volumes.first.min).to eq 8.GiB
          expect(swap_volumes.first.max).to eq 8.GiB
        end
      end
    end

    context "with use_separate_home" do
      before do
        settings.use_separate_home = true
        settings.home_min_size = 4.GiB
        settings.home_max_size = Y2Storage::DiskSize.unlimited
        settings.home_filesystem_type = xfs
      end

      let(:home) { subject.planned_devices(:desired).detect { |v| v.mount_point == "/home" } }

      it "includes a /home planned device with the configured settings" do
        expect(home).to have_attributes(
          mount_point:     "/home",
          min:             settings.home_min_size,
          max:             settings.home_max_size,
          filesystem_type: settings.home_filesystem_type
        )
      end

      context "if proposing a partition-based setup" do
        context "without encryption" do
          it "proposes /home to be a plain partition" do
            expect(home).to be_a Y2Storage::Planned::Partition
            expect(home.encrypt?).to eq false
          end
        end

        context "with encryption" do
          before { settings.encryption_password = "12345678" }

          it "proposes /home to be an encrypted partition" do
            expect(home).to be_a Y2Storage::Planned::Partition
            expect(home.encrypt?).to eq true
            expect(home.encryption_password).to eq "12345678"
          end
        end
      end

      context "if proposing an LVM-based setup" do
        before { settings.use_lvm = true }

        context "without encryption" do
          it "proposes /home to be a plain logical volume with the right name" do
            expect(home).to be_a Y2Storage::Planned::LvmLv
            expect(home.encrypt?).to eq false
            expect(home.logical_volume_name).to eq "home"
          end
        end

        context "with encryption" do
          before { settings.encryption_password = "12345678" }

          # Encryption is performed at PV level, not at LV one
          it "proposes /home to be a plain logical volume with the right name" do
            expect(home).to be_a Y2Storage::Planned::LvmLv
            expect(home.encrypt?).to eq false
            expect(home.logical_volume_name).to eq "home"
          end
        end
      end
    end

    context "without use_separate_home" do
      before do
        settings.use_separate_home = false
      end

      it "does not include a /home volume" do
        expect(subject.planned_devices(:desired)).to_not include(
          an_object_having_attributes(mount_point: "/home")
        )
      end
    end

    describe "setting the properties of the root partition" do
      before do
        settings.root_base_size = 10.GiB
        settings.root_max_size = 20.GiB
        settings.btrfs_increase_percentage = 75
      end

      let(:root) { subject.planned_devices(:desired).detect { |v| v.mount_point == "/" } }

      context "if proposing a partition-based setup" do
        context "without encryption" do
          it "proposes / to be a plain partition" do
            expect(root).to be_a Y2Storage::Planned::Partition
            expect(root.encrypt?).to eq false
          end
        end

        context "with encryption" do
          before { settings.encryption_password = "12345678" }

          it "proposes / to be an encrypted partition" do
            expect(root).to be_a Y2Storage::Planned::Partition
            expect(root.encrypt?).to eq true
            expect(root.encryption_password).to eq "12345678"
          end
        end
      end

      context "if proposing an LVM-based setup" do
        before { settings.use_lvm = true }

        context "without encryption" do
          it "proposes / to be a plain logical volume with the right name" do
            expect(root).to be_a Y2Storage::Planned::LvmLv
            expect(root.encrypt?).to eq false
            expect(root.logical_volume_name).to eq "root"
          end
        end

        context "with encryption" do
          before { settings.encryption_password = "12345678" }

          # Encryption is performed at PV level, not at LV one
          it "proposes / to be a plain logical volume with the right name" do
            expect(root).to be_a Y2Storage::Planned::LvmLv
            expect(root.encrypt?).to eq false
            expect(root.logical_volume_name).to eq "root"
          end
        end
      end

      context "with a non-Btrfs filesystem" do
        before do
          settings.root_filesystem_type = xfs
        end

        it "uses the normal sizes" do
          expect(subject.planned_devices(:min)).to include(
            an_object_having_attributes(
              mount_point:     "/",
              min:             10.GiB,
              max:             20.GiB,
              filesystem_type: xfs
            )
          )

          expect(subject.planned_devices(:desired)).to include(
            an_object_having_attributes(
              mount_point:     "/",
              min:             20.GiB,
              max:             20.GiB,
              filesystem_type: xfs
            )
          )
        end

        it "does not plan snapshots for the root device" do
          root = subject.planned_devices(:desired).find(&:root?)
          expect(root.snapshots?).to eq false
        end
      end

      context "if Btrfs is used" do
        before do
          settings.root_filesystem_type = btrfs
          allow(settings).to receive(:subvolumes).and_return settings_subvolumes
        end

        let(:root) { subject.planned_devices(:desired).detect { |v| v.mount_point == "/" } }
        let(:settings_subvolumes) do
          [
            Y2Storage::SubvolSpecification.new("var"),
            Y2Storage::SubvolSpecification.new("home")
          ]
        end

        context "and snapshots are not active" do
          before do
            settings.use_snapshots = false
          end

          it "uses the normal sizes" do
            expect(subject.planned_devices(:min)).to include(
              an_object_having_attributes(
                mount_point:     "/",
                min:             10.GiB,
                max:             20.GiB,
                filesystem_type: btrfs
              )
            )

            expect(subject.planned_devices(:desired)).to include(
              an_object_having_attributes(
                mount_point:     "/",
                min:             20.GiB,
                max:             20.GiB,
                filesystem_type: btrfs
              )
            )
          end

          it "does not plan snapshots for the root device" do
            root = subject.planned_devices(:desired).find(&:root?)
            expect(root.snapshots?).to eq false
          end
        end

        context "and snapshots are active" do
          before do
            settings.use_snapshots = true
          end

          it "increases all the sizes by btrfs_increase_percentage" do
            expect(subject.planned_devices(:min)).to include(
              an_object_having_attributes(
                mount_point:     "/",
                min:             17.5.GiB,
                max:             35.GiB,
                filesystem_type: btrfs
              )
            )

            expect(subject.planned_devices(:desired)).to include(
              an_object_having_attributes(
                mount_point:     "/",
                min:             35.GiB,
                max:             35.GiB,
                filesystem_type: btrfs
              )
            )
          end

          it "plans snapshots for the root device" do
            root = subject.planned_devices(:desired).find(&:root?)
            expect(root.snapshots?).to eq true
          end
        end

        context "if none of the planned subvolumes generated by ProposalSettings is shadowed" do
          before { settings.use_separate_home = false }

          it "includes all the subvolumes in the planned root device" do
            expect(root.subvolumes).to eq settings_subvolumes
          end
        end

        context "if some of the planned subvolumes generated by ProposalSettings is shadowed" do
          before { settings.use_separate_home = true }

          it "includes only the non-shadowed subvolumes in the planned root device" do
            expect(root.subvolumes.map(&:path)).to eq ["var"]
          end
        end
      end
    end
  end
end
