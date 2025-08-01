#!/usr/bin/env rspec

# Copyright (c) [2018-2022] SUSE LLC
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
require "y2storage/setup_errors_presenter"

describe Y2Storage::SetupErrorsPresenter do
  using Y2Storage::Refinements::SizeCasts

  let(:setup_checker) { instance_double(Y2Storage::SetupChecker) }

  before do
    Y2Storage::StorageManager.create_test_instance
    allow(setup_checker).to receive(:boot_warnings).and_return(boot_errors)
    allow(setup_checker).to receive(:product_warnings).and_return(product_errors)
    allow(setup_checker).to receive(:mount_warnings).and_return(mount_errors)
    allow(setup_checker).to receive(:encryption_warnings).and_return(encryption_errors)
    allow(setup_checker).to receive(:security_policy).and_return(policy)
    allow(setup_checker).to receive(:security_policy_failing_rules).and_return(policy_errors)
    allow(setup_checker).to receive(:errors).and_return(fatal_errors)
    allow(subject).to receive(:with_security_policies).and_return(policy_html)
  end

  subject { described_class.new(setup_checker) }

  let(:boot_errors) { [] }

  let(:fatal_errors) { [] }

  let(:product_errors) { [] }

  let(:mount_errors) { [] }

  let(:encryption_errors) { [] }

  let(:policy) { double("Y2Security::SecurityPolicies::DisaStigPolicy", name: "STIG") }

  let(:policy_errors) { [] }

  let(:policy_html) { "does not comply with the #{policy.name} policy" }

  describe "#to_html" do
    context "when there is no error" do
      let(:boot_errors) { [] }
      let(:product_errors) { [] }
      let(:mount_errors) { [] }
      let(:policy_errors) { [] }
      let(:encryption_errors) { [] }

      it "returns an empty string" do
        expect(subject.to_html).to be_empty
      end
    end

    context "when there are fatal errors" do
      let(:fatal_errors) { [instance_double(Y2Storage::SetupError, message: "fatal error 1")] }

      it "contains messages only for fatal errors" do
        expect(subject.to_html).to match(/fatal error 1/)
      end
    end

    context "when there are errors" do
      let(:boot_error1) { instance_double(Y2Storage::SetupError, message: "boot error 1") }
      let(:boot_error2) { instance_double(Y2Storage::SetupError, message: "boot error 2") }
      let(:product_error1) { instance_double(Y2Storage::SetupError, message: "product error 1") }
      let(:product_error2) { instance_double(Y2Storage::SetupError, message: "product error 2") }
      let(:product_error3) { instance_double(Y2Storage::SetupError, message: "product error 3") }
      let(:mount_error1) { instance_double(Y2Storage::SetupError, message: "missing option 1") }
      let(:encryption_error) do
        instance_double(Y2Storage::SetupError, message: "encryption error")
      end

      let(:policy_errors) { [] }

      let(:boot_errors) { [boot_error1, boot_error2] }
      let(:product_errors) { [product_error1, product_error2, product_error3] }
      let(:mount_errors) { [mount_error1] }
      let(:encryption_errors) { [encryption_error] }

      it "contains a message for each error" do
        expect(subject.to_html.scan(/<li>/).size).to eq(7)
      end

      context "and there are boot errors" do
        let(:boot_errors) { [boot_error1] }
        let(:product_errors) { [] }
        let(:mount_errors) { [] }
        let(:policy_errors) { [] }
        let(:encryption_errors) { [] }

        it "contains a general error message for boot errors" do
          expect(subject.to_html).to match(/not be able to boot/)
        end

        it "does not contain a general error message for product errors" do
          expect(subject.to_html).to_not match(/could not work/)
        end

        it "does not contain a general error message for product errors" do
          expect(subject.to_html).to_not match(/mount point during boot/)
        end

        it "does not contain a general error message for policy errors" do
          expect(subject.to_html).to_not match(/does not comply with the STIG policy/)
        end

        it "does not contain a general error message for encryption errors" do
          expect(subject.to_html).to_not match(/problems while encrypting devices/)
        end
      end

      context "and there are product errors" do
        let(:boot_errors) { [] }
        let(:product_errors) { [product_error1] }
        let(:mount_errors) { [] }
        let(:policy_errors) { [] }
        let(:encryption_errors) { [] }

        it "contains a general error message for product errors" do
          expect(subject.to_html).to match(/could not work/)
        end

        it "does not contain a general error message for boot errors" do
          expect(subject.to_html).to_not match(/not be able to boot/)
        end

        it "does not contain a general error message for mount errors" do
          expect(subject.to_html).to_not match(/mount point during boot/)
        end

        it "does not contain a general error message for policy errors" do
          expect(subject.to_html).to_not match(/does not comply with the STIG policy/)
        end

        it "does not contain a general error message for encryption errors" do
          expect(subject.to_html).to_not match(/problems while encrypting devices/)
        end
      end

      context "and there are mount errors" do
        let(:boot_errors) { [] }
        let(:product_errors) { [] }
        let(:mount_errors) { [mount_error1] }
        let(:policy_errors) { [] }
        let(:encryption_errors) { [] }

        it "contains a general error message for mount errors" do
          expect(subject.to_html).to match(/mount point during boot/)
        end

        it "does not contain a general error message for boot errors" do
          expect(subject.to_html).to_not match(/not be able to boot/)
        end

        it "does not contain a general error message for product errors" do
          expect(subject.to_html).to_not match(/could not work/)
        end

        it "does not contain a general error message for policy errors" do
          expect(subject.to_html).to_not match(/does not comply with the STIG policy/)
        end
      end

      context "and there are policy errors" do
        let(:boot_errors) { [] }
        let(:product_errors) { [] }
        let(:mount_errors) { [] }
        let(:encryption_errors) { [] }
        let(:policy_errors) { [double("Y2Security::SecurityPolicies::Rule")] }

        it "contains a general error message for the policy" do
          expect(subject.to_html).to match(/does not comply with the STIG policy/)
        end

        it "does not contain a general error message for boot errors" do
          expect(subject.to_html).to_not match(/not be able to boot/)
        end

        it "does not contain a general error message for product errors" do
          expect(subject.to_html).to_not match(/could not work/)
        end

        it "does not contain a general error message for mount errors" do
          expect(subject.to_html).to_not match(/mount point during boot/)
        end

        it "does not contain a general error message for encryption errors" do
          expect(subject.to_html).to_not match(/problems while encrypting devices/)
        end
      end

      context "and there are encryption errors" do
        let(:boot_errors) { [] }
        let(:product_errors) { [] }
        let(:mount_errors) { [] }
        let(:encryption_errors) { [encryption_error] }
        let(:policy_errors) { [] }

        it "contains a general error message for encryption" do
          expect(subject.to_html).to match(/problems while encrypting devices/)
        end

        it "contains not a general error message for the policy" do
          expect(subject.to_html).to_not match(/does not comply with the STIG policy/)
        end

        it "does not contain a general error message for boot errors" do
          expect(subject.to_html).to_not match(/not be able to boot/)
        end

        it "does not contain a general error message for product errors" do
          expect(subject.to_html).to_not match(/could not work/)
        end

        it "does not contain a general error message for mount errors" do
          expect(subject.to_html).to_not match(/mount point during boot/)
        end
      end

      context "and there are boot, product, mount errors, encryption errors and policies errors" do
        let(:boot_errors) { [boot_error1] }
        let(:product_errors) { [product_error1] }
        let(:mount_errors) { [mount_error1] }
        let(:encryption_errors) { [encryption_error] }
        let(:policy_errors) { [instance_double(Y2Storage::SetupError, message: "policy error")] }

        it "contains a general error message for boot errors" do
          expect(subject.to_html).to match(/not be able to boot/)
        end

        it "contains a general error message for product errors" do
          expect(subject.to_html).to match(/could not work/)
        end

        it "contains a general error message for mount errors" do
          expect(subject.to_html).to match(/mount point during boot/)
        end

        it "contains a general error message for the policy" do
          expect(subject.to_html).to match(/does not comply with the STIG policy/)
        end

        it "contains a general error message for encryption" do
          expect(subject.to_html).to match(/problems while encrypting devices/)
        end
      end
    end
  end
end
