require 'tempfile'
class Quire::Source::Io <  Quire::Source
  def initialize(source, options = {})
    super
    tempfile = Tempfile.new('quire')
    tempfile.write(source.read)
    tempfile.close
    open_zip_file(tempfile.path)
  end
end