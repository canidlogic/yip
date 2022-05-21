# NAME

yip.pl - Yip microblog rendering script.

# SYNOPSIS

    /cgi-bin/yip.pl
    /cgi-bin/yip.pl?global=917530
    /cgi-bin/yip.pl?local=3905121002
    /cgi-bin/yip.pl?post=309685
    /cgi-bin/yip.pl?archive=820035

# DESCRIPTION

This CGI script handles all of the rendering of the Yip CMS database to
the public.  This script does not alter or handle administration of the
CMS database; use the separate administrator CGI scripts for that.

This script only works with the GET method.  If invoked without any
parameters, the script generates the main catalog page.  Otherwise, the
parameter name indicates the type of entity to render and the parameter
value is a unique ID identifying the entity, as shown in the synopsis.
However, for the `local` invocation, the parameter value is ten digits,
the first six being the unique ID of a post and the last four being the
attachment ID of that post to render.

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
