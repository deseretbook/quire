class Quire::Source::Filesystem <  Quire::Source
  def initialize(source, options = {})
    super

    if !File.exists?(source)
      add_error("File '#{source}' does not exist")
      return false
    end

    if File.directory?(source)
      add_error("Path '#{source}' is a directory")
      return false
    end

    open_zip_file(source)
  end
end