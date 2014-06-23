require 'quire'

RSpec.configure do |config|
  config.order = :random

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect

    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended.
    mocks.verify_partial_doubles = true
  end

  config.after(:suite) do
    # delete the tempfile
    FileUtils.rm test_epub_path
  end

end

def fixture_path(filename=nil)
  [ './spec/fixtures', filename ].join('/')
end

def test_epub_path
  './tmp/rspec_test.epub'
end

# Compare the contents of two epub files. Expect them to be identical.
# Checks file names and paths, and contents.
shared_examples_for 'the fixture epub' do |control_epub_path|
  # add path to the filename
  control_epub_path = fixture_path(control_epub_path)

  # expect an 'unzip' command to be present.
  let!(:unzip_path) do
    (`which unzip` or raise 'could not find an "unzip" command').strip
  end

  # expect an 'md5sum' command to be present.
  let!(:md5_path) do
    (`which md5` or raise 'could not find an "unzip" command').strip
  end

  let!(:test_dir) { Dir.mktmpdir("epub_test") }
  let!(:control_dir) { Dir.mktmpdir("epub_control") }

  before do
    `#{unzip_path} #{test_epub_path} -d #{test_dir}`
    `#{unzip_path} #{control_epub_path} -d #{control_dir}`
  end

  let(:files_in_test) { Dir.glob([test_dir.to_s, '**', '*'].join('/')) }
  let(:files_in_control) { Dir.glob([control_dir.to_s, '**', '*'].join('/')) }

  it 'has the correct file names of files' do
    expect(
      files_in_test.map{|f|f.sub(test_dir.to_s, '')}.sort
    ).to eq(
      files_in_control.map{|f|f.sub(control_dir.to_s, '')}.sort
    )
  end

  # I really wanted to make these file comparison tests dynamic, where an
  # example was created for each comparison. Turns out that it's really hard
  # to dynalically add examples at runtime after all. So, intead, you get
  # the ugliness below. I'm sorry.

  it 'has matching file checksums' do
    files_in_test.each do |test_file|
      next if File.directory?(test_file)
      test_md5 = `#{md5_path} -q #{test_file}`.strip
      bare_filename = test_file.sub(test_dir.to_s, '')
      control_md5 = `#{md5_path} -q #{control_dir}#{bare_filename}`.strip

      expect(test_md5).to eq(control_md5), "Checksum missmatch for #{bare_filename}"
    end
  end

end
