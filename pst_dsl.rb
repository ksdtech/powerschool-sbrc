require 'csv'
require 'nokogiri'

$the_report = nil

def round_num(n)
  sprintf("%.03f", n).gsub(/\.000$/, '')
end

class Box
  def initialize(p, l, t, r, b, lbl="Box", opts={})
    @p = p
    @l = l
    @t = t
    @r = r
    @b = b
    @lbl = lbl
    @opts = opts
  end
  
  def build(xml, obj_no)
    xml.Type "Box"
    xml.Label sprintf(".%03d.#{@lbl}", obj_no)
    xml.Page @p
    xml.Layer @opts[:layer] ? @opts[:layer] : 0
    xml.Repeat {
      xml.Multiple 0
      xml.Offset {
        xml.Horizontal 0
        xml.Vertical 0
      }
    }
    xml.Rotation 0
    xml.Coordinates {
      xml.Left round_num(@l)
      xml.Top round_num(@t)
      xml.Right round_num(@r)
      xml.Bottom round_num(@b)
    }
    xml.Line {
      xml.Width "0.5"
      xml.Style 1
      xml.Color "Black"
      xml.Tint 100
    }
    xml.CornerRadius 0
    if @opts[:fill]
      xml.Fill {
        xml.Color @opts[:fill]
        xml.Tint 100
      }
    end
  end
end

class Line
  def initialize(p, l, t, r, b, lbl="Line", rpt=0, h=0, v=0)
    @p = p
    @l = l
    @t = t
    @r = r
    @b = b
    @lbl = lbl
    @rpt = rpt
    @h = h
    @v = v
  end
  
  def build(xml, obj_no)
    xml.Type "Line"
    xml.Label sprintf(".%03d.#{@lbl}", obj_no)
    xml.Page @p
    xml.Layer 0
    xml.Repeat {
      xml.Multiple @rpt
      xml.Offset {
        xml.Horizontal round_num(@h)
        xml.Vertical round_num(@v)
      }
    }
    xml.Rotation 0
    xml.Coordinates {
      xml.Left round_num(@l)
      xml.Top round_num(@t)
      xml.Right round_num(@r)
      xml.Bottom round_num(@b)
    }
    xml.Line {
      xml.Width "0.5"
      xml.Style 1
      xml.Color "Black"
      xml.Tint 100
    }
  end
end

class Picture
  def initialize(p, l, t, r, b, src, lbl="Picture")
    @p = p
    @l = l
    @t = t
    @r = r
    @b = b
    @src = src
    @lbl = lbl
  end

  def build(xml, obj_no)
    xml.Type "Picture"
    xml.Label sprintf(".%03d.#{@lbl}", obj_no)
    xml.Page @p
    xml.Layer 0
    xml.Repeat {
      xml.Multiple 0
      xml.Offset {
        xml.Horizontal 0
        xml.Vertical 0
      }
    }
    xml.Rotation 0
    xml.ScalingOption "shrink"
    xml.Coordinates {
      xml.Left round_num(@l)
      xml.Top round_num(@t)
      xml.Right round_num(@r)
      xml.Bottom round_num(@b)
    }
    xml.Picture @src
  end
end

class Text
  def initialize(p, l, t, w, h, txt, lbl="Text", opts={bold: false})
    @p = p
    @l = l
    @t = t
    @w = w
    @h = h
    @txt = txt
    @lbl = lbl
    @opts = opts
  end
  
  def build(xml, obj_no)
    xml.Type "Text"
    xml.Label sprintf(".%03d.#{@lbl}", obj_no)
    xml.Page @p
    xml.Layer @opts[:layer] ? @opts[:layer] : 0
    xml.Rotation 0
    xml.Coordinates {
      xml.Left round_num(@l)
      xml.Top round_num(@t)
    }
    xml.Line {
      xml.Width "0.5"
      xml.Style 1
      xml.Color "Black"
      xml.Tint 100
    }
    xml.MaxWidth round_num(@w)
    xml.MaxHeight round_num(@h)
    xml.Frame {
      xml.Width 0
      xml.Padding 0
      xml.Radius 0
    }
    xml.Fill {
      xml.Color "Black"
      xml.Tint 100
    }
    xml.Body {
      xml.Font {
        xml.Face @opts[:face] ? @opts[:face] : "Default"
        xml.Size @opts[:size] if @opts[:size]
        xml.Bold @opts[:bold] ? "True" : "False"
        xml.Italic @opts[:italic] ? "True" : "False"
        xml.Underline @opts[:underline] ? "True" : "False"
      }
      xml.Text @txt
    }
    xml.Special {
      xml.MoveToNextRecord "False"
    }
  end
end

class Report
  attr_accessor :box
  
  BOX_LEFT = 0
  BOX_TOP = 1
  BOX_RIGHT = 2
  BOX_BOTTOM = 3
  
  def initialize(filename, ps_name, title)
    @filename = filename
    @ps_name = ps_name
    @title = title
    @objects = [ ]
    @page_tops = [ 2.2, 0.6 ]
    @page = 1
    @column = 1
    @box = nil
    @box_trimesters = true
    @box_first = true
    @box_standards = nil
    @comment_std = nil
    @grade_scale = false
    @comment_height = 1.8
    @caption_char_widths = [ [ 48, 92-48 ], [ 40, 80-40 ] ]
    @p_height   = 0.2
    @br_height  = 0.17
    @text_bias  = [ 0.05, 0.12 ]
    @col_tops   = [ @page_tops[0], @page_tops[0] ]
    @col_lefts  = [ 0.5,   4.375 ]
    @column_width  = 3.625
    @grade_width = 0.25
    @caption_width = @column_width - (3 * @grade_width)
    @caption_maxw  = @caption_width - @text_bias[0]
    @supp_caption_width = @column_width - 1.5
    @supp_caption_maxw = @supp_caption_width - @text_bias[0]
    @standards = { }
    @standards_by_course = { }
    @standards_by_parent = { }
    read_standards
  end
  
  def pst_output
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.PSReportTemplate {
        xml.FileHeader {
          xml.Created "Friday, October 4, 2013 9:20:54 AM"
          xml.PSVersion "(VisualPST 2.1)"
          xml.TemplateVersion "1.0"
          xml.Author "Peter Zingg"
        }
        xml.ReportHeader {
          xml.Type "Object Report"
          xml.Name @ps_name
          xml.Table "Students"
        }
        xml.ReportData {
          xml.Units "Inches"
          xml.Paper {
            xml.Size "Letter"
            xml.Width 8.5
            xml.Height 11
            xml.Orientation "Portrait"
            xml.Margins {
              xml.Left 0.5
              xml.Top 0.5
              xml.Right 0.5
              xml.Bottom 0.5
            }
            xml.Scale 100
          }
          xml.Body {
            xml.Font {
              xml.Face "Helvetica"
              xml.Size 9
              xml.Leading 10
            }
          }
        }
        xml.ObjectData {
          xml.Type "Objects"
          @objects.each_with_index do |obj, i|
            obj_no = i + 1
            xml.Object(no: obj_no) {
              obj.build(xml, obj_no)
            }
          end
        }
      }
    end

    # Don't write whole document. PowerSchool chokes on
    # <xml> declaration
    File.open(@filename, "w") do |f|
      builder.doc.root.write_to(f)
    end
  end
  
  def pst_page(page_no)
    page(page_no)
    yield self
  end

  def pst_grid(col_no)
    open_box(col_no)
    yield self
    close_box
  end

  def pst_title(*cols)
    title(*cols)
  end

  def pst_attendance(col_no)
    open_box(col_no)
    title('ATTENDANCE')
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_TOP], @box[BOX_RIGHT], @box[BOX_TOP])
    s = 'Days absent'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @caption_maxw, maxh, s, "Absent.Name")
    t1c = round_num(@box[BOX_LEFT] + @caption_width + 0.5 * @grade_width)
    t2c = round_num(@box[BOX_LEFT] + @caption_width + 1.5 * @grade_width)
    t3c = round_num(@box[BOX_LEFT] + @caption_width + 2.5 * @grade_width)
    @objects << Text.new(@page, @box[BOX_LEFT] + @caption_width, @box[BOX_BOTTOM] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(daily.att.count;;A,E,X,S;T1)<tabc #{t2c}>^(daily.att.count;;A,E,X,S;T2)<tabc #{t3c}>^(daily.att.count;;A,E,X,S;T3)", "Absent.T123", { bold: true })
    @box[BOX_BOTTOM] += h
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    s = 'Days tardy'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @caption_maxw, maxh, s, "Tardy.Name")
    @objects << Text.new(@page, @box[BOX_LEFT] + @caption_width, @box[BOX_BOTTOM] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(daily.att.count;;T,U,L;T1)<tabc #{t2c}>^(daily.att.count;;T,U,L;T2)<tabc #{t3c}>^(daily.att.count;;T,U,L;T3)", "Tardy.T123", { bold: true })
    @box[BOX_BOTTOM] += h
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    close_box
  end

  def pst_supplemental(col_no)
    open_box(col_no)
    title('SUPPLEMENTAL PROGRAMS', '')
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_TOP], @box[BOX_RIGHT], @box[BOX_TOP])
    t1l = @box[BOX_LEFT] + @supp_caption_width + @text_bias[0]
    s = 'English Language Learning - Language Proficiency Level'
    maxh = h = @p_height + @br_height
    maxw = @column_width - @supp_caption_width - @text_bias[0]
    @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @supp_caption_maxw, maxh, s, "ELProf.Name")
    @objects << Text.new(@page, t1l, @box[BOX_BOTTOM] + @text_bias[1], maxw, maxh, "^(KSD_EL_Proficiency)", "ELProf.Score", { bold: true })
    @box[BOX_BOTTOM] += h
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    s = 'Resource Specialist'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @caption_maxw, maxh, s, "RSP.Name")
    @objects << Text.new(@page, t1l, @box[BOX_BOTTOM] + @text_bias[1], 0, 0, "^(CA_PrimDisability;if.not.blank.then=X)", "504.Value", { bold: true })
    @box[BOX_BOTTOM] += h
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    s = '504'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @caption_maxw, maxh, s, "504.Name")
    @objects << Text.new(@page, t1l, @box[BOX_BOTTOM] + @text_bias[1], 0, 0, "^(CA_SpEd504;if.1.then=X)", "504.Value", { bold: true })
    @box[BOX_BOTTOM] += h
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    s = 'Modifications'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @caption_maxw, maxh, s, "Modifications.Name")
    @box[BOX_BOTTOM] += h
    @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    @objects << Line.new(@page, @box[BOX_LEFT] + @supp_caption_width, @box[BOX_TOP], @box[BOX_LEFT] + @supp_caption_width, @box[BOX_BOTTOM])
    @box_trimesters = false
    close_box
  end
  
  def pst_standards(*groups)
    @box_standards = groups
    @box_standards.each do |std_filter|
      filters = std_filter.split('|')
      parent = filters.shift
      std = @standards[parent]
      if !std
        raise "no such standard '#{parent}'"
      end
      if !@standards_by_parent[parent] || @standards_by_parent[parent].empty?
        raise "no standards for parent '#{parent}'"
      end
      
      box_top_line
      maxh, h = line_height(std[:name], true)
      t1c = round_num(@box[BOX_LEFT] + @caption_width + 0.5 * @grade_width)
      t2c = round_num(@box[BOX_LEFT] + @caption_width + 1.5 * @grade_width)
      t3c = round_num(@box[BOX_LEFT] + @caption_width + 2.5 * @grade_width)
      
      unless filters.include?('noheader')
        @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @caption_maxw, maxh, std[:name], "#{parent}.Name", { layer: 2, bold: true })
        @objects << Box.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM]+h, "#{parent}.Box", { layer: 1, fill: "#CCCCCC" })
        @box[BOX_BOTTOM] += h
      end
      
      @standards_by_parent[parent].each do |id|
        std = @standards[id]
        maxh, h = line_height(std[:name], false)
        @objects << Text.new(@page, @box[BOX_LEFT] + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], @caption_maxw, maxh, std[:name], "#{id}.Name")
        @objects << Text.new(@page, @box[BOX_LEFT] + @caption_width, @box[BOX_BOTTOM] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(*std.stored.transhigh;#{id};T1)<tabc #{t2c}>^(*std.stored.transhigh;#{id};T2)<tabc #{t3c}>^(*std.stored.transhigh;#{id};T3)", "#{id}.T123", { bold: true })
        @box[BOX_BOTTOM] += h
        @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
      end
    end
  end
  
  def pst_grade_scale(col_no)
    open_box(col_no)
    @grade_scale = true
    @box_trimesters = false
    yield self
    close_box
  end
  
  def pst_text(*lines)
    if @grade_scale
      lines.each_with_index do |title, i|
        if i > 0
          @box[BOX_BOTTOM] += @br_height
        end
        @objects << Text.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM] + @text_bias[1], @column_width, @p_height, title, "GS.#{i+1}")
      end
    end
    @box[BOX_BOTTOM] += @p_height
    @box[BOX_TOP] = @box[BOX_BOTTOM]
  end
  
  def pst_comment(comments, height=1.8)
    @comment_std = comments
    @comment_height = height
  end
    
  protected
    
  def line_count(s, bold)
    widths_table = @caption_char_widths[bold ? 1 : 0]
    base = widths_table[0]
    incr = widths_table[1]
    l = s.length
    n = l <= base ? 1 : ((s.length - base + incr) / incr).floor + 1
    return n
  end
  
  def line_height(s, bold)
    n    = line_count(s, bold)
    maxh = @p_height + (n-1) * @br_height
    h    = maxh
    return [maxh, h]
  end
  
  def read_standards(filename='standards.txt')
    CSV.foreach(filename, col_sep: "\t", row_sep: "\n", headers: true,
      header_converters: :symbol) do |row|
      h  = row.to_hash
      id = h[:identifier]
      @standards[id] = h
      courses = h[:courses]
      if courses
        courses.split(',').each do |course|
          @standards_by_course[course] = [ ] if !@standards_by_course.key?(course)
          @standards_by_course[course] << id
        end
      end
      parent = h[:listparent]
      if parent
        @standards_by_parent[parent] = [ ] if !@standards_by_parent.key?(parent)
        @standards_by_parent[parent] << id
      end
    end
    @standards_by_parent.keys.each do |parent|
      @standards_by_parent[parent].sort! { |a,b| @standards[a][:sortorder] <=> @standards[b][:sortorder] }
    end
  end
    
  def page(page_no)
    @page = page_no
    if @page == 1
      @objects << Picture.new(@page,  0.556,  0.500,  1.612,  2.000, "KSDLogo.jpg", "Picture")
      @objects << Text.new(@page,  1.600,  0.778,  0,  0, "<tabc 4.25>Kentfield School District", "Kentfield School District", {  })
      @objects << Text.new(@page,  1.600,  0.944,  0,  0, "<tabc 4.25>" + @title, @title, { size: 11, bold: true,  })
      @objects << Text.new(@page,  1.600,  1.111,  0,  0, "<tabc 4.25>Bacich Elementary School - Sally Peck, Principal", "Bacich", {  })
      @objects << Text.new(@page,  1.600,  1.278,  0,  0, "<tabc 4.25>School Year 2013-2014", "School Year", {  })
      @objects << Text.new(@page,  1.600,  1.500,  0,  0, "Student Name: ^(First_Name) ^(Middle_Name) ^(Last_Name)\nTeacher: ^(HomeRoom_TeacherFirst) ^(HomeRoom_Teacher)", "Student Name", { size: 9, bold: true })
      @col_tops = [ @page_tops[0], @page_tops[0] ]
    else
      @col_tops = [ @page_tops[1], @page_tops[1] ]
    end
    open_box(1)
  end
  
  def open_box(col_no)
    @column = col_no
    i = @column - 1
    @box = [ @col_lefts[i], @col_tops[i], @col_lefts[i] + @column_width, @col_tops[i] ]
    @box_trimesters = true
    @box_first = true
    @box_standards = nil
    @comment_std = nil
  end
  
  def box_top_line
    if @box_first
      @box_first = false
      @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_TOP], @box[BOX_RIGHT], @box[BOX_TOP])
    end
  end
  
  def title(*cols)
    n = cols.size
    if @grade_scale
      cols.each_with_index do |title, i|
        if i > 0
          @box[BOX_TOP] += @br_height
          @box[BOX_BOTTOM] += @br_height
        end
        @objects << Text.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM] + @text_bias[1], @column_width, @p_height, title, "GS.Title", { bold: true })
      end
    else
      title = cols[0].strip
      @objects << Text.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM] + @text_bias[1], @column_width, @p_height, title, "Grid.Title", { bold: true })
      t1c = round_num(@box[BOX_LEFT] + @caption_width + 0.5 * @grade_width)
      if n < 2
        # use trimester labels
        @box_trimesters = true
        t2c = round_num(@box[BOX_LEFT] + @caption_width + 1.5 * @grade_width)
        t3c = round_num(@box[BOX_LEFT] + @caption_width + 2.5 * @grade_width)
        @objects << Text.new(@page, @box[BOX_LEFT] + @caption_width, @box[BOX_BOTTOM] + @text_bias[1], 0, 0, "<tabc #{t1c}>T1<tabc #{t2c}>T2<tabc #{t3c}>T3", "Grid.T123", { bold: true })
      else
        # use value label
        @box_trimesters = false
        value = cols[1].strip
        if value != ""
          t3r = @box[BOX_RIGHT] - @text_bias[0]
          @objects << Text.new(@page, @box[BOX_LEFT] + @caption_width + @text_bias[0], @box[BOX_BOTTOM] + @text_bias[1], 0, 0, "<tabr #{t3r}>#{value}", "Grid.Value", { bold: true })
        end
      end
    end
    @box[BOX_TOP] += @p_height
    @box[BOX_BOTTOM] += @p_height
  end

  def close_box
    if @box_trimesters && ((@box[BOX_BOTTOM] - @box[BOX_TOP]).abs > 0.01)
      1.upto(3) do |i|
        left = @box[BOX_RIGHT] - (4-i) * @grade_width
        @objects << Line.new(@page, left, @box[BOX_TOP], left, @box[BOX_BOTTOM])
      end
    end
    
    # comments
    if @comment_std
      terms = @comment_std.split('|')
      std = terms.shift
      
      box_top_line
      left = @box[BOX_LEFT] + @text_bias[0]
      top = @box[BOX_BOTTOM] + @text_bias[1]
      maxw = @column_width - 2 * @text_bias[0]
      maxh = @comment_height - 2 * @text_bias[1]
      text = @box_standards ? "<b>COMMENTS</b>\n" : ""
      case terms.size
      when 0
        text += "^(*std.stored.comment;#{std};T1)\n^(*std.stored.comment;#{std};T2)\n^(*std.stored.comment;#{std};T3)"
      when 1
        text += "^(*std.stored.comment;#{std};#{terms[0]})"
      else
        raise "invalid term specifiers for comments #{std}: #{terms.inspect}"
      end
      @objects << Text.new(@page, left, top, maxw, maxh, text, "#{std}.Comments")
      @box[BOX_BOTTOM] += @comment_height
      @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_BOTTOM], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    end
    
    # left and right of box
    if (@box[BOX_BOTTOM] - @box[BOX_TOP]).abs > 0.01
      @objects << Line.new(@page, @box[BOX_LEFT], @box[BOX_TOP], @box[BOX_LEFT], @box[BOX_BOTTOM])
      @objects << Line.new(@page, @box[BOX_RIGHT], @box[BOX_TOP], @box[BOX_RIGHT], @box[BOX_BOTTOM])
    end
    
    # set up next box top
    i = @column - 1
    @col_tops[i] = @box[BOX_BOTTOM] + @p_height
    @box = nil
    @box_first = true
    @box_standards = nil
    @comment_std = nil
    @grade_scale = false
  end
end

def pst_report(filename, ps_name, title)
  $the_report = Report.new(filename, ps_name, title)
  yield $the_report
end

def method_missing(meth, *args, &block)
  if meth.to_s =~ /^pst_/
    $the_report.send(meth, *args, &block)
  else
    super  
  end
end
