require 'test_helper'

describe Expedite::Env do
  let(:env) { Expedite::Env.new }

  describe "#root" do
    subject { env.root }

    it "should default to Dir.pwd" do
      assert subject == Dir.pwd
    end
  end

  describe "#tmp_path" do
    subject { env.tmp_path }

    it "should succeed" do
      subject
    end
  end
end
