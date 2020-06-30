require 'spec_helper'

describe Quire::Source::Filesystem do
  let(:path) { '/some/path.epub' }
  let(:options) { {} }
  subject { Quire::Source::Filesystem.new(path, options) }

  describe '.new' do
    context 'source path doesn\'t exist' do
      before { expect( File ).to receive(:exist?).with(path).and_return(false) }
      it 'sets error message' do
        expect( subject.error? ).to be_truthy
        expect( subject.errors ).to include("File '#{path}' does not exist")
      end
    end

    context 'source path is a directory' do
      before { expect( File ).to receive(:exist?).with(path).and_return(true) }
      before { expect( File ).to receive(:directory?).with(path).and_return(true) }
      it 'sets error message' do
        expect( subject.error? ).to be_truthy
        expect( subject.errors ).to include("Path '#{path}' is a directory")
      end
    end
  end
end
