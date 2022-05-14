# NAME

yiplist.pl - Report list administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yiplist.pl?report=types
    /cgi-bin/yiplist.pl?report=vars
    /cgi-bin/yiplist.pl?report=templates
    /cgi-bin/yiplist.pl?report=archives
    /cgi-bin/yiplist.pl?report=globals
    /cgi-bin/yiplist.pl?report=posts

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles listing entities currently within the database and
provides links for editing entities.  The client must have an
authorization cookie to use this script.

The GET request takes a query-string variable `report` that indicates
which kind of entity should be displayed (`types` `vars` `templates`
`archives` `globals` or `posts`).

GET is the only method supported by this script.

# AUTHOR

Noah Johnson, `noah.johnson@loupmail.com`

# COPYRIGHT AND LICENSE

Copyright (C) 2022 Multimedia Data Technology Inc.

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
