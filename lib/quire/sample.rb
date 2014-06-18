class Quire::Sample
  attr_reader :source, :source_type
  def initialize(source, options = {})
    @source = source
    @source_type = detect_source_type(source)
  end

private

  def detect_source_type(src)
    case src.class.to_s
    when 'String'
      if src =~ /^https?:\/\//
        return :http
      else
        return :file
      end
    when 'IO', 'StringIO', 'File'
      return :io
    else # assume String
      return :file
    end
  end
end