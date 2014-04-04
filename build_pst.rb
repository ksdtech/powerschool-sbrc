require './pst_dsl'

USING_TERMS = TRUE
REPORT_VERSION = "1.2"

TEMPLATES = [
  # 'gradetktmpl.txt', 'gradektmpl.txt', 
  # 'grade1tmpl.txt', 
  'grade2tmpl.txt',
  # 'grade3tmpl.txt', 'grade4tmpl.txt'
]

TEMPLATES.each do |tmpl|
  $stderr.puts "loading #{tmpl}"
  load(tmpl)
end