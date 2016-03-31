require 'spec_helper'

describe AttachFilesToWorkJob do
  context "happy path" do
    let(:file1) { File.open(fixture_path + '/world.png') }
    let(:file2) { File.open(fixture_path + '/image.jp2') }
    let(:uploaded_file1) { UploadedFile.create(file: file1) }
    let(:uploaded_file2) { UploadedFile.create(file: file2) }
    let(:generic_work) { create(:public_generic_work) }

    it "attaches files and copies visibility" do
      expect(CharacterizeJob).to receive(:perform_later).twice
      described_class.perform_now(generic_work, [uploaded_file1, uploaded_file2])
      generic_work.reload
      expect(generic_work.file_sets.count).to eq 2
      expect(generic_work.file_sets.map(&:visibility)).to all(eq 'open')
    end
  end
end
