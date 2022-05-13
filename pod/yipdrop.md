# NAME

yipdrop.pl - Entity drop administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipdrop.pl?type=example
    /cgi-bin/yipdrop.pl?var=example
    /cgi-bin/yipdrop.pl?template=example
    /cgi-bin/yipdrop.pl?archive=715932
    /cgi-bin/yipdrop.pl?global=175983
    /cgi-bin/yipdrop.pl?post=540015

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles dropping various kinds of entities from the database.
The client must have an authorization cookie to use this script.

The GET request takes a query-string variable whose name indicates the
type of entity being dropped and whose value identifies the specific
entity of that type to drop.  See the synopsis for the patterns.  The
GET request does not actually perform the drop.  Instead, it provides a
form that confirms the operation and submits to itself with a POST
request.

This script is also the POST request target of the form it provides in
the GET request.  The POST request will drop the indicated entity from
the database.

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
