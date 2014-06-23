class Quire::Sample
  attr_reader :source, :source_type, :source_epub, :destination
  def initialize(source, options = {})
    @destination = options.delete(:destination)
    @sample_size = (options.delete(:sample_size) || 10).to_i # percent of source
    @source = source
    @source_type = detect_source_type(source)
    @source_epub = Quire::Source.build(source, @source_type, options)
  end

  def to_s
    @sample_epub ||= build_sample
  end

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
    when 'IO', 'StringIO', 'File'
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
    [ source_epub.prefix, path ].join('/')
  end

  # returns the calculated content size (in bytes) of the sample based on the
  # :sample_size constuctor option, interpreted as a percent of total content
  # size in bytes.
  # 'content' means those pages referenced in the navMap.
  def content_sample_size_in_bytes
    return @content_sample_size_in_bytes if @content_sample_size_in_bytes

    total = 0
    source_epub.toc.nav_point_content_sources.each do |source|
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

  def sample_content
    # find what content files will completly fit in the 10%
    sample_bytes_allocated = 0
    keep_these_completely = source_epub.toc.nav_point_content_sources.select do |source|
      if sample_bytes_allocated <= content_sample_size_in_bytes
        sample_bytes_allocated += all_files_in_source[path_in_zip(source)].size
        true
      end
    end

    # remove content files that are not in `keep_these_completely` from
    # `all_files_in_source`
    remove_these = source_epub.toc.nav_point_content_sources - keep_these_completely
    remove_these.map{|r| path_in_zip(r) }.each do |fn|
      if all_files_in_source[fn]
        all_files_in_source.delete(fn)
      else
        raise "#{fn} not found in all_files_in_source"
      end
    end

    # find size of partial overrun
    partial_size = sample_bytes_allocated - content_sample_size_in_bytes

    # find which file will be partially included in sample (if any)
    keep_partial = partial_size > 0 ? keep_these_completely.pop : nil

    if keep_partial
      fn = path_in_zip(keep_partial)
      # truncate that partial file if there is one, and fix/close HTML tags
      # in the new, shorter file using nokogiri magic:
      # http://nokogiri.org/tutorials/ensuring_well_formed_markup.html
      all_files_in_source[fn] = Nokogiri::XML(
        all_files_in_source[fn][0..partial_size]
      ).to_s
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
        if (m = file_data.match(/href\s*=\s*['|"]#{r}['|"]/))
          changed = true
          #puts "#{file_name}: #{m[0]}"
          file_data.gsub!(m[0], 'href=""')
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
        if (m = file_data.match(/src\s*=\s*['|"]#{image_file}['|"]/))
          #puts "#{file_name}: #{m[0]}"
          images_in_use << image_file
          break
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
    zio.write mimetype_data.strip! # may have dangling crlf
  end

  def write_file_to_zip(zio, file_name, file_data)
    zio.put_next_entry(file_name)
    zio.write file_data
  end
end