# NAME

Yip::Admin - Common utilities for administration CGI scripts.

# SYNOPSIS

    use Yip::Admin;
    
    # Check we are running as HTTPS CGI and get 'GET' or 'POST' method
    my $method = Yip::Admin->http_method;
    
    # Verify client is sending us application/x-www-form-urlencoded
    Yip::Admin->check_form;
    
    # Verify client is sending us multipart/form-data
    Yip::Admin->check_upload;
    
    # Read data sent from HTTP client as raw bytes
    my $octets = Yip::Admin->read_client;
    
    # Parse application/x-www-form-urlencoded into hashref
    my $vars = Yip::Admin->parse_form($octets);
    my $example = $vars->{'example_var'};
    
    # Parse multipart/form-data into hashref, files as binary strings
    my $vars = Yip::Admin->parse_upload($octets);
    my $example = $vars->{'example_var'};
    
    # Generate HTML or HTML template in "house" CGI style
    my $html = Yip::Admin->format_html($title, $body_code);
    
    # Send standard responses (these calls do not return)
    Yip::Admin->insecure_protocol;
    Yip::Admin->not_authorized;
    Yip::Admin->invalid_method;
    Yip::Admin->bad_request;
    
    # Instance methods require database connection to construct instance
    use Yip::Admin;
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
    
    # Change the cookie behavior for send functions
    $yap->cookieLogin;
    $yap->cookieCancel;
    $yap->cookieDefault;
    
    # Add custom template parameter
    $yap->customParam('example', 'value');
    
    # Set a special status code for response
    $yap->setStatus(403, 'Forbidden');
    
    # Respond with a template (does not return)
    $yap->sendTemplate($tcode);
    
    # Respond with non-template HTML code (does not return)
    $yap->sendHTML($html);

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
was invoked as a CGI script over HTTPS and also determines whether this
is a GET or POST request.

For most administrator CGI scripts, the next operation will be to get a
Yip CMS database connection, use that to construct a `Yip::Admin`
object instance, and then call the `checkCookie` instance function to
make sure that the client is authorized.  However, the login and
password reset scripts do not follow this pattern, since they must also
be able to work with clients who are not authorized yet.

Administrator CGI scripts finish in three different ways:

- Fatal error
- Predefined response
- Send functions

The following subsections describe these three possibilities.

### Fatal error handling

If a fatal error occurs with the Perl `die` or the like, then the
response is up to the server because the CGI script will not generate a
normal CGI response in that case.  The usual server behavior is to send
a generic 500 Internal Server Error page back to the client.

If you are debugging and want more information, add the following near
the start of the CGI script to get more details on the error page:

    use CGI::Carp qw(fatalsToBrowser);

In production, this should _not_ be included, for security reasons.

Fatal errors should only occur for problems originating within the
server that have nothing to do with the client.

### Predefined responses

Predefined responses are class methods provided by this module.  They
include the following:

- `insecure_protocol`

    Used when the client did not connect over secured HTTPS.

- `not_authorized`

    Used when the client is not logged in with a valid cookie.

- `invalid_method`

    Used when the client requested something other than HEAD, GET, or POST.

- `bad_request`

    Used when the client's request is malformed.

All of these predefined responses are used internally by this module,
but they are provided publicly in case clients want to use them.  (The
`bad_request` is likely to be useful.)

Since these are class methods, you do not need a database connection or
a `Yip::Admin` object instance to use them.  This makes them good for
responding immediately to low-level errors.

### Send functions

The best way to end an administrator script is by calling either the
`sendTemplate` or `sendHTML` function.  (Internally, the function
`sendTemplate` is just a wrapper around `sendHTML`.)  It is
recommended that you use the `format_html` function to generate HTML or
HTML template code in the "house style" for administrator CGI scripts.

These send functions are instance methods, so you must have an instance
of `Yip::Admin` in order to use them.  The only difference between the
two is that `sendTemplate` will perform template processing.

By default, the template processor will make all of the standard path
variables defined in the `cvars` table available as template variables,
except that each name is prefixed with an underscore.  If you need
additional template variables, you can define them with the
`customParam` function, provided that none of the custom names begin
with an underscore.

By default, the send functions will use HTTP status 200 'OK'.  If you
want to set a different status, use the `setStatus` function.

By default, the send functions will give the HTTP a refreshed
authorization cookie only if the client already has a valid
authorization cookie.  If the client has no valid authorization cookie,
the default behavior is to not send any cookie information back to the
client.  You can explicitly set this default behavior with
`cookieDefault` if you wish.

If you want to send a refershed authorization cookie to the client in
all cases, even when the client doesn't already have a cookie, then you
should call `cookieLogin` to always send a cookie.  This is only
appropriate for the login script when the client has authorized
themselves by providing a matching password.

If you want to cancel any authorization cookie the client may have, then
you should call `cookieCancel`.  This will cause a cookie header to be
sent to the client that overwrites any existing authorization cookie
with an invalid value and immediately expires it.  This is appropriate
for the logout script and the password reset script after the password
has been changed.  But note that this does _not_ update the secret key
in the database, which should be done in a proper logout.

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
    invalid\_method.  Next, check that the CGI environment variable HTTPS is
    defined, invoking insecure\_protocol if it is not.  Finally, return the
    normalized method, which is either 'GET' or 'HEAD'.

- **check\_form()**

    Check that CGI environment variable REQUEST\_METHOD is set to POST or
    fatal error otherwise.  Then, check that there is a CGI environment
    variable CONTENT\_TYPE that is `application/x-www-form-urlencoded` or
    else send 400 Bad Request back to client.

- **check\_upload()**

    Check that CGI environment variable REQUEST\_METHOD is set to POST or
    fatal error otherwise.  Then, check that there is a CGI environment
    variable CONTENT\_TYPE that is `multipart/form-data` or else send 400
    Bad Request back to client.

- **read\_client()**

    Read data sent by an HTTP client and return it as a raw binary string.

    First, this checks that the CGI environment variable REQUEST\_METHOD is
    defined as POST, causing a fatal error if it is not.  Next, this checks
    for CONTENT\_LENGTH environment variable, then reads exactly that from
    standard input, returning the raw bytes in a binary string.  If
    CONTENT\_LENGTH is zero or empty or not defined, then an empty string is
    returned instead.

    Fatal errors occur if there are any problems with the CONTENT\_LENGTH
    variable or with reading the data.

    **Note:** This function might set standard input into raw binary mode.

- **parse\_form($str)**

    Given a string in application/x-www-form-urlencoded format, parse it
    into a hash reference containing the decoded key/value map with possible
    Unicode in the strings.  If there are any problems, sends 400 Bad
    Request back to client and exits without returning.

    You can use this both with POSTed data in that format and also to
    interpret query strings on GET requests.  If you are reading POSTed
    data, you should use `check_form` to make sure the client sent the
    right kind of data first.

- **parse\_upload($str)**

    Given a string in multipart/form-data format, parse it into a hash
    reference containing the decoded key/value map with strings and uploaded
    files as binary string.  If there are any problems, sends 400 Bad
    Request back to client and exits without returning.

    This will call check\_upload automatically because it needs to access the
    CONTENT\_TYPE CGI environment variable to function.  This is in contrast
    to the `parse_form` function, which does not check any CGI environment
    variables.

    **Note:** Strings are always left in binary format.  This is in contrast
    to the `parse_form` function, which decodes strings to Unicode.  This
    difference is to allow for raw binary files.

    **Note:** Does not support multiple files uploaded for a single field.
    Each file control may only upload a single file.

    **Warning:** Everything parsed in memory, so if client sends huge upload,
    you can exhaust memory space.  Make sure clients are authorized before
    attempting to read what they are uploading in any way.

    You should use `check_upload` to make sure the client sent the right
    kind of data first.

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
        
        .txbox
        CSS class for text and number input boxes
        
        .pwbox
        CSS class for password input boxes
        
        .btn
        CSS class for submit buttons

    This function will also normalize all line breaks to CR+LF before
    returning the result.

- **insecure\_protocol()**

    Send an HTTP 403 Forbidden with message indicating that HTTPS is
    required back to the client and exit without returning.

- **not\_authorized()**

    Send an HTTP 403 Forbidden with message indicating client must log in
    back to the client and exit without returning.

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

    The database connection is only used during this constructor.  After the
    return from the constructor, no further reference is made to the
    database.

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
    this function returns without doing anything further.  If not, the
    `not_authorized` function is invoked.

- **getVar(key)**

    Get the cached value of a variable from the `cvars` table.  `key` is
    the name of the variable to query.  A fatal error occurs if the key is
    not recognized.  `epoch` `lastmod` `authlimit` and `authcost` are
    returned as integer values, everything else is returned as strings.
    Path variables will already have been decoded from UTF-8.

- **cookieLogin()**

    Set the special _login_ behavior for cookies when using the send
    functions.  In this behavior, a fresh verification cookie is always sent
    to the client, even if they don't have a verification cookie.  This is
    only appropriate during the login process.

    This function does not actually send any cookie header, but rather just
    changes an internal setting that will be applied when one of the send
    functions is called.

- **cookieCancel()**

    Set the special _cancel_ behavior for cookies when using the send
    functions.  In this behavior, any existing client verification cookie
    will be overwritten with an invalid value and then immediately expired.
    This is only appropriate during the logout process.  Note that this
    function does _not_ change the secret key, which should also be done
    during the logout process.

    This function does not actually send any cookie header, but rather just
    changes an internal setting that will be applied when one of the send
    functions is called.

- **cookieDefault()**

    Set the default behavior for cookies when using the send functions.
    In this behavior, a fresh verification cookie is always sent to the
    client only if the client already had a valid verification cookie; else,
    no cookie header is sent to the client.  This is the default behavior
    that is always set during construction, but you might need to use this
    function is you changed the cookie behavior to one of the special
    settings but now want to change it back.

    This function does not actually send any cookie header, but rather just
    changes an internal setting that will be applied when one of the send
    functions is called.

    **Note:**  If a logout simultaneously happens from another script, the
    default behavior is still to refresh the client cookie if they already
    had one.  This would appear to be a security flaw in that clients could
    get their cookies refreshed across a logout, which isn't supposed to be
    possible.  However, there is actually no flaw here.  All the cookie
    configuration values were cached during construction, and the refreshed
    cookie uses these cached values.  Since the cached values includes the
    secret key _before_ the logout happened, the "refreshed" cookie will
    not in fact be valid since the secret key has since changed.  This is
    the appropriate behavior.

- **customParam(name, value)**

    Add a custom template parameter that will be available to templates sent
    to the `sendTemplate` function.

    By default, all of the path variables from the `cvars` table will be
    available as template variables, with underscores prefixed to all of
    the variable names.  (So, for example, `_pathlogin` is the template
    variable for the `pathlogin` in the `cvars` table.)

    If you need more than this in the templates, you can use this function
    to add additional variables.  All custom variables must not begin with
    an underscore, so custom variables are never able to overwrite the
    standard path variables.

    If you provide a variable name that hasn't been set yet, a new custom
    variable will be defined.  If you provide a variable name that is 
    already defined, it will be overwritten with the name value.

    The name must be a string of one to 31 ASCII lowercase letters, digits,
    and underscores, where the first character is not an underscore.

    The value must either be a string (which can hold any Unicode
    codepoints, excluding surrogates) or a _template array_.  A template
    array is an array reference where each element of the array is a hash
    reference.  Each property of those hashes must have a name that is a
    sequence of one to 31 ASCII lowercase letters, digits, and underscores,
    where the first character is not an underscore.  Each value of those
    properties must either be a string (which can hold any Unicode
    codepoints, excluding surrogates) or another template array.  The
    maximum depth of nested template arrays is 64.

- **setStatus(numeric, string)**

    Set the HTTP status code that will be returned.  By default this is
    200 'OK'.

    Setting the status here will not actually send the status code.
    Instead, it will update internal state.  The status code will actually
    be sent when one of the send functions is invoked.

    The `numeric` parameter must be an integer in range 100-599.  The
    `string` parameter must be a string of US-ASCII printing characters in
    range \[U+0020, U+007E\] that names the status code.

- **sendTemplate(tcode)**

    Send a template back to the HTTP client and exit script without
    returning to caller.

    This is a wrapper around `sendHTML`.  This wrapper runs the template
    and then sends the generated templated to the `sendHTML` function.  By
    default the template variables available are all the standard path
    variables from the `cvars` table, except each of their names is
    prefixed with an underscore.  Custom parameters that were defined by the
    `customParam` function will also be available.

    See the `sendHTML` function for further details on what happens.

- **sendHTML(html)**

    Send HTML code back to the HTTP client and exit script without returning
    to caller.

    First, the core status headers are written to the client, using the MIME
    type `text/html; charset=utf-8` for the content type, sending the
    current HTTP status (200 OK by default, or else whatever it was last
    changed to with `setStatus`), and specifying `no-store` behavior for
    caching.

    Next, there may be a `Set-Cookie` header sent to the HTTP client,
    depending on the current cookie state.  See `cookieDefault` for the
    default behavior, and `cookieLogin` and `cookieCancel` for the other
    behaviors.

    The CGI response head is then finished and the HTML code is sent.
    Finally, the script exits without returning to caller.

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
