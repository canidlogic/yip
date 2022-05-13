# NAME

yipupload.pl - Global resource upload administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipupload.pl

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles uploading global resources, which can either create new
global resources or overwrite existing ones.  The client must have an
authorization cookie to use this script.

The GET request will provide a form allowing the unique, six-digit ID of
the resource to be entered, the resource data type to be selected, and
the actual resource file to be uploaded.  The resource data type is a
multiple choice populated by the data types currently registered in the
database, with an error message displayed to user if there are no
currently registered data types.  The unique ID number must be six
digits beginning with a non-zero digit.  If no resource with that number
currently exists, a new global resource will be created.  Otherwise, an
existing resource will be overwritten.

This script is also the POST request target of the form it provides in
the GET request.  The POST request will read the uploaded resource and
update the database accordingly.

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
