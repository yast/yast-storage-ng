#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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

require_relative "../../../spec_helper.rb"
require_relative "#{TEST_PATH}/support/widgets_context"
require "y2storage/dialogs/guided_setup/widgets/windows_partition_actions"

describe Y2Storage::Dialogs::GuidedSetup::Widgets::WindowsPartitionActions do
  include_context "widgets"

  subject { described_class.new(widget_id, settings) }

  let(:widget_id) { :windows_actions }

  let(:settings) { Y2Storage::ProposalSettings.new }

  describe "#init" do
    context "when settings.windows_delete_mode is set to :all" do
      before do
        settings.windows_delete_mode = :all
      end

      it "sets the Windows action to :always_remove" do
        expect_select(:windows_actions, :always_remove)

        subject.init
      end
    end

    context "when settings.windows_delete_mode is set to :ondemand" do
      before do
        settings.windows_delete_mode = :ondemand
      end

      it "sets the Windows action to :remove" do
        expect_select(:windows_actions, :remove)

        subject.init
      end
    end

    context "when settings.windows_delete_mode is set to :none" do
      before do
        settings.windows_delete_mode = :none
      end

      context "and resizing is allowed" do
        before do
          settings.resize_windows = true
        end

        it "sets the Windows action to :resize" do
          expect_select(:windows_actions, :resize)

          subject.init
        end
      end

      context "and resizing is not allowed" do
        before do
          settings.resize_windows = false
        end

        it "sets the Windows action to :not_modify" do
          expect_select(:windows_actions, :not_modify)

          subject.init
        end
      end
    end
  end

  describe "#store" do
    context "when :not_modify option is selected" do
      before do
        select_widget(:windows_actions, :not_modify)
      end

      it "sets settings.windows_delete_mode to :none" do
        subject.store

        expect(settings.windows_delete_mode).to eq(:none)
      end

      it "sets settings.resize_windows to false" do
        subject.store

        expect(settings.resize_windows).to eq(false)
      end
    end

    context "if :resize option is selected" do
      before do
        select_widget(:windows_actions, :resize)
      end

      it "sets settings.windows_delete_mode to :none" do
        subject.store

        expect(settings.windows_delete_mode).to eq(:none)
      end

      it "sets settings.resize_windows to true" do
        subject.store

        expect(settings.resize_windows).to eq(true)
      end
    end

    context "if :remove option is selected" do
      before do
        select_widget(:windows_actions, :remove)
      end

      it "sets settings.windows_delete_mode to :ondemand" do
        subject.store

        expect(settings.windows_delete_mode).to eq(:ondemand)
      end

      it "sets settings.resize_windows to true" do
        subject.store

        expect(settings.resize_windows).to eq(true)
      end
    end

    context "if :always_remove option is selected" do
      before do
        select_widget(:windows_actions, :always_remove)
      end

      it "sets settings.windows_delete_mode to :all" do
        subject.store

        expect(settings.windows_delete_mode).to eq(:all)
      end
    end
  end
end
