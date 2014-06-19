class Quire::Opf
  def initialize(raw_xml)
    @parsed_opf = MultiXml.parse(raw_xml)
  end

  def package
    @parsed_opf['package']
  end

  def manifest
    package['manifest']
  end

  def manifest_items
    # we always want to return an array, so typecheck here
    if manifest['item'].kind_of? Array
      manifest['item']
    else # hash probably
      [manifest['item'][manifest['item'].keys.first]]
    end
  end

  # Find the toc by finding first package->manifest->item entry if media-type of
  # 'application/x-dtbncx+xml' and id of 'toc'.
  def find_toc_item
    manifest_items.detect do |item|
      item['media_type'] == 'application/x-dtbncx+xml' && item['id'] == 'toc'
    end
  end

  # find all manifest items with media-type of "image/*"
  def find_image_items
    manifest_items.select { |item| item['media_type'] =~ /^image\// }
  end

  # return the file names of all the image files declared in the manifest
  def all_image_file_names
    find_image_items.map{|i|i['href']}.uniq.compact
  end
end
