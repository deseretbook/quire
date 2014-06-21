require 'spec_helper'

describe 'Full sample generation' do
  before do
    Quire.new(
      fixture_path(fixture_input),
      sample_size: sample_size,
      destination: test_epub_path
    ).write
  end

  let(:fixture_input) { 'full.epub' }
  let(:sample_size) { 10 } # percent, default

  context 'sample size at 10% (default)' do
    it_behaves_like 'the fixture epub', fixture_path('sample_10_pct.epub')
  end

  context 'sample size at 1%' do
    let(:sample_size) { 1 } # percent
    it_behaves_like 'the fixture epub', fixture_path('sample_1_pct.epub')
  end

  context 'source with unused image' do
    let(:fixture_input) { 'full_with_unused_image.epub' }
    it_behaves_like 'the fixture epub', fixture_path('sample_with_unused_image_10_pct.epub')
  end

end