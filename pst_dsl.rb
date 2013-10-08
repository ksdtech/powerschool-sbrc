require 'csv'
require 'nokogiri'

$the_report = nil

def round_num(n)
  sprintf("%.03f", n).gsub(/\.000$/, '')
end

class Box
  def initialize(p, l, t, r, b, lbl="Box")
    @p = p
    @l = l
    @t = t
    @r = r
    @b = b
    @lbl = lbl
  end
  
  def build(xml, obj_no)
    xml.Type "Box"
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
    xml.Layer 0
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
  def initialize(filename='test.pst', title='CCSS Grade 1')
    @filename = filename
    @title = title
    @objects = [ ]
    @page_tops = [ 2.4, 1.4, 1.0 ]
    @page = 1
    @column = 1
    @box = nil
    @comment_std = nil
    @comment_height = 1.8
    @caption_char_widths = [ 42, 35 ]
    @line_heights = [ 0.2, 0.3, 0.4 ]
    @text_bias  = [ 0.05, 0.12 ]
    @col_tops   = [ @page_tops[0], @page_tops[0] ]
    @col_lefts  = [ 0.5,   4.375 ]
    @column_width  = 3.625
    @grade_width = 0.3
    @caption_width = @column_width - (3 * @grade_width) - 0.05
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
          xml.Name @title
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

  def pst_grid(col_no, comments=nil)
    open_box(col_no, comments)
    yield self
  end

  def pst_title(*cols)
    title = cols[0]
    @objects << Text.new(@page, @box[0], @box[3] + @text_bias[1], @column_width, @line_heights[0], title, "Grid.Title", { bold: true })
    t1c = round_num(@box[0] + @caption_width + 0.5 * @grade_width)
    if cols.size < 2
      # use trimester labels
      t2c = round_num(@box[0] + @caption_width + 1.5 * @grade_width)
      t3c = round_num(@box[0] + @caption_width + 2.5 * @grade_width)
      @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>T1<tabc #{t2c}>T2<tabc #{t3c}>T3", "Grid.T123", { bold: true })
    else
      # use value label
      value = cols[1]
      @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>#{value}", "Grid.Value", { bold: true })
    end
    @box[1] += @line_heights[0]
    @box[3] += @line_heights[0]
  end

  def pst_attendance(col_no)
    open_box(col_no, nil)
    pst_title('ATTENDANCE')
    @objects << Line.new(@page, @box[0], @box[1], @box[2], @box[1])
    s = 'Days absent'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, s, "Absent.Name")
    t1c = round_num(@box[0] + @caption_width + 0.5 * @grade_width)
    t2c = round_num(@box[0] + @caption_width + 1.5 * @grade_width)
    t3c = round_num(@box[0] + @caption_width + 2.5 * @grade_width)
    @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(daily.att.count;;A,E,X,S;T1)<tabc #{t2c}>^(daily.att.count;;A,E,X,S;T2)<tabc #{t3c}>^(daily.att.count;;A,E,X,S;T3)", "Absent.T123", { bold: true })
    @box[3] += h
    @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
    s = 'Days tardy'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, s, "Tardy.Name")
    @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(daily.att.count;;T,U,L;T1)<tabc #{t2c}>^(daily.att.count;;T,U,L;T2)<tabc #{t3c}>^(daily.att.count;;T,U,L;T3)", "Tardy.T123", { bold: true })
    @box[3] += h
    @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
    close_box
  end

  def pst_supplemental(col_no)
    open_box(col_no, nil)
    t1c = round_num(@box[0] + @caption_width + 0.5 * @grade_width)
    pst_title('SUPPLEMENTAL PROGRAMS', 'VALUE')
    @objects << Line.new(@page, @box[0], @box[1], @box[2], @box[1])
    s = 'English Language Learning - Overall CELDT'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, s, "CELDT.Name")
    @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(tests;name=CELDT;score=Overall;type=num;result=max)", "CELDT.Overall", { bold: true })
    @box[3] += h
    @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
    s = 'Resource Specialist'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, s, "RSP.Name")
    @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(CA_PrimDisability;if.not.blank.then=X)", "504.Value", { bold: true })
    @box[3] += h
    @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
    s = '504'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, s, "504.Name")
    @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(CA_SpEd504;if.1.then=X)", "504.Value", { bold: true })
    @box[3] += h
    @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
    s = 'Modifications'
    maxh, h = line_height(s, false)
    @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, s, "Modifications.Name")
    @box[3] += h
    @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
    close_box
  end
  
  def pst_groups(*groups)
    first = true
    groups.each do |parent|
      if first
        first = false
        @objects << Line.new(@page, @box[0], @box[1], @box[2], @box[1])
      end
      std = @standards[parent]
      maxh, h = line_height(std[:name], true)
      @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, std[:name], "#{parent}.Name", { bold: true })
      @box[3] += h
      @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
      t1c = round_num(@box[0] + @caption_width + 0.5 * @grade_width)
      t2c = round_num(@box[0] + @caption_width + 1.5 * @grade_width)
      t3c = round_num(@box[0] + @caption_width + 2.5 * @grade_width)
      @standards_by_parent[parent].each do |id|
        std = @standards[id]
        maxh, h = line_height(std[:name], false)
        @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @caption_width, maxh, std[:name], "#{id}.Name")
        @objects << Text.new(@page, @box[0] + @caption_width, @box[3] + @text_bias[1], 0, 0, "<tabc #{t1c}>^(*std.stored.transhigh;#{id};T1)<tabc #{t2c}>^(*std.stored.transhigh;#{id};T2)<tabc #{t3c}>^(*std.stored.transhigh;#{id};T3)", "#{id}.T123", { bold: true })
        @box[3] += h
        @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
      end
    end
    close_box
  end
  
  protected
  
  def line_count(s, bold)
    bold ? (s.length > @caption_char_widths[1] ? 2 : 1) :
      (s.length > @caption_char_widths[0] ? 2 : 1)
  end
  
  def line_height(s, bold)
    n    = line_count(s, bold)
    maxh = @line_heights[n-1]
    h    = @line_heights[n-1]
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
      @objects << Text.new(@page,  3.750,  0.778,  0,  0, "Kentfield School District", "Kentfield School District", {  })
      @objects << Text.new(@page,  3.352,  0.944,  0,  0, "First Grade Progress Report", "First Grade Progress Report", { size: 11, bold: true,  })
      @objects << Text.new(@page,  3.065,  1.111,  0,  0, "Bacich Elementary School - Sally Peck, Principal", "Bacich", {  })
      @objects << Text.new(@page,  3.769,  1.278,  0,  0, "School Year 2013-2014", "School Year", {  })
      @objects << Text.new(@page,  1.600,  1.500,  0,  0, "Student Name: ^(Fipst_Name) ^(Middle_Name) ^(Fipst_Name)\nTeacher: ^(HomeRoom_TeacherFirst) ^(HomeRoom_Teacher)", "Student Name", { size: 9, bold: true })
      @objects << Text.new(@page,  4.500,  1.500,  0,  0, "Academic Achievement Level Descriptors", "Text", { bold: true, })
      @objects << Text.new(@page,  3.900,  1.625,  0,  0, "3  = <b>Significant</b> understanding of the standard and the ability to apply.\n2  = <b>Partial</b> understanding of the standard and the ability to apply.\n1  = <b>Minimal</b> understanding of the standard and the ability to apply.", "Text", {  })
      @col_tops = [ @page_tops[0], @page_tops[0] ]
    elsif @page == 2
      @objects << Text.new(@page,  4.917,  0.625,  0,  0, "          Self-Directed Learner and\nCollaborative Communicator Descriptors", "Text", { bold: true, })
      @objects << Text.new(@page,  5.223,  1.025,  0,  0, "C  = <b>Consistently</b> demonstrates.\nO  = <b>Occasionally</b> demonstrates.\nS  = <b>Seldom</b> demonstrates.", "Text", {  })
      @col_tops = [ @page_tops[1], @page_tops[1] ]
    else
      @col_tops = [ @page_tops[2], @page_tops[2] ]
    end
  end
  
  def open_box(col_no, comments)
    @column = col_no
    i = @column - 1
    @box = [ @col_lefts[i], @col_tops[i], @col_lefts[i] + @column_width, @col_tops[i] ]
    @comment_std = comments
  end
  
  def close_box
    # vertical lines
    1.upto(3) do |i|
      left = @box[2] - (4-i) * @grade_width
      @objects << Line.new(@page, left, @box[1], left, @box[3])
    end
    if @comment_std
      @objects << Text.new(@page, @box[0] + @text_bias[0], @box[3] + @text_bias[1], @column_width - 2 * @text_bias[0], @comment_height - 2 * @text_bias[1], 
      "^(*std.stored.comment;#{@comment_std};T1)", "Comments", { bold: true })
      @box[3] += @comment_height
      @objects << Line.new(@page, @box[0], @box[3], @box[2], @box[3])
    end
    @objects << Line.new(@page, @box[0], @box[1], @box[0], @box[3])
    @objects << Line.new(@page, @box[2], @box[1], @box[2], @box[3])
    i = @column - 1
    @col_tops[i] = @box[3] + @line_heights[0]
    @box = nil
    @comment_std = nil
  end
end

def pst_report(filename, title)
  $the_report = Report.new(filename, title)
  yield $the_report
end

def method_missing(meth, *args, &block)
  if meth.to_s =~ /^pst_/
    $the_report.send(meth, *args, &block)
  else
    super  
  end
end
