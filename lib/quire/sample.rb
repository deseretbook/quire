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

  def sample_content
    # load all files in epub in to data structure
    all_files_in_source = {}.tap do |h|
      source_epub.entries.map do |fn|
        next if fn.to_s =~ /\/$/ # if last char is '/', it's a dir; skip.
        fd = source_epub.read_file(fn)
        h[fn.to_s] = fd 
      end
    end

    # remove trailing crlf from mimetype if necessary;.
    all_files_in_source['mimetype'].strip!

    # total sizes of 'content files' which are those pages referenced by navMap
    total = 0
    source_epub.toc.nav_point_content_sources.each do |source|
      fn = [ source_epub.prefix, source ].join('/')
      total += all_files_in_source[fn].size
    end

    # calculate size of sample based on percent of total
    sample_size = (total * (@sample_size.to_f / 100.0)).to_i
    #puts "Sample size (#{@sample_size}%): #{sample_size}"

    # find what content files will completly fit in the 10%
    allocated = 0
    keep_all = source_epub.toc.nav_point_content_sources.select do |source|
      if allocated <= sample_size
        fn = [ source_epub.prefix, source ].join('/')
        allocated += all_files_in_source[fn].size
        true
      end
    end

    # remove content files that are not in `keep_all` from `all_files_in_source`
    remove = source_epub.toc.nav_point_content_sources - keep_all
    #puts "Files to remove(#{remove.size}): #{remove.join(', ')}"
    remove.each do |r|
      fn = [ source_epub.prefix, r ].join('/')
      if all_files_in_source[fn]
        all_files_in_source.delete(fn)
      else
        raise "#{fn} not found in all_files_in_source"
      end
    end

    # find size of partial overrun
    partial_size = allocated - sample_size

    # find which file will be partially included in sample (if any)
    keep_partial = partial_size > 0 ? keep_all.pop : nil

    #puts sample_size
    #puts allocated
    #puts keep_partial
    #puts partial_size

    if keep_partial
      fn = [ source_epub.prefix, keep_partial ].join('/')
      # truncate that partial file if there is one, and fix/close HTML tags
      # in the new, shorter file.
      # http://nokogiri.org/tutorials/ensuring_well_formed_markup.html
      all_files_in_source[fn] = Nokogiri::XML(all_files_in_source[fn][0..partial_size]).to_s
    end

    opf_xml = Nokogiri::XML(source_epub.read_file(source_epub.opf_file_path))

    # update db.opf to have <item> tags in <manifest> for the missing content to have href=“”
    opf_xml.search('manifest/item').each do |item|
      if remove.include?(item['href'])
        item['href'] = ''
      end
    end

    # update db.opf to have <reference> tags in <guide> for the missing content to have href=“”
    opf_xml.search('guide/reference').each do |item|
      if remove.include?(item['href'])
        item['href'] = ''
      end
    end

    # opf is witten back to the hash later after we remove images

    ncx_xml = Nokogiri::XML(source_epub.read_file(source_epub.toc_file_path))

    # update sample so db.ncx <content> tags have src=“” for missing content

    remove.each do |r|
      ncx_xml.search('navMap//content').each do |content|
        if remove.include?(content['src'])
          content['src'] = ''
        end
      end
    end

    all_files_in_source[source_epub.toc_file_path] = ncx_xml.to_s

    # change entries in the HTML TOC to be href="" or a sample placeholder page
    # (related to above) parse all remaining html pages and find links to removed content and either rewrite them to href="" or a sample placeholder page

    #puts 'fixing broken hrefs'
    all_files_in_source.each do |file_name, file_data|
      # go through each file, see if it contains an href to any of the files
      # previously removed and if found, replace with href=""
      changed = false
      remove.each do |r|
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
    #puts "#{images_in_epub.size} images declared in manifest"
    #puts images_in_epub.inspect
    #puts 'Seeing which ones are no longer referenced'
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

    # this array should now include just images that are not referenced anywhere
    if images_to_remove.size > 0
      #puts "#{images_to_remove.size} images will be removed:"
      #puts images_to_remove.inspect
      # remove the files
      images_to_remove.each do |image_file|
        fn = [ source_epub.prefix, image_file ].join('/')
        all_files_in_source.delete(fn)
      end
      
      # remove them from the manifest
      images_to_remove.each do |image_file|
        fn = [ source_epub.prefix, image_file ].join('/')
        all_files_in_source.delete(fn)
      end

      opf_xml.search('manifest/item').each do |item|
        if images_to_remove.include?(item['href']) && item['media-type'] =~ /^image\//
          item.remove
        end
      end
    else
      #puts 'no ununsed images to remove'
    end

    # write changed opf
    all_files_in_source[source_epub.opf_file_path] = opf_xml.to_s

    # return our new files to write to the new epub file
    all_files_in_source
  end

  def epub_files
    @epub_files ||= sample_content
  end

  def build_sample
    stringio = Zip::OutputStream::write_buffer do |zio|
      # write mimetype first, without compression
      mimetype_file = epub_files.delete('mimetype') || raise('mimetype file missing!')
      # zio.put_next_entry('mimetype')
      zio.put_next_entry('mimetype', nil, nil, ::Zip::Entry::STORED)
      zio.write mimetype_file

      epub_files.each do |fn, d|
        zio.put_next_entry(fn)
        zio.write d
      end
    end
    stringio.rewind
    stringio.sysread # returns binary data of zip file
  end
end