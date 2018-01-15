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
# find current contact information at www.suse.com.

require_relative "test_helper"
require "y2storage"
require "y2partitioner/setup_errors_presenter"

describe Y2Partitioner::SetupErrorsPresenter do
  using Y2Storage::Refinements::SizeCasts

  let(:setup_checker) { instance_double(Y2Storage::SetupChecker) }

  before do
    Y2Storage::StorageManager.create_test_instance
    allow(setup_checker).to receive(:boot_errors).and_return(boot_errors)
    allow(setup_checker).to receive(:product_errors).and_return(product_errors)
  end

  subject { described_class.new(setup_checker) }

  let(:boot_errors) { [] }

  let(:product_errors) { [] }

  describe "#to_html" do
    context "when there is no error" do
      let(:boot_errors) { [] }
      let(:product_errors) { [] }

      it "returns an empty string" do
        expect(subject.to_html).to be_empty
      end
    end

    context "when there are errors" do
      let(:boot_error1) { instance_double(Y2Storage::SetupError, message: "boot error 1") }
      let(:boot_error2) { instance_double(Y2Storage::SetupError, message: "boot error 2") }
      let(:product_error1) { instance_double(Y2Storage::SetupError, message: "product error 1") }
      let(:product_error2) { instance_double(Y2Storage::SetupError, message: "product error 2") }
      let(:product_error3) { instance_double(Y2Storage::SetupError, message: "product error 3") }

      let(:boot_errors) { [boot_error1, boot_error2] }
      let(:product_errors) { [product_error1, product_error2, product_error3] }

      it "contains a message for each error" do
        expect(subject.to_html.scan(/<li>/).size).to eq(5)
      end

      context "and there are boot errors" do
        let(:boot_errors) { [boot_error1] }
        let(:product_errors) { [] }

        it "contains a general error message for boot errors" do
          expect(subject.to_html).to match(/not be able to boot/)
        end

        it "does not contain a general error message for product errors" do
          expect(subject.to_html).to_not match(/could not work/)
        end
      end

      context "and there are product errors" do
        let(:boot_errors) { [] }
        let(:product_errors) { [product_error1] }

        it "contains a general error message for product errors" do
          expect(subject.to_html).to match(/could not work/)
        end

        it "does not contain a general error message for boot errors" do
          expect(subject.to_html).to_not match(/could not load/)
        end
      end

      context "and there are boot and product errors" do
        let(:boot_errors) { [boot_error1] }
        let(:product_errors) { [product_error1] }

        it "contains a general error message for boot errors" do
          expect(subject.to_html).to match(/could not load/)
        end

        it "contains a general error message for product errors" do
          expect(subject.to_html).to match(/could not work/)
        end
      end
    end
  end
end
