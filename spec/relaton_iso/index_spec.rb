# describe RelatonIso::Index do
#   it "initializes" do
#     expect(subject).to be_instance_of described_class
#     expect(subject.instance_variable_get(:@file)).to be_nil
#   end

#   context "instance methods" do
#     it "index" do
#       expect(subject).to receive(:read_index).and_return :index
#       expect(subject.index).to eq :index
#     end

#     context "[]=" do
#       let(:doc) do
#         docid = double("docid", id: "123", primary: true)
#         title = double("title", title: double("content", content: "Title"))
#         double "doc", docidentifier: [docid], title: [title]
#       end

#       it "adds index entry" do
#         allow(subject).to receive(:read_index).and_return []
#         subject << doc
#         expect(subject.instance_variable_get(:@index)).to eq [{ id: "123", title: "Title" }]
#       end

#       it "updates index entry" do
#         allow(subject).to receive(:read_index).and_return [{ id: "123", title: "Old Title" }]
#         subject << doc
#         expect(subject.instance_variable_get(:@index)).to eq [{ id: "123", title: "Title" }]
#       end
#     end

#     context "[]" do
#       before do
#         subject.instance_variable_set(:@index, [{ id: "123", title: "Title" }])
#       end

#       it "fetches document from index by ID" do
#         expect(subject["123"]).to eq id: "123", title: "Title"
#       end

#       it "returns nil if document is not found" do
#         expect(subject["456"]).to be_nil
#       end
#     end

#     it "save" do
#       allow(subject).to receive(:read_index).and_return [{ id: "123", title: "Title" }]
#       subject.instance_variable_set(:@file, "file.yaml")
#       file = double "file"
#       expect(file).to receive(:puts).with("---")
#       expect(file).to receive(:puts).with("id: '123'\ntitle: Title\n")
#       expect(File).to receive(:open).with("file.yaml", "w:UTF-8").and_yield file
#       subject.save
#     end

#     context "read_index" do
#       it "reads index from file" do
#         subject.instance_variable_set(:@file, "file.yaml")
#         expect(File).to receive(:exist?).with("file.yaml").and_return true
#         expect(subject).to receive(:read_file).and_return :index
#         expect(subject.send(:read_index)).to eq :index
#       end

#       it "creates empty index if file doesn't exist" do
#         subject.instance_variable_set(:@file, "file.yaml")
#         expect(File).to receive(:exist?).with("file.yaml").and_return false
#         expect(subject.send(:read_index)).to eq []
#       end

#       it "returns nil if file is undefined" do
#         expect(subject.send(:read_index)).to be_nil
#       end
#     end

#     context "read_from_user_dir" do
#       let(:file) { File.join(Dir.home, "index.yml") }

#       before do
#         subject.instance_variable_set(:@file, "file.yaml")
#       end

#       it "reads index from file" do
#         expect(File).to receive(:exist?).with(file).and_return true
#         expect(subject).to receive(:outdated?).and_return false
#         expect(subject).to receive(:read_file).and_return :index
#         expect(subject.send(:read_from_user_dir)).to eq :index
#       end

#       it "not read index if file doesn't exist" do
#         expect(File).to receive(:exist?).with(file).and_return false
#         expect(subject).not_to receive(:outdated?)
#         expect(subject.send(:read_from_user_dir)).to be_nil
#       end

#       it "not read index if file is outdated" do
#         expect(File).to receive(:exist?).with(file).and_return true
#         expect(subject).to receive(:outdated?).and_return true
#         expect(subject.send(:read_from_user_dir)).to be_nil
#       end
#     end

#     it "read_file" do
#       subject.instance_variable_set(:@file, "file.yaml")
#       expect(File).to receive(:read).with("file.yaml", encoding: "UTF-8").and_return :yaml
#       expect(RelatonBib).to receive(:parse_yaml).with(:yaml, [], symbolize_names: true).and_return :index
#       expect(subject.send(:read_file)).to eq :index
#     end

#     context "outdated?" do
#       before do
#         subject.instance_variable_set(:@file, "file.yaml")
#       end

#       it "returns true if file is older than 1 day" do
#         expect(File).to receive(:mtime).with("file.yaml").and_return Time.now - (48 * 3600)
#         expect(subject.send(:outdated?)).to be true
#       end

#       it "returns false if file is younger than 1 day" do
#         expect(File).to receive(:mtime).with("file.yaml").and_return Time.now - (12 * 3600)
#         expect(subject.send(:outdated?)).to be false
#       end
#     end

#     context "fetch_index" do
#       it "success" do
#         url = "https://raw.githubusercontent.com/relaton/relaton-data-iso/master/iso/index.zip"
#         uri = double "uri"
#         expect(uri).to receive(:open).and_return :body
#         expect(subject).to receive(:URI).with(url).and_return uri
#         zip = double "zip"
#         expect(zip).to receive_message_chain(:get_next_entry, :get_input_stream, :read).and_return :yaml
#         expect(Zip::InputStream).to receive(:new).with(:body).and_return zip
#         expect(RelatonBib).to receive(:parse_yaml).with(:yaml, [], symbolize_names: true).and_return :index
#         expect(subject).to receive(:serialize_and_save).with(:index)
#         expect(subject.send(:fetch_index)).to eq :index
#       end

#       it "fails" do
#         expect(subject).to receive_message_chain(:URI, :open).and_raise OpenURI::HTTPError.new("404", nil)
#         expect do
#           expect(subject.send(:fetch_index)).to eq []
#         end.to output(/failed to fetch index: 404/).to_stderr
#       end
#     end
#   end
# end
