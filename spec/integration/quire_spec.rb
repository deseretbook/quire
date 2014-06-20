require 'spec_helper'

describe 'Full sample generation' do
  let(:sample_size) { 10 }
  let(:fixture_input) { 'full.epub' }

  subject { Quire.new(fixture_path(fixture_input), sample_size: sample_size) }

  before { subject.write(temp_epub_path) }

  context 'sample size at 10%' do
    # let(:expected_sample_ouput) { 'sample_10_pct.epub' }

    expect_epub_contents_to_be_identical(
      temp_epub_path,
      fixture_path('sample_10_pct.epub')
    )
  end
end