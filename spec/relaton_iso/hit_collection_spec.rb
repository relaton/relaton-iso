describe RelatonIso::HitCollection do
  subject { described_class.new :ref }

  context "#pubid_match?" do
    it "rescue error" do
      expect(Pubid::Iso::Identifier).to receive(:create).and_raise StandardError
      expect do
        subject.pubid_match?({})
      end.to output(/\[relaton-iso\] WARN: \(ref\) StandardError/).to_stderr_from_any_process
    end
  end
end
