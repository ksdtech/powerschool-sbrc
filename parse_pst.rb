require 'nokogiri'

def dquote_escape(s)
  begin
    return s.gsub(/"/){ %q(\") }.gsub(/\n/) { %q(\n) }
  rescue
    STDERR.puts $!
    STDERR.puts s
    exit 2
  end
end

def parse_pst(filename)
  doc = Nokogiri::XML(File.open(filename, 'r:iso-8859-1'))
  doc.root.xpath('//Object').each do |obj|
    typ = obj.at_xpath('Type').content
    lbl = obj.at_xpath('Label').content.gsub(/^\.\d+\./, '')
    p = obj.at_xpath('Page').content
    l = sprintf('%6.3f', obj.at_xpath('Coordinates/Left').content)
    t = sprintf('%6.3f', obj.at_xpath('Coordinates/Top').content)
    case typ
    when /Box/
      r = sprintf('%6.3f', obj.at_xpath('Coordinates/Right').content)
      b = sprintf('%6.3f', obj.at_xpath('Coordinates/Bottom').content)
      puts "@objects << #{typ}.new(#{p}, #{l}, #{t}, #{r}, #{b}, '#{lbl}')"
    when /Line/
      h = 0
      v = 0
      rpt = 0
      r = sprintf('%6.3f', obj.at_xpath('Coordinates/Right').content)
      b = sprintf('%6.3f', obj.at_xpath('Coordinates/Bottom').content)
      rpt_node = obj.at_xpath('Repeat/Multiple')
      if rpt_node
        rpt = rpt_node.content.to_i
        if rpt > 0 
          h = sprintf('%6.3f', obj.at_xpath('Repeat/Offset/Horizontal').content)
          v = sprintf('%6.3f', obj.at_xpath('Repeat/Offset/Vertical').content)
        end
      end
      puts "@objects << #{typ}.new(#{p}, #{l}, #{t}, #{r}, #{b}, '#{lbl}', #{rpt}, #{h}, #{v})"
    when /Picture/
      r = sprintf('%6.3f', obj.at_xpath('Coordinates/Right').content)
      b = sprintf('%6.3f', obj.at_xpath('Coordinates/Bottom').content)
      src = dquote_escape(obj.at_xpath('Picture').content)
      puts "@objects << #{typ}.new(#{p}, #{l}, #{t}, #{r}, #{b}, \"#{src}\", '#{lbl}')"
    when /Text/
      w = sprintf('%6.3f', obj.at_xpath('MaxWidth').content)
      h = sprintf('%6.3f', obj.at_xpath('MaxHeight').content)
      txt = dquote_escape(obj.at_xpath('Body/Text').content)
      f = begin obj.at_xpath('Body/Font/Face').content rescue "Default" end
      s = begin obj.at_xpath('Body/Font/Size').content rescue nil end
      b = begin obj.at_xpath('Body/Font/Bold').content rescue "False" end
      i = begin obj.at_xpath('Body/Font/Italic').content rescue "False" end
      u = begin obj.at_xpath('Body/Font/Underline').content rescue "False" end
      opts = " "
      opts << "face: '#{f}', " if f != "Default" && f != ""
      opts << "size: #{s}, " if s
      opts << "bold: true, " if b == "True"
      opts << "italic: true, " if i == "True"
      opts << "underline: true, " if u == "True"
      puts "@objects << #{typ}.new(#{p}, #{l}, #{t}, #{w}, #{h}, \"#{txt}\", '#{lbl}', {#{opts}})"
    end
  end
end
