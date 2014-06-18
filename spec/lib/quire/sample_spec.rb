require 'spec_helper'

describe 'Quire::Sample' do
  describe '.new' do
    context 'source argument' do
      subject { Quire::Sample.new(source) }
      
      context 'is a filesystem path' do
        let(:source) { '/path/to/file.epub' }
        it 'is recognized' do
          expect( subject.source_type ).to eq(:file)
        end
      end

      context 'is a an http url' do
        let(:source) { 'http://example.com/file.epub' }
        it 'is recognized' do
          expect( subject.source_type ).to eq(:http)
        end
      end

      context 'is a an https url' do
        let(:source) { 'https://example.com/file.epub' }
        it 'is recognized' do
          expect( subject.source_type ).to eq(:http)
        end
      end

      context 'is a File object' do
        let(:source) { File.new('spec/spec_helper.rb', 'r') }
        it 'is recognized' do
          expect( subject.source_type ).to eq(:io)
        end
      end

      context 'is a StringIO object' do
        let(:source) { StringIO.new('data') }
        it 'is recognized' do
          expect( subject.source_type ).to eq(:io)
        end
      end

    end
  end
end