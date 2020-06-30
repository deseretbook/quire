class Quire::Sample
  attr_reader :source, :source_type, :source_epub, :destination
  def initialize(source, options = {})
    @destination = options.delete(:destination)
    @sample_size = (options.delete(:sample_size) || 10).to_i # percent of source
    @source = source
    @source_type = options.delete(:source_type) || detect_source_type(source)

    @source_epub = Quire::Source.build(source, @source_type, options)
    if @source_epub.errors?
      raise "Error loading source '#{source}'(#{source_type}): #{@source_epub.errors.join(', ')}"
    end
  end

  def to_s
    @sample_epub ||= build_sample
  end
  alias :data :to_s

  def write(dest=nil)
    dest ||= destination
    raise ArgumentError, 'destination not specified' if dest.nil?
    File.new(dest, 'w').print(to_s)
    return dest
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
    when 'IO', 'StringIO', 'File', 'Tempfile'
      return :io
    else # assume String
      return :file
    end
  end

  # Loads all file data from the files within source_epub in to a hash keyed
  # by file name (with full path inside zip).
  def all_files_in_source
    @all_files_in_source ||= {}.tap do |h|
      source_epub.entries.map do |fn|
        next if fn.to_s =~ /\/$/ # if last char is '/', it's a dir; skip.
        fd = source_epub.read_file(fn)
        h[fn.to_s] = fd
      end
    end
  end

  # prepend the epub #prefix to path and return it
  def path_in_zip(path)
    [ source_epub.prefix, CGI.unescape(path) ].join('/')
  end

  def nav_point_content_sources
    @nav_point_content_sources ||= source_epub.toc.nav_point_content_sources
  end

  # returns the calculated content size (in bytes) of the sample based on the
  # :sample_size constuctor option, interpreted as a percent of total content
  # size in bytes.
  # 'content' means those pages referenced in the navMap.
  def content_sample_size_in_bytes
    return @content_sample_size_in_bytes if defined?(@content_sample_size_in_bytes)

    # keep track of files already used because they can appear more
    # than once in the navMap section.
    files_processed = []

    total = 0
    nav_point_content_sources.each do |source|
      next if files_processed.include?(source)

      # file referenced in TOC may not actually be in the epub file.
      if all_files_in_source[path_in_zip(source)].nil?
        warn "#content_sample_size_in_bytes: #{path_in_zip(source)} not found in all_files_in_source"
        next
      end

      total += all_files_in_source[path_in_zip(source)].size
    end

    # calculate size of sample based on percent of total
    @content_sample_size_in_bytes = (total * (@sample_size.to_f / 100.0)).to_i
  end

  def opf_xml
    @opf_xml ||= Nokogiri::XML(source_epub.read_file(source_epub.opf_file_path))
  end

  def toc_xml
    @toc_xml ||= Nokogiri::XML(source_epub.read_file(source_epub.toc_file_path))
  end

  # This method is pretty insane spaghetti and needs to be refactored a bunch.
  # My feeling is that there're at least two classes lurking in here that want
  # to be broken out.
  #
  # The operations go like this:
  #
  # Find out how big the sample should be.
  # Find out what "content files" will fit fully in to that size.
  # Find out what "content file" will need to be truncated and truncate it.
  # Remove all the other "content files" data and update XML and HTML links.
  # Find any image files that are now unused and remove them.
  # Return a hash of the data that is to be written in the new sample file.
  # .. the hash is keyed by the full path of each file inside the zip.
  #
  # "Content file" means a file that is referenced in the navMap portion
  # of the TOC file (usually db.ncx).
  #
  # The only reliable tests is the integration test at
  # /spec/integration/quire_spec.rb. Feel free to refactor this method at will
  # but make sure that test _always_passes_.
  def sample_content
    # find what content files will completly fit in the sample-size percentage.
    sample_bytes_allocated = 0

    keep_these_completely = nav_point_content_sources.select do |source|

      # file referenced in TOC may not actually be in the epub file.
      if all_files_in_source[path_in_zip(source)].nil?
        warn "#sample_content A: #{path_in_zip(source)} not found in all_files_in_source"
        next
      end

      if sample_bytes_allocated < content_sample_size_in_bytes
        sample_bytes_allocated += all_files_in_source[path_in_zip(source)].size
        true
      end
    end

    # remove content files that are not in `keep_these_completely` from
    # `all_files_in_source`
    remove_these = nav_point_content_sources - keep_these_completely
    remove_these.map{|r| path_in_zip(r) }.each do |fn|
      if all_files_in_source[fn]
        all_files_in_source.delete(fn)
      else
        warn "#SampleContent B: #{fn} not found in all_files_in_source"
      end
    end

    # find size of partial overrun
    partial_size = sample_bytes_allocated - content_sample_size_in_bytes

    # special case for epubs with only one document in the TOC
    if nav_point_content_sources.length == 1 && sample_bytes_allocated > content_sample_size_in_bytes
      partial_size = content_sample_size_in_bytes
    end

    # find which file will be partially included in sample (if any)
    keep_partial = partial_size > 0 ? keep_these_completely.pop : nil

    if keep_partial
      fn = path_in_zip(keep_partial)

      partial_content = all_files_in_source[fn][0..partial_size]

      # truncate that partial file if there is one, and fix/close HTML tags
      # in the new, shorter file using nokogiri magic:
      # http://nokogiri.org/tutorials/ensuring_well_formed_markup.html
      all_files_in_source[fn] = Nokogiri::XML(partial_content).to_s
    end

    # update sample so TOC (db.ncx) <content> tags have src=“” for removed
    # content
    remove_these.each do |r|
      toc_xml.search('navMap//content').each do |content|
        if remove_these.include?(content['src'])
          content['src'] = ''
        end
      end
    end

    # Parse all remaining html/xhtml pages and find links to removed content
    # and rewrite them to href=""
    all_files_in_source.each do |file_name, file_data|
      # go through each file, see if it contains an href to any of the files
      # previously removed and if found, replace with href=""
      changed = false
      remove_these.each do |r|
        # begin
        #   if (m = file_data.match(/href\s*=\s*['|"]#{r}['|"]/))
        #     changed = true
        #     file_data.gsub!(m[0], 'href=""')
        #   end
        # rescue ArgumentError => excpt
        #   # not a great way to catch this error, but..
        #   if excpt.message =~ /^invalid byte sequence in/
        #     file_data = force_remove_invalid_characters_from_string(file_data)
        #     retry
        #   else
        #     raise
        #   end
        # end
        match_with_encoding_protection(file_data, /href\s*=\s*['|"]#{r}['|"]/) do |m|
          if m
            changed = true
            file_data.gsub!(m[0], 'href=""')
          end
        end
      end
      all_files_in_source[file_name] = file_data if changed
    end

    # iterate over all image/* files in data structure and see if they appear
    # in <img> tags in any of the remaining files.
    images_in_epub = source_epub.opf.all_image_file_names
    images_in_use = []
    images_in_epub.each do |image_file|
      next if images_in_use.include?(image_file)
      all_files_in_source.each do |file_name, file_data|
        # if file_data.match(/src\s*=\s*['|"]#{image_file}['|"]/)
        # permissive matcher to match complicated relative paths.
        # Matches strings like:
        #  <imgANYTHINGimage.png"
        #  <imgANYTHINGimage.png'
        # begin
        #   if file_data.downcase.match(/src\s*=\s*['|"].*#{image_file.downcase}['|"]?/)
        #     images_in_use << image_file
        #     break
        #   end
        # rescue ArgumentError => excpt
        #   # not a great way to catch this error, but..
        #   if excpt.message =~ /^invalid byte sequence in/
        #     file_data = force_remove_invalid_characters_from_string(file_data)
        #     retry
        #   else
        #     raise
        #   end
        # end

        match_with_encoding_protection(file_data, /src\s*=\s*['|"].*#{image_file}['|"]?/i) do |m|
          if m
            images_in_use << image_file
            break
          end
        end
      end
    end

    images_to_remove = images_in_epub - images_in_use

    # this now includes only images that are not referenced anywhere any more
    if images_to_remove.size > 0
      # remove them from the sample data
      images_to_remove.each do |image_file|
        fn = path_in_zip(image_file)
        all_files_in_source.delete(fn)
      end

      # remove them from the manifest
      opf_xml.search('manifest/item').each do |item|
        if images_to_remove.include?(item['href']) && item['media-type'] =~ /^image\//
          item.remove
        end
      end
    end

    # update db.opf to have <item> tags in <manifest> for the removed content
    # to have href=“”
    opf_xml.search('manifest/item').each do |item|
      if remove_these.include?(item['href'])
        item['href'] = ''
      end
    end

    # update db.opf to have <reference> tags in <guide> for the removed
    # content to have href=“”
    opf_xml.search('guide/reference').each do |item|
      if remove_these.include?(item['href'])
        item['href'] = ''
      end
    end

    # write changed opf
    all_files_in_source[source_epub.opf_file_path] = opf_xml.to_s

    #write changed ncx/toc
    all_files_in_source[source_epub.toc_file_path] = toc_xml.to_s

    # return our new files to write to the new epub file
    all_files_in_source
  end

  def epub_files
    @epub_files ||= sample_content
  end

  def build_sample
    stringio = Zip::OutputStream::write_buffer do |zio|
      # write mimetype first
      write_mimetype_to_zip(
        zio, epub_files.delete('mimetype') || raise('mimetype file missing!')
      )

      epub_files.each do |file_name, file_data|
        write_file_to_zip(zio, file_name, file_data)
      end
    end
    stringio.rewind
    stringio.sysread # returns binary data of zip file
  end

  # write mimetype without compression
  def write_mimetype_to_zip(zio, mimetype_data)
    zio.put_next_entry('mimetype', nil, nil, ::Zip::Entry::STORED)
    mimetype_data.strip! if mimetype_data =~ /\n/

    # write miletype file, remove any dangling CRLR/CR's that may have snuck in.
    zio.write mimetype_data.gsub("\r\n",'').gsub("\n", '')
  end

  def write_file_to_zip(zio, file_name, file_data)
    zio.put_next_entry(file_name)
    zio.write file_data
  end

  def match_with_encoding_protection(str, regex)
    # protection against infinite loops
    match_with_encoding_protection_already_tried = false
    begin
      yield str.match(regex)
    rescue ArgumentError => excpt
      # not a great way to catch this specific error, but..
      if excpt.message =~ /^invalid byte sequence in/ && !match_with_encoding_protection_already_tried
        match_with_encoding_protection_already_tried = true
        str = force_remove_invalid_characters_from_string(str)
        retry
      else
        raise
      end
    end
  end

  def force_remove_invalid_characters_from_string(str)
    original_encoding = str.encoding.name
    # encode to 8859 and back to remove invalid characters.
    options = { :invalid => :replace, :undef => :replace, :replace => "?" }
    str.encode("iso-8859-1", options).encode(original_encoding, options)
  end
end
