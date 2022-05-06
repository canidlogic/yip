# NAME

Yip::Admin - Common utilities for administration CGI scripts.

# SYNOPSIS

    use Yip::DB;
    use Yip::Admin;
    use YipConfig;
    
    my $dbc = Yip::DB->connect($config_dbpath, 0);
    my $yad = Yip::Admin->load($dbc);
    
    # Check for verification cookie for scripts that can work without it
    if ($yad->hasCookie) {
      ...
    }
    
    # Make sure verification cookie present on scripts that require it
    $yad->checkCookie;
    
    # Get any loaded configuration value
    my $epoch = $yad->getVar('epoch');
    
    # Send a Set-Cookie header to client with new verification cookie
    $yad->sendCookie;
    
    # Send a Set-Cookie header to client that cancels cookie
    $yad->cancelCookie;
    
    # Send a standard error response for an invalid request method
    Yip::Admin->invalid_method;
    
    # Send a standard error response for a bad request
    Yip::Admin->bad_request;
    
    # Read data sent from HTTP client as raw bytes
    my $octets = Yip::Admin->read_client;

# DESCRIPTION

Module that contains common support functions for administration CGI
scripts.  Some functions are available as class methods, others need a
utility object to be constructed, as described below.

First, you connect to the Yip CMS database using `Yip::DB`.  Then, you
pass that database connection object to the `Yip::Admin` constructor to
load the administrator utility object.  This constructor will make sure
that the connection is HTTPS by checking for a CGI environment variable
named `HTTPS`, load a copy of all configuration variables into memory,
and check whether the CGI environment variable `HTTP_COOKIE` contains a
currently valid verification cookie.  It is a fatal error if the
protocol is not HTTPS or if loading configuration variables fails, but
it is okay if there is no valid verification cookie.

Once the administrator utility object is loaded, you should check
whether there is a valid verification cookie.  For the common case of
administrator scripts that only work when verified, you can just use the
`checkCookie` instance method which sends an HTTP error back to the
client and exits if there is no verification cookie.  For certain
special scripts that can function even without verification, you can use
the `hasCookie` instance method to check whether the client is verified
or not.

At any point after construction, you can get the cached values of the
configuration variables with the `getVar` function.

Finally, when you are printing out a CGI response, you can use the
`sendCookie` instance function to print out a `Set-Cookie` header line
that sets the verification cookie.  Most administrator scripts should do
this at the end of a successful invocation while writing the CGI headers
so that the time in the client's verification cookie is updated.  Don't
send a cookie if the client was never verified in the first place,
though!

# CONSTRUCTOR

- **load(dbc)**

    Construct a new administrator utilities object.  `dbc` is the
    `Yip::DB` object that should be used to load the configuration
    variables.  All the configuration variables will be loaded in a single
    read-only work block.  If you want all database activity to be in a
    single transaction, including this configuration load, you should begin
    a work block on the `Yip::DB` object before calling this constructor.

    This constructor will also verify that the CGI environment variable
    `HTTPS` is defined, indicating that the connection is secured over
    HTTPS.  If this is not the case, this constructor will send HTTP 403
    Forbidden to the client with a message that they need to connect over
    HTTPS and then the function will exit without returning to the caller.

    Furthermore, the constructor will set both standard input and standard
    output into raw binary mode.

    When loading configuration variables into memory, this constructor will
    make sure that all of these recognized variables are defined:

        epoch
        lastmod
        authsuffix
        authsecret
        authlimit
        authcost
        authpswd
        pathlogin
        pathlogout
        pathreset
        pathadmin
        pathlist
        pathdrop
        pathedit
        pathupload
        pathimport
        pathdownload
        pathexport
        pathgenuid

    You can set all these variables using the `resetdb.pl` script.  Any
    variables beyond the ones listed above will be ignored.

    All of the path variables will be decoded from UTF-8 into a Unicode
    string and checked that they begin with a slash.  The `epoch`
    `lastmod` `authlimit` and `authcost` variables will be range-checked
    and decoded into integer values.  All other variables will be checked
    and stored as strings.  Fatal errors occur if there are any problems.

    Finally, the constructor checks for a CGI environment variable named
    `HTTP_COOKIE`.  If the environment variable is present and it contains
    a valid list of cookies that includes a cookie with name `__Host-`
    suffixed with the `authsuffix` value, and this cookie consists of a
    valid verification payload, then an internal flag will be set indicating
    that the client is verified.  In all other cases, the internal flag will
    be cleared indicating the client is not verified.

    A valid verification payload is two base-16 strings separated by a
    vertical bar.  The first base-16 string is the number of minutes since
    the Unix epoch and the second base-16 string is an HMAC-MD5 digest using
    the `authsecret` value as the secret key.  Apart from the HMAC-MD5
    being valid, the time encoded in the payload must not be further than
    `authlimit` minutes in the past, and must not be more than one minute
    in the future.

# INSTANCE METHODS

- **hasCookie()**

    Returns 1 if the HTTP client has a valid verification cookie, 0 if not.
    You should only use this function if the script supports both authorized
    and unauthorized clients.  In the more usual case that only authorized
    clients are allowed, see `checkCookie`.

- **checkCookie()**

    Make sure the HTTP client has a valid verification cookie.  If so, then
    this function returns without doing anything further.  If not, an error
    message is set to the HTTP client and this function will exit the script
    without returning.

- **getVar(key)**

    Get the cached value of a variable from the `cvars` table.  `key` is
    the name of the variable to query.  A fatal error occurs if the key is
    not recognized.  `epoch` `lastmod` `authlimit` and `authcost` are
    returned as integer values, everything else is returned as strings.
    Path variables will already have been decoded from UTF-8.

- **sendCookie()**

    Print a `Set-Cookie` HTTP header that contains a fresh, valid
    authorization cookie.  The `Set-Cookie` line is printed directly to
    standard output, followed by a CR+LF break.

- **cancelCookie()**

    Print a `Set-Cookie` HTTP header that overwrites any authorization
    cookie the client may have with an invalid value and then immediately
    expires the cookie.  The `Set-Cookie` line is printed directly to
    standard output, followed by a CR+LF break.

# STATIC CLASS METHODS

- **invalid\_method()**

    Send an HTTP 405 Method Not Allowed back to the client and exit without
    returning.

- **bad\_request()**

    Send an HTTP 400 Bad Request back to the client and exit without
    returning.

- **read\_client()**

    Read data sent by an HTTP client.  This checks for CONTENT\_LENGTH
    environment variable, then reads exactly that from standard input,
    returning the raw bytes in a binary string.  If there are any problems,
    sends 400 Bad Request back to client and exits without returning.

- **parse\_form($str)**

    Given a string in application/x-www-form-urlencoded format, parse it
    into a hash reference containing the decoded key/value map with possible
    Unicode in the strings.  If there are any problems, sends 400 Bad
    Request back to client and exists without returning.

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
