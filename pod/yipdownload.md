# NAME

yipdownload.pl - Global resource and template download administration
CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipdownload.pl?template=example
    /cgi-bin/yipdownload.pl?global=907514

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script serves template text files and global resources directly to the
client, allowing for global resources and templates to be viewed and
downloaded.  The client must have an authorization cookie to use this
script.

**Note:** Global resources are served by this script with caching
disabled so that the client always gets the current copy.  This is
_not_ the script to use for serving global resources to the public.

The GET request takes either a `template` variable that names the
template to download, or a `global` variable that gives the UID of the
global resource to download.  Only GET requests are supported.

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
