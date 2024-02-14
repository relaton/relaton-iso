describe RelatonIso::Queue do
  context "#queue" do
    before { allow(File).to receive(:exist?).and_call_original }

    it "open file" do
      expect(File).to receive(:exist?).with("iso-queue.txt").and_return true
      expect(File).to receive(:read).with("iso-queue.txt").and_return "item1\nitem2"
      expect(subject.queue).to eq %w[item1 item2]
    end

    it "file not exist" do
      expect(File).to receive(:exist?).with("iso-queue.txt").and_return false
      expect(subject.queue).to eq []
    end
  end

  context "#add_first" do
    it "add" do
      subject.instance_variable_set(:@queue, %w[item1 item2])
      expect(subject.add_first("item3")).to eq %w[item3 item1 item2]
    end

    # it "move" do
    #   subject.instance_variable_set(:@queue, %w[item1 item2])
    #   expect(subject.add_first("item2")).to eq %w[item2 item1]
    # end
  end

  context "#move_last" do
    it "add" do
      subject.instance_variable_set(:@queue, %w[item1 item2])
      expect(subject.move_last("item3")).to eq %w[item1 item2 item3]
    end

    it "move" do
      subject.instance_variable_set(:@queue, %w[item1 item2])
      expect(subject.move_last("item1")).to eq %w[item2 item1]
    end
  end

  # it "#take_first" do
  #   subject.instance_variable_set(:@queue, %w[item1 item2])
  #   expect(subject.take_first).to eq "item1"
  #   expect(subject.instance_variable_get(:@queue)).to eq %w[item2]
  # end

  it "#save" do
    subject.instance_variable_set(:@queue, %w[item1 item2])
    expect(File).to receive(:write).with("iso-queue.txt", "item1\nitem2")
    subject.save
  end
end
