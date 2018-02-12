require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/mkfs_optiondata"
require "y2partitioner/widgets/mkfs_options"

describe Y2Partitioner::Widgets do
  let(:all_options) { Y2Partitioner::Widgets::MkfsOptiondata.all }

  describe Y2Partitioner::Widgets::MkfsOptiondata do
    subject { all_options }

    it "'widget' references a suitable class" do
      subject.each do |x|
        expect(Object.const_defined?("Y2Partitioner::Widgets::#{x.widget}")).to eq true
      end
    end

    it "'fs' is a list of symbols" do
      subject.each do |x|
        expect(x.fs).to be_a(Array)
        expect(x.fs.find { |fs| fs.class != Symbol }).to be nil
      end
    end

    it "a label exists" do
      subject.each do |x|
        expect(x.widget).not_to be_empty
      end
    end

    it "a help text exists" do
      subject.each do |x|
        expect(x.help).not_to be_empty
      end
    end

    it "a default value is defined" do
      subject.each do |x|
        expect(x.default).not_to be_nil
      end
    end

    it "'validate' references a proc" do
      subject.each do |x|
        expect(x.validate).to be_a(Proc).or be_a(NilClass)
      end
    end

    it "if it can validate there must be an error message" do
      subject.each do |x|
        expect(x.validate ? !x.error.empty? : true).to be true
      end
    end

    it "defines either 'mkfs_option' or 'tune_option'" do
      subject.each do |x|
        expect(x.mkfs_option ? x.tune_option.nil? : !x.tune_option.nil?).to be true
        expect(x.mkfs_option || x.tune_option).not_to be_empty
      end
    end
  end
end
