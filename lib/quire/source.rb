class Quire::Source
  attr_reader :errors, :epub_zip

  CONTAINER_PATH = 'META-INF/container.xml'

  def self.build(source, type, options = {})
    case type
    when :file
      Quire::Source::Filesystem.new(source, options)
    when :io
      Quire::Source::Io.new(source, options)
    when :http
      Quire::Source::Http.new(source, options)
    else
      raise ArgumentError, "Unknown source type #{type}"
    end
  end

  def error?
    !errors.empty?
  end
  alias_method :errors?, :error?

  def file_exists?(path)
    epub_zip.file.exists?(path)
  end

  def read_file(path)
    epub_zip.read(path)
  end

  def entries
    epub_zip.entries
  end

  def container
    return @container if defined?(@container)

    raise "Can't find container.xml at '#{CONTAINER_PATH}'" unless file_exists?(CONTAINER_PATH)

    @container = MultiXml.parse(read_file(CONTAINER_PATH))['container']
  end

  def rootfiles
    raise "No <rootfiles> defined in #{CONTAINER_PATH}" unless container['rootfiles']

    # we always want to return an array, so typecheck here
    if container['rootfiles'].kind_of?(Array)
      container['rootfiles']
    else # probably a hash
      [container['rootfiles'][container['rootfiles'].keys.first]]
    end

  end

  def rootfile
    rootfiles.first
  end

  def prefix
    @prefix ||= opf_file_path.split('/').first
  end

  # opf file name with prefix
  def opf_file_path
    @opf_file_path = rootfile['full_path']
  end

  # opf file name without prefix
  def opf_file_name
    @opf_file_name = opf_file_path - "#{prefix}/"
  end

  def opf
    return @opf if defined?(@opf)

    raise "Can't find OPF file at '#{opf_file_path}'" unless
      file_exists?(opf_file_path)

    @opf = Quire::Opf.new(read_file(opf_file_path))
  end

  # ncx file without prefix
  def toc_file_name
    toc_manifest_item['href']
  end

  # ncx file name with prefix
  def toc_file_path
    [ prefix, toc_file_name ].join('/')
  end

  # NOTE: this is the NCX TOC, not the user-readable HTML TOC. For that use #html_toc
  def toc
    @toc ||= Quire::Toc.new(read_file(toc_file_path))
  end

protected

  def initialize(source, options = {})
    # below is usually handled by subclasses calling #open_zip_file
    @epub_zip = options.delete(:epub_zip)
    @errors = []
  end

  def open_zip_file(file_path)
    @epub_zip = Zip::File.open(file_path)
  end

  def add_error(msg)
    @errors << msg
  end

private

  def toc_manifest_item
    opf.find_toc_item || raise('could not find an NCX TOC in OPF manifest')
  end
end