require 'spec_helper'

describe Berkshelf::Formatters::Null do
  before { Berkshelf.set_format(:null) }

  Berkshelf::Formatters::AbstractFormatter.instance_methods.reject { |m| %w(to_s inspect).include?(m.to_s) }.each do |meth|
    it "does not raise an error for :#{meth}" do
      expect {
        subject.send(meth)
      }.to_not raise_error(Berkshelf::AbstractFunction)
    end

    it "returns nil for :#{meth}" do
      expect(subject.send(meth)).to be_nil
    end
  end

  describe '#to_s' do
    it 'includes the class name' do
      expect(subject.to_s).to eq("#<#{described_class}>")
    end
  end

  describe '#inspect' do
    it 'is the same as #to_s' do
      expect(subject.inspect).to eq(subject.to_s)
    end
  end
end
