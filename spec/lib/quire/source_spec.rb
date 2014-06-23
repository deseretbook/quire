require 'spec_helper'

describe Quire::Source do
  subject do
    Quire::Source.new('x', epub_zip: mock_epub_zip)
  end

  let(:mock_epub_zip) do
    double('Zip::File.open(file_path)', file: nil, read: nil, entries: [])
  end

  describe '#error?' do
    it 'returns negative of errors.empty?' do
      expect( subject.errors ).to receive(:empty?).and_return(false)
      expect( subject.error? ).to be_truthy

      expect( subject.errors ).to receive(:empty?).and_return(true)
      expect( subject.error? ).to be_falsey
    end
  end

  describe '#file_exists?' do
    it 'passes arg to #epub_zip.file.exists? and returns result' do
      file = 'x'
      expect( subject.epub_zip.file ).to receive(:exists?).with(file).and_return(true)
      expect( subject.file_exists?(file) ).to be_truthy
    end
  end

  describe '#read_file' do
    it 'passes arg to #epub_zip.read and returns result' do
      file = 'x'
      expect( subject.epub_zip ).to receive(:read).with(file).and_return('xyz')
      expect( subject.read_file(file) ).to eq('xyz')
    end
  end

  describe '#entries' do
    it 'passes arg to #epub_zip.entries and returns result' do
      files = %w[x y z]
      expect( subject.epub_zip ).to receive(:read).with(files).and_return(files)
      expect( subject.read_file(files) ).to eq(files)
    end
  end
end
