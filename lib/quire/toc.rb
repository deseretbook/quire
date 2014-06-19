class Quire::Toc
  def initialize(raw_xml)
    @parsed_toc = MultiXml.parse(raw_xml)
  end

  # returns navMap->navPoints->content_src as array order as in the toc
  def nav_point_content_sources
    found_content_sources = []
    find_content_sources(nav_map, found_content_sources)
    found_content_sources.uniq.compact
  end

private

  def find_content_sources(node, found = [])
    if node.kind_of? Array
      node.each { |n| find_content_sources(n, found) }
    elsif node.kind_of? Hash
      node.keys.each do |key|
        if key == 'content'
          found << node[key]['src']
        else
          find_content_sources(node[key], found)
        end
      end
    end
    found
  end

  def nav_map
    ncx['navMap']
  end

  def ncx
    @parsed_toc['ncx']
  end
end