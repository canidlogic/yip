# NAME

yipdownload.pl - Global resource, attachment, and template download
administration CGI script for Yip.

# SYNOPSIS

    /cgi-bin/yipdownload.pl?template=example
    /cgi-bin/yipdownload.pl?global=907514
    /cgi-bin/yipdownload.pl?local=8519841009
    
    /cgi-bin/yipdownload.pl?template=example&preview=1
    /cgi-bin/yipdownload.pl?global=907514&preview=1
    /cgi-bin/yipdownload.pl?local=8519841009&preview=1

# DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script serves template text files, global resources, and attachment
files directly to the client, allowing for global resources,
attachments, and templates to be viewed and downloaded.  The client must
have an authorization cookie to use this script.

**Note:** Global resources and attachment files are served by this script
with caching disabled so that the client always gets the current copy.
Also, resources and attachments are served with attachment disposition
intended for downloading.  This is _not_ the script to use for serving
global resources or attachments to the public.

The GET request takes either a `template` variable that names the
template to download, or a `global` variable that gives the UID of the
global resource to download, or a `local` variable that takes ten
digits, the first six being the UID of a post and the last four being
the attachment index to fetch.  Only GET requests are supported.

If the optional `preview` parameter is provided and set to 1, then
instead of serving with attachment disposition, the resource is served
with the default inline disposition so that the browser will attempt to
show the resource or attachment or template directly.  Providing
`preview` with it set to 0 is equivalent to not providing the parameter
at all.  No other value is valid.

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
