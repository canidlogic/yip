# NAME

yipexport.pl - Post export administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipexport.pl?post=814570
    /cgi-bin/yipexport.pl?post=814570&preview=1

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles exporting posts along with their attachments.  The client
must have an authorization cookie to use this script.

The GET request must be provided with a query string variable `post`
that contains the unique ID of the post to export.  The response will be
an encoded MIME message that contains the exported post and all its
attachments.  See the `Yip::Post` module for further details about the
format of this MIME message.  You can use the `runyip.pl` utility
script for working with this MIME message format.

You can provide an optional `preview` parameter and set it to 1, in
which case instead of providing an encoded MIME message to download, an
HTML page is displayed showing the raw contents of the post, along with
links to view and download any attachments.  If `preview` is set to 0
then the script works as normal by generating a MIME message to
download.  No other values of the optional `preview` parameter are
supported.

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
