powerschool-sbrc
================

Builds standards-based report card template file to be imported
into PowerSchool.

Instructions:

1. Export Standards table from PowerSchool DDE with these columns. 

Type
Courses
Conversionscale
Allowassignments
Includecomment
Grade
Identifier
Subjectarea
Name
Description
Level
Sortorder
Listparent

2. Save into standards.txt.

3. Create template files using DSL.  See grade1tmpl.txt for example.

4. Run build_pst.rb.

5. Import .pst file into PowerSchool.