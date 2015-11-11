#!/usr/bin/env rspec

require_relative "spec_helper"
require "storage/storage_proposal"
require "pp"


describe Yast::Storage::Proposal do

  before (:all) do
    # nothing so far
  end

  describe "constructed empty" do
    it "should return a clear 'empty' message" do
      proposal = Yast::Storage::Proposal.new
      expect( proposal.propose.downcase ).to include "no disks found"
    end
  end

end
