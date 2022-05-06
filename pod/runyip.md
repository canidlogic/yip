# NAME

runyip.pl - Perform operations on a Yip MIME message.

# SYNOPSIS

    # Print the UID of an existing message
    ./runyip.pl -read -print uid < input.msg
    
    # Print the timestamp of an existing message
    ./runyip.pl -read -print date < input.msg
    
    # Print the list of attachments of an existing message
    ./runyip.pl -read -print attlist < input.msg
    
    # Export the template code of an existing message
    ./runyip.pl -read -export body < input.msg > body.txt
    
    # Export an attachment of an existing message
    ./runyip.pl -read -export 1001 < input.msg > att.jpeg
    
    # Create a new message
    ./runyip.pl -date 2022-05-05T11:54:29 -uid 532909
                -body body.txt -att 9120 jpeg img.jpg
                -write > output.msg
    
    # Edit an existing message by dropping attachment 9120
    ./runyip.pl -read -drop 9120 -write < input.msg > output.msg

# Description

Wrapper script around the `Yip::Post` module.  This allows you to
perform various manipulations of Yip MIME posts.  If invoked with no
parameters, this script does nothing.  Otherwise, it reads and
interprets parameters in sequential order.  The parameter list is
organized as a sequence of zero or more commands.  Each command starts
with a _verb_ and the verb is followed by zero or more _objects_.  The
types of objects are specific to particular verbs.

By using the `-read` verb at the start, you can query information about
an existing Yip MIME message, extract its contents, and edit it.  You
can also start with a blank MIME message, define all its contents using
verbs and then use the `-write` verb.  See the synopsis for various
usage examples.

The following subsections document the available verbs.

## read verb

The `-read` verb, if present, must be the first parameter.  It does not
take any objects.  This verb indicates that a Yip MIME message should be
read and parsed from standard input.  If not present, then the state
starts out in the default initialization state defined by `Yip::Post`.

## print verb

The `-print` verb, if present, must be the second-to-last parameter.
The last parameter is then the object of this verb, which must be either
`uid` `date` or `attlist`.  This verb will finish the script by
printing to standard output the current value of the specified field.
For the `attlist`, a listing of attachment indices and their data types
will be printed.

## export verb

The `-export` verb, if present, must be the second-to-last parameter.
The last parameter is then the object of this verb, which must be either
`body` or a four-digit attachment index.  The template code or the
specified raw attachment data is printed to standard output.

## date verb

The `-date` verb can be used anywhere and any number of times.  It
takes a single object, which is a timestamp in `yyyy-mm-ddThh:mm:ss`
format.  The current post timestamp is changed to the given timestamp.
The year must be in range \[1970, 4999\].

## uid verb

The `-uid` verb can be used anywhere and any number of times.  It takes
a single object, which is a unique ID code in range \[100000, 999999\].
The current post UID is changed to the given unique identifier.

## body verb

The `-body` verb can be used anywhere and any number of times.  It
takes a single object, which is the path to a UTF-8 text file that
contains the template code that should be set as the template code
within the MIME message.

## att verb

The `-att` verb can be used anywhere and any number of times.  It takes
three objects:  (1) the attachment index, which must be in \[1000, 9999\];
(2) the data type, which must be one to 31 ASCII alphanumerics and
underscores; (3) the path to the file containing the binary data of the
attachment.  If the given attachment index does not currently exist, a
new attachment is created.  If the given attachment index already
exists, the attachment is overwritten.

## drop verb

The `-drop` verb can be used anywhere and any number of times.  It
takes a single object, which is an attachment index in \[1000, 9999\].  If
an attachment with that index exists, it is dropped.  Otherwise, this
verb has no effect.

## write verb

The `-write` verb, if present, must be the last parameter.  If present,
it means that whatever the state of the MIME message at the end of
interpretation, the resulting MIME message should be printed to standard
output.

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
