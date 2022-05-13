# NAME

yipimport.pl - Post import administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipimport.pl

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles importing posts along with their attachments.  It can be
used both for creating new posts within the database or for overwriting
existing posts.  The client must have an authorization cookie to use
this script.

The GET request will provide a form allowing a MIME message to be
uploaded containing the post, all necessary metainformation for the
post, and any attachments.  See the `Yip::Post` module for further
details about the format of this MIME message.  You can use the
`runyip.pl` utility script for working with this MIME message format.

This script is also the POST request target of the form it provides in
the GET request.  The POST request will read the uploaded MIME message,
parse it, and update the database accordingly.  If a post with a UID
matching what is given within the MIME message already exists, it will
be deleted and then immediately replaced with the new post.  If no post
with a matching UID already exists, a new post will be added.

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
