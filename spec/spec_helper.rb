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
end

def fixture_path(filename=nil)
  [ './spec/fixtures', filename ].join('/')
end

def temp_epub_path
  './tmp/rspec_test.epub'
end

# Compare the contents of two epub files. Expect them to be identical.
# Checks file names and paths, and contents.
def expect_epub_contents_to_be_identical(test_epub_path, control_epub_path)
  # expect an 'unzip' command to be present.
  unzip_path = `which unzip` or raise 'could not find an "unzip" command'
  unzip_path.strip!

  # expect an 'md5sum' command to be present.
  md5_path = `which md5` or raise 'could not find an "unzip" command'
  md5_path.strip!

  test_dir = Dir.mktmpdir('epub_test')
  control_dir = Dir.mktmpdir('epub_control')

  `#{unzip_path} #{test_epub_path} -d #{test_dir}`
  `#{unzip_path} #{control_epub_path} -d #{control_dir}`

  files_in_test = Dir.glob([test_dir.to_s, '**', '*'].join('/'))
  files_in_control = Dir.glob([control_dir.to_s, '**', '*'].join('/'))

  it 'has the correct file names of files' do
    expect(
      files_in_test.map{|f|f.sub(test_dir.to_s, '')}
    ).to eq(
      files_in_control.map{|f|f.sub(control_dir.to_s, '')}
    )
  end

  files_in_test.each do |test_file|
    test_md5 = `#{md5_path} -q #{test_file}`.strip
    bare_filename = test_file.sub(test_dir.to_s, '')
    control_md5 = `#{md5_path} -q #{control_dir}/#{bare_filename}`.strip
    it "has the same md5 for file #{bare_filename}" do
      expect(test_md5).to eq(control_md5)
    end
  end
end
