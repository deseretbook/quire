require 'spec_helper'

describe Quire::Sample do
  subject { Quire::Sample.new( '/some.epub' ) }

  let(:mock_quire_source) { double(Quire::Source, errors?: false) }

  before do
    expect(Quire::Source).to(receive(:build)).and_return(mock_quire_source)
  end

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

  describe '#write' do

    RSpec.shared_examples 'a successful #write() call' do
      let(:destination) { 'xyz' }
      let(:epub_data) { 'epub data' }
      let(:mock_filehandle) { double(File) }

      before do
        expect( File ).to receive(:new).with(destination, 'w').and_return(mock_filehandle)
        expect( subject ).to receive(:to_s).and_return( epub_data )
        expect( mock_filehandle).to receive(:print).with(epub_data)
      end
      it 'writes output of #to_s to destination path' do
        subject.write( destination )
      end

      it 'returns destination path' do
        expect( subject.write( destination ) ).to eq( destination )
      end
    end
    
    context 'no destination argument passed' do
      context 'no destination passed in constuctor' do
        before do
          expect( subject.destination ).to be_nil
          expect( File ).to_not receive(:new)
        end

        it 'raises exception' do
          expect( lambda { subject.write(nil) } ).to raise_exception(ArgumentError)
        end
      end
      context 'destination passed in constuctor' do
        it_behaves_like 'a successful #write() call'
      end
    end
    
    context 'destination argument passed' do
      it_behaves_like 'a successful #write() call'
    end
  end

  describe '#to_s' do
    it 'returns outout from #build_sample' do
      build_sample_output = 'epub data'
      expect( subject ).to receive(:build_sample).and_return(build_sample_output)
      expect( subject.to_s ).to eq( build_sample_output )
    end
  end
end
