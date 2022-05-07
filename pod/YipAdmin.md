# NAME

Yip::Admin - Common utilities for administration CGI scripts.

# SYNOPSIS

    use Yip::Admin;
    
    # Check we are running as CGI and get 'GET' or 'POST' method
    my $method = Yip::Admin->http_method;
    
    # Read data sent from HTTP client as raw bytes
    my $octets = Yip::Admin->read_client;
    
    # Parse application/x-www-form-urlencoded into hashref
    my $vars = Yip::Admin->parse_form($octets);
    my $example = $vars->{'example_var'};
    
    # Send standard responses (these calls do not return)
    Yip::Admin->invalid_method;
    Yip::Admin->bad_request;
    
    # Generate HTML or HTML template in "house" CGI style
    my $html = Yip::Admin->format_html($title, $body_code);
    
    # Instance methods require database connection to construct instance
    use Yip::DB;
    use YipConfig;
    
    my $dbc = Yip::DB->connect($config_dbpath, 0);
    my $yap = Yip::Admin->load($dbc);
    
    # If you want everything in one transaction, do like this:
    my $dbc = Yip::DB->connect($config_dbpath, 0);
    my $dbh = $dbc->beginWork('w');
    my $yap = Yip::Admin->load($dbc);
    ...
    $dbc->finishWork;
    
    # Check for verification cookie for scripts where it's optional
    if ($yap->hasCookie) {
      ...
    }
    
    # Make sure verification cookie present on scripts that require it
    $yap->checkCookie;
    
    # Get any loaded configuration value
    my $epoch = $yap->getVar('epoch');
    
    # Send a Set-Cookie header to client with new verification cookie
    $yap->sendCookie;
    
    # Send a Set-Cookie header to client that cancels cookie
    $yap->cancelCookie;

# DESCRIPTION

Module that contains common support functions for administration CGI
scripts.  Some functions are available as class methods and can be
called directly by clients, as shown in the first part of the synopsis.
Other functions need access to data in the Yip CMS database to work.
For these functions, you must construct a Yip::Admin object instance,
passing a `Yip::DB` connection to use.  The constructor will read and
cache all necessary data from the database.  Instance methods will then
make use of the cached data (the database is not used again after
construction).  See the second half of the synopsis for examples of
using the instance functions.

## General pattern

Administrator CGI scripts should always start out with a call to the
`http_method` instance method, which does a quick check that the script
was invoked as a CGI script and also determines whether this is a GET or
POST request.

For most administrator CGI scripts, the next operation will be to get a
Yip CMS database connection, use that to construct a `Yip::Admin`
object instance, and then call the `checkCookie` instance function to
make sure that the client is authorized.  However, the login and
password reset scripts do not follow this pattern, since they must also
be able to work with clients who are not authorized yet.

For most administrator CGI scripts, when sending a response back to the
client, the `sendCookie` function should be called immediately after
writing the other CGI response headers but before writing the blank line
that ends the CGI response head.  This will refresh the client's
authorization cookie.  However, the login, logout, and password reset
scripts do not follow this pattern.

**Note:** The constructor for `Yip::Admin` will put standard input and
standard output into binary mode.

## Configuration variable access

The `Yip::Admin` object instance caches all configuration variables, so
administrator CGI scripts can just use the `getVar` instance method to
access these cached copies.

## POST data access

For `POST` request handling, you can read all the raw bytes that the
client sent you using the `read_client` class method.  **Do not slurp
all input from standard input!**  According to the CGI standard, CGI
scripts should only read the amount of bytes indicated by the
`CONTENT_LENGTH` environment variable from standard input.  The
`read_client` class method will handle this correctly.

If the POSTed client data is in the usual form data format of
`application/x-www-form-urlencoded` then you can use the class method
`parse_form` to decode it into a hashref, which includes Unicode
support.

## Predefined responses

Class methods are provided for certain predefined responses.  Some of
these predefined responses are used internally, though they are also
made public in case the client might need them.

Predefined responses will print a complete CGI response to standard
output and then exit the script, never returning to caller.  All of the
predefined responses are for brief error messages.

## HTML formatting

The `format_html` class method is used by all the predefined responses
and should be used by administrator CGI scripts to ensure a consistent
HTML style across all administrator CGI scripts.  This can be used both
for HTML pages and HTML templates.  A standard CSS stylesheet will be
included, as well as consistent headers.  See the documentation of the
function for further information.

# CLASS METHODS

- **http\_method()**

    Check that there is a CGI environment variable REQUEST\_METHOD and fatal
    error if not.  Then, get the REQUEST\_METHOD and normalize it to 'GET' or
    'POST'.  If it can't be normalized to one of those two, invoke
    invalid\_method.  Return the normalized method.

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

- **format\_html(title, body\_code)**

    Generate HTML or an HTML template according to the "house style" for
    administration scripts.  `title` is the page title to write into the
    head section _which should be escaped properly_ but _not_ include the
    surrounding title element start and end blocks.  `body_code` is what
    should be pasted between the body start and end element.

    This function will generate all the necessary boilerplate code and add a
    stylesheet.  The following special CSS IDs are classes are defined in
    the stylesheet:

        #homelink
        The DIV containing link back to control panel
        
        .ctlbox
        DIVs containing two sub-DIVs, one for label and second for control
        
        .btnbox
        DIV for submit button
        
        .pwbox
        CSS class for password input boxes
        
        .btn
        CSS class for submit buttons

    This function will also normalize all line breaks to CR+LF before
    returning the result.

- **invalid\_method()**

    Send an HTTP 405 Method Not Allowed back to the client and exit without
    returning.

- **bad\_request()**

    Send an HTTP 400 Bad Request back to the client and exit without
    returning.

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

- **sendCookie()**

    Print a `Set-Cookie` HTTP header that contains a fresh, valid
    authorization cookie.  The `Set-Cookie` line is printed directly to
    standard output, followed by a CR+LF break.

- **cancelCookie()**

    Print a `Set-Cookie` HTTP header that overwrites any authorization
    cookie the client may have with an invalid value and then immediately
    expires the cookie.  The `Set-Cookie` line is printed directly to
    standard output, followed by a CR+LF break.

- **getVar(key)**

    Get the cached value of a variable from the `cvars` table.  `key` is
    the name of the variable to query.  A fatal error occurs if the key is
    not recognized.  `epoch` `lastmod` `authlimit` and `authcost` are
    returned as integer values, everything else is returned as strings.
    Path variables will already have been decoded from UTF-8.

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
