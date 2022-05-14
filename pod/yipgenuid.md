# NAME

yipgenuid.pl - Unique ID generator administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipgenuid.pl?table=post
    /cgi-bin/yipgenuid.pl?table=global
    /cgi-bin/yipgenuid.pl?table=archive

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles generating random but unique identity codes for posts,
global resources, and archives.  The client must have an authorization
cookie to use this script.

The GET request takes a query-string variable `table` that indicates
which table a unique identity is being generated for (`post` `global`
or `archive`).  Each time the page is loaded, a new unique ID will be
randomly generated that does not currently match any record in the
indicated table.

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
