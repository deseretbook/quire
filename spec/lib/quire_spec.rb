require 'spec_helper'

describe 'Quire' do
  describe '.new' do
    let(:path) { '/path/to/file.epub' }
    let(:options) { {} }
    it 'returns a Quire::Sample object' do
      mock_sample = double(Quire::Sample)
      expect( Quire::Sample ).to receive(:new).with(path, options).and_return(mock_sample)
      expect( Quire.new(path, options) ).to eq(mock_sample)
    end
  end
end