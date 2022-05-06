# NAME

Yip::Post - Pack and unpack Yip posts encapsulated in MIME messages.

# SYNOPSIS

    use Yip::Post;
    
    # New post objects start out empty
    my $yp = Yip::Post->create;
    
    # You can overwrite state by loading from a MIME message
    $yp->loadMIME($octets);
    
    # Get and set the UID of the post
    my $uid = $yp->uid;
    $yp->uid(532909);
    
    # Get and set date as yyyy-mm-ddThh:mm:ss string
    my $datestr = $yp->date;
    $yp->date('2022-05-05T11:54:29');
    
    # Get and set the post body (may contain Unicode codepoints)
    my $body = $yp->body;
    $yp->body($body . 'extra text');
    
    # Get a list of all attachment indices in ascending order
    my @attl = $yp->attlist;
    
    # Get and set the typename of any existing attachment
    my $tname = $yp->atttype(1001);
    $yp->atttype(1001, 'jpeg');
    
    # Get and set the binary data of any existing attachment
    my $octets = $yp->attdata(1001);
    $yp->attdata(1001, $octets);
    
    # Drop attachments
    $yp->attdrop(5007);
    $yp->attdrop(9120);
    
    # Create or overwrite attachment
    $yp->attnew(2073, 'png', $octets);
    
    # Encode current state into MIME message
    my $octets = $yp->encodeMIME;

# DESCRIPTION

This class allows you create, edit, pack, and unpack Yip posts that are
encapsulated in MIME messages.  The class never accesses any Yip CMS
database, and it is independent of any particular Yip deployment.
Therefore, Yip MIME messages will work across all Yip deployments.

**Caution:** This class assumes messages and all their attachments are
small enough to be stored entirely within memory.  Trouble will occur if
you try to use this class to access huge posts that won't easily fit in
memory.

The Yip MIME message includes a unique ID integer for the post, a
timestamp for the post, Unicode text storing the HTML template code for
the post, and zero or more attachments.  Attachments each have an index
that is unique for the attachment within this specific post, a textual
name identifying the kind of data stored within the attachment, and a
binary string storing the raw data of the attachment.

See the documentation for `createdb.pl` for further information about
the structure of Yip posts and the format of the HTML template code.
Note that the textual data type name for attachments is _not_ a MIME
type, but rather is a key that should match a record in the `rtype`
table of whichever Yip CMS database this message is intended for.

To use this class, first you construct a new instance.  The new instance
always starts out with empty template code, zero attachments, UID set to
100000, and timestamp set to 1970-01-01T00:00:00.  If you are creating a
new post from scratch, you now use the editing instance methods to get
the object into the proper state.  If you want to read an existing post
message, you can use the `loadMIME` function to parse and set the
object state equal to what's contained within a given MIME message.

For unpacking existing messages, the various accessor functions allow
you to read all the needed information.  For packing new messages, the
`encodeMIME` function will encode the current state of the object into
a MIME message.

## MIME message format

This section describes the specific format of MIME messages that are
parsed by the `loadMIME` function of this class and written by the
`encodeMIME` function of this class.

`MIME::Parser` is used internally to parse MIME format and
`MIME::Entity` is used internally to generate MIME format.

When parsing, e-mail fields such as From, To, and Subject are ignored.
When generating, `author@example.com` is used as the From field,
`yip@example.com` is used as the To field, and the Subject is
`Yip post 915400` with the UID of the post.  (Note that the subject
field is _not_ where the parser determines the UID of the post from!
The manifest is what determines the UID.)

The first entity attached to the MIME message must be a `text/plain`
file.  Its name is ignored by the parser, but set to `manifest` by the
generator.  The generator will use 7bit encoding and specify inline
disposition.  It has the following format:

    YIP 915400 2022-05-05T11:54:29
    1001 jpeg
    1002 jpeg
    1003 png
    4257 mp3
    1005 jpeg
    END

The first line is always required.  It has the format signature `YIP`
followed by the UID of the post, followed by the timestamp of the post.
After the first line is a sequence of zero or more attachment
declarations.  Each attachment declaration is an attachment index and
then the data type name of the attachment.  Attachments must match the
order they appear in the MIME message and each must have a unique index
number, but the index numbers do not need to be in any sort of order.
Finally, the last line just has `END`.

After the manifest file always comes another file that must be
`text/plain; charset=utf-8`.  Its name is ignored by the parser, but
set to `post` by the generator.  It contains the template code for the
post, and the part is encoded by the generator in base64 and set to
attachment disposition.

After the template code part comes the sequence of zero or more
attachments, which must match what is given in the manifest file.  The
type of each must be `application/octet-stream`.  The attachment names
are ignored by the parser but set to `att4257` by the generator where
the attachment index is used as the digits.  The generator will encode
in base64 and set to attachment disposition.

# CONSTRUCTOR

- **create()**

    Construct a new, blank post object.  After construction, the template
    code will be empty, there will be no attachments, the unique ID will be
    set to 100000, and timestamp set to 1970-01-01T00:00:00.

# INSTANCE METHODS

- **loadMIME(octets)**

    Given a binary string holding a complete Yip MIME post message,
    overwrite the contents of this Yip object with the encoded post message.
    Fatal errors occur if there are any errors parsing the Yip MIME message.
    This object state will only be changed if the load operation is
    successful.

- **uid(\[uid\])**

    If invoked without a parameter, returns the UID of the object, which is
    an integer in range \[100000, 999999\].  If invoked with a parameter,
    takes a new UID to set, which must be an integer in that same range.

- **date(\[datestring\])**

    If invoked without a parameter, returns the timestamp of the object,
    which is a string in `yyyy-mm-ddThh:mm:ss` format.  If invoked with a
    parameter, takes a new timestamp to set, which must be a string with
    that same format.

- **body(\[string\])**

    If invoked without a parameter, returns the template code within the
    body as a Unicode string.  If invoked with a parameter, takes a new
    Unicode string to set as the body.  The Unicode string may contain any
    Unicode codepoints except for surrogates.

- **attlist()**

    Returns a list (in list context) containing all the attachment indices
    in ascending order.  May be an empty list if no attachments defined.

- **atttype(att\_index\[, typename\])**

    If invoked with one parameter, returns the data type of the attachment
    that has the given attachment index.  If invoked with two parameters,
    sets the data type of the attachment with the given attachment index.
    An attachment with the given index must already exist or a fatal error
    occurs.  The typename must be a string of one to 31 ASCII alphanumerics
    and underscores.

- **attdata(att\_index\[, octets\])**

    If invoked with one parameter, returns the raw binary string data of the
    attachment that has the given attachment index.  If invoked with two
    parameters, sets the raw binary data of the attachment with the given
    attachment index.

- **attdrop(att\_index)**

    Drop the attachment with the given index, if it exists.  Does nothing if
    the given attachment index does not exist.  The index however must be an
    integer in range \[1000, 9999\] or a fatal error occurs.

- **attnew(att\_index, data\_type, octets)**

    Add or overwrite an attachment.  att\_index is the index of the
    attachment, which must be an integer in range \[1000, 9999\].  If this
    index is not already used, a new attachment will be added.  If this
    index is already in use, the new attachment will replace the old one.
    data\_type is the name of data type, which must be a string of 1 to 31
    ASCII alphanumerics and underscores.  octets is the raw binary data.

- **encodeMIME()**

    Encode the current state of the post object into a MIME message.
    Returns a binary string containing the whole MIME message.  This binary
    string is 7-bit safe.

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
