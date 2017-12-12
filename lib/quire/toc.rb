class Quire::Toc
  def initialize(raw_xml)
    @parsed_toc = MultiXml.parse(raw_xml)
  end

  # returns navMap->navPoints->content_src as array order as in the toc, with
  # anchors ("xxx.html#xyz") removed if they are present. Unique and sorted.
  def nav_point_content_sources
    found_content_sources = []
    find_content_sources(nav_map, found_content_sources)
    found_content_sources.map{|s| s.split('#').first}.compact.uniq
  end

private

  def find_content_sources(node, found = [])
    if node.kind_of? Array
      node.each { |n| find_content_sources(n, found) }
    elsif node.kind_of? Hash
      node.keys.each do |key|
        if key == 'content'
          if node[key].is_a? Array
            found += node[key].map{|n| n['src']}
          else
            found << node[key]['src']
          end
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
