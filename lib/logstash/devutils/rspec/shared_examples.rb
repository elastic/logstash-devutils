require 'rspec/wait'

RSpec.shared_examples "an interruptible input plugin" do
  # why 3? 2 is not enough, 4 is too much..
  # a plugin that is known to be slower can override
  let(:allowed_lag) { 3 }

  describe "#stop" do
    let(:queue) { SizedQueue.new(20) }
    subject { described_class.new(config) }
    before(:each) { subject.register }

    it "returns from run" do
      consumer_thread = Thread.new(queue) { |queue| loop { queue.pop } }
      plugin_thread = Thread.new(subject, queue) { |subject, queue| subject.run(queue) }
      # the run method is a long lived one, so it should still be running after "a bit"
      sleep 0.5
      expect(plugin_thread).to be_alive
      # now let's actually stop the plugin
      subject.do_stop
      wait(allowed_lag).for { plugin_thread }.to_not be_alive
    end
  end
end
