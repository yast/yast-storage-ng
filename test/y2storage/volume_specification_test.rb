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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::VolumeSpecification do
  using Y2Storage::Refinements::SizeCasts

  subject { described_class.new(volume_features) }

  describe "#initialize" do
    context "when creating from a set of features" do
      let(:volume_features) do
        {
          "mount_point" => "/home",
          "proposed"    => true,
          "min_size"    => "5 GiB",
          "weight"      => "300"
        }
      end

      it "creates an object with the indicated features" do
        expect(subject.mount_point).to eq("/home")
        expect(subject.proposed).to eq(true)
        expect(subject.min_size).to eq(5.GiB)
        expect(subject.weight).to eq(300)
      end

      it "does not set the missing features" do
        expect(subject.desired_size).to be_nil
        expect(subject.fs_type).to be_nil
      end

      it "sets max_size to unlimited by default" do
        expect(subject.max_size).to eq(Y2Storage::DiskSize.unlimited)
      end

      context "when a fs_type is indicated" do
        let(:volume_features) { { "fs_type" => fs_type } }

        context "and fs_type is valid" do
          let(:fs_type) { :ext3 }

          it "sets the proper Filesystems::Type" do
            type = Y2Storage::Filesystems::Type.find(:ext3)
            expect(subject.fs_type).to eq(type)
          end
        end

        context "and fs_type is not valid" do
          let(:fs_type) { :foo }

          it "raises an exception" do
            expect { subject }.to raise_error(NameError)
          end
        end
      end

      context "when the list of fs_types is not indicated" do
        let(:volume_features) { { "mount_point" => mount_point } }

        context "and the volume is root" do
          let(:mount_point) { "/" }

          it "sets a fallback list of fs_types for root" do
            expect(subject.fs_types).to eq(Y2Storage::Filesystems::Type.root_filesystems)
          end
        end

        context "and the volume is home" do
          let(:mount_point) { "/home" }

          it "sets a fallback list of fs_types for home" do
            expect(subject.fs_types).to eq(Y2Storage::Filesystems::Type.home_filesystems)
          end
        end

        context "and the volume is neither root nor home" do
          let(:mount_point) { "/tmp" }

          it "sets an empty list of fs_types" do
            expect(subject.fs_types).to be_empty
          end
        end
      end

      context "when a list of fs_types is indicated" do
        let(:volume_features) { { "fs_types" => fs_types } }

        context "and all of them are valid types" do
          let(:fs_types) { ["ext3", "xfs", "btrfs"] }

          it "sets a list of proper Filesystems::Type" do
            types = [:ext3, :xfs, :btrfs].map { |t| Y2Storage::Filesystems::Type.find(t) }
            expect(subject.fs_types).to eq(types)
          end
        end

        context "and it contains some not valid type" do
          let(:fs_types) { ["ext3", "foo", "btrfs"] }

          it "raises an exception" do
            expect { subject }.to raise_error(NameError)
          end
        end
      end

      context "when the list of subvolumes is not indicated" do
        let(:volume_features) { { "mount_point" => mount_point } }

        context "and the volume is not root" do
          let(:mount_point) { "/home" }

          it "sets an empty list of subvolumes" do
            expect(subject.subvolumes).to be_empty
          end
        end

        context "and the volume is root" do
          let(:mount_point) { "/" }

          it "sets a fallback list of subvolumes" do
            expect(subject.subvolumes).to_not be_empty
            expect(subject.subvolumes).to all(be_a(Y2Storage::SubvolSpecification))
          end
        end
      end

      context "when a list of subvolumes is indicated" do
        let(:volume_features) { { "mount_point" => mount_point, "subvolumes" => subvolumes } }

        context "and the list is empty" do
          let(:subvolumes) { [] }

          context "and the volume is not root" do
            let(:mount_point) { "/home" }

            it "sets an empty list of subvolumes" do
              expect(subject.subvolumes).to be_empty
            end
          end

          context "and the volume is root" do
            let(:mount_point) { "/" }

            it "sets a fallback list of subvolumes" do
              expect(subject.subvolumes).to_not be_empty
              expect(subject.subvolumes).to all(be_a(Y2Storage::SubvolSpecification))
            end
          end
        end

        context "and the list is not empty" do
          let(:mount_point) { "/home" }

          let(:subvolumes) do
            [
              { "path" => "home" },
              { "path" => "var", "copy_on_write" => false, "archs" => "i386,x86_64" },
              { "path" => "opt", "copy_on_write" => true }
            ]
          end

          it "sets the indicated list of subvolumes" do
            expect(subject.subvolumes).to include(
              an_object_having_attributes(path: "home", copy_on_write: true, archs: nil),
              an_object_having_attributes(path: "var", copy_on_write: false, archs: ["i386", "x86_64"]),
              an_object_having_attributes(path: "opt", copy_on_write: true,  archs: nil)
            )
          end
        end
      end
    end
  end
end
