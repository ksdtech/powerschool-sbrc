require './pst_dsl'

['gradetktmpl.txt', 'gradektmpl.txt', 
  'grade1tmpl.txt', 'grade2tmpl.txt',
  'grade3tmpl.txt', 'grade4tmpl.txt'].each do |tmpl|
  $stderr.puts "loading #{tmpl}"
  load(tmpl)
end