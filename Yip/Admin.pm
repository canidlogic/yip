package Yip::Admin;
use strict;

# Core dependencies
use Encode qw(decode encode);

# Non-core dependencies
use Digest::HMAC_MD5 qw(hmac_md5_hex);
use HTML::Template;
use MIME::Parser;

=head1 NAME

Yip::Admin - Common utilities for administration CGI scripts.

=head1 SYNOPSIS

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
  
  # Respond with a binary file of given type (does not return)
  $yap->sendRaw($octets, 'image/jpeg', undef);
  
  # Respond with a binary file in attachment disposition (does not
  # return)
  $yap->sendRaw($octets, 'image/jpeg', 'example.jpg');

=head1 DESCRIPTION

Module that contains common support functions for administration CGI
scripts.  Some functions are available as class methods and can be
called directly by clients, as shown in the first part of the synopsis.
Other functions need access to data in the Yip CMS database to work.
For these functions, you must construct a Yip::Admin object instance,
passing a C<Yip::DB> connection to use.  The constructor will read and
cache all necessary data from the database.  Instance methods will then
make use of the cached data (the database is not used again after
construction).  See the second half of the synopsis for examples of
using the instance functions.

=head2 General pattern

Administrator CGI scripts should always start out with a call to the
C<http_method> instance method, which does a quick check that the script
was invoked as a CGI script over HTTPS and also determines whether this
is a GET or POST request.

For most administrator CGI scripts, the next operation will be to get a
Yip CMS database connection, use that to construct a C<Yip::Admin>
object instance, and then call the C<checkCookie> instance function to
make sure that the client is authorized.  However, the login and
password reset scripts do not follow this pattern, since they must also
be able to work with clients who are not authorized yet.

Administrator CGI scripts finish in three different ways:

=over 4

=item *
Fatal error

=item *
Predefined response

=item *
Send functions

=back

The following subsections describe these three possibilities.

=head3 Fatal error handling

If a fatal error occurs with the Perl C<die> or the like, then the
response is up to the server because the CGI script will not generate a
normal CGI response in that case.  The usual server behavior is to send
a generic 500 Internal Server Error page back to the client.

If you are debugging and want more information, add the following near
the start of the CGI script to get more details on the error page:

  use CGI::Carp qw(fatalsToBrowser);

In production, this should I<not> be included, for security reasons.

Fatal errors should only occur for problems originating within the
server that have nothing to do with the client.

=head3 Predefined responses

Predefined responses are class methods provided by this module.  They
include the following:

=over 4

=item C<insecure_protocol>

Used when the client did not connect over secured HTTPS.

=item C<not_authorized>

Used when the client is not logged in with a valid cookie.

=item C<invalid_method>

Used when the client requested something other than HEAD, GET, or POST.

=item C<bad_request>

Used when the client's request is malformed.

=back

All of these predefined responses are used internally by this module,
but they are provided publicly in case clients want to use them.  (The
C<bad_request> is likely to be useful.)

Since these are class methods, you do not need a database connection or
a C<Yip::Admin> object instance to use them.  This makes them good for
responding immediately to low-level errors.

=head3 Send functions

The best way to end an administrator script is by calling either the
C<sendTemplate> or C<sendHTML> or C<sendRaw> function.  (Internally, the
function C<sendTemplate> is just a wrapper around C<sendHTML>, and the
function C<sendHTML> is just a wrapper around C<sendRaw>.)  It is
recommended that you use the C<format_html> function to generate HTML or
HTML template code in the "house style" for administrator CGI scripts.

These send functions are instance methods, so you must have an instance
of C<Yip::Admin> in order to use them.  The only difference between
C<sendTemplate> and C<sendHTML> is that the former will perform template
processing.  C<sendHTML> is just a wrapper around C<sendRaw> that
encodes the HTML to UTF-8 and then sends it along with the appropriate
MIME type for HTML in UTF-8.

By default, the template processor will make all of the standard path
variables defined in the C<cvars> table available as template variables,
except that each name is prefixed with an underscore.  If you need
additional template variables, you can define them with the
C<customParam> function, provided that none of the custom names begin
with an underscore.

By default, the send functions will use HTTP status 200 'OK'.  If you
want to set a different status, use the C<setStatus> function.

By default, the send functions will give the HTTP a refreshed
authorization cookie only if the client already has a valid
authorization cookie.  If the client has no valid authorization cookie,
the default behavior is to not send any cookie information back to the
client.  You can explicitly set this default behavior with
C<cookieDefault> if you wish.

If you want to send a refershed authorization cookie to the client in
all cases, even when the client doesn't already have a cookie, then you
should call C<cookieLogin> to always send a cookie.  This is only
appropriate for the login script when the client has authorized
themselves by providing a matching password.

If you want to cancel any authorization cookie the client may have, then
you should call C<cookieCancel>.  This will cause a cookie header to be
sent to the client that overwrites any existing authorization cookie
with an invalid value and immediately expires it.  This is appropriate
for the logout script and the password reset script after the password
has been changed.  But note that this does I<not> update the secret key
in the database, which should be done in a proper logout.

=head2 Configuration variable access

The C<Yip::Admin> object instance caches all configuration variables, so
administrator CGI scripts can just use the C<getVar> instance method to
access these cached copies.

=head2 POST data access

For C<POST> request handling, you can read all the raw bytes that the
client sent you using the C<read_client> class method.  B<Do not slurp
all input from standard input!>  According to the CGI standard, CGI
scripts should only read the amount of bytes indicated by the
C<CONTENT_LENGTH> environment variable from standard input.  The
C<read_client> class method will handle this correctly.

If the POSTed client data is in the usual form data format of
C<application/x-www-form-urlencoded> then you can use the class method
C<parse_form> to decode it into a hashref, which includes Unicode
support.

=head2 HTML formatting

The C<format_html> class method is used by all the predefined responses
and should be used by administrator CGI scripts to ensure a consistent
HTML style across all administrator CGI scripts.  This can be used both
for HTML pages and HTML templates.  A standard CSS stylesheet will be
included, as well as consistent headers.  See the documentation of the
function for further information.

=cut

# =========
# Constants
# =========

# The boilerplate code, divided into sections, which is used by the
# format_html function
#
my $boilerplate_1 = q{<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <title>};

my $boilerplate_2 = q{</title>
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0"/>
    <style>

body {
  padding-left: 0.5em;
  padding-right: 0.5em;
  padding-bottom: 5em;
  font-family: sans-serif;
  max-width: 35em;
  margin-left: auto;
  margin-right: auto;
  background-color: rgb(222, 222, 222);
  color: black;
}

:link {
  text-decoration: none;
  color: blue
}

:visited {
  text-decoration: none;
  color: blue
}

h1 {
  font-family: sans-serif;
}

#homelink {
  margin-top: 0;
  margin-bottom: 2em;
  font-size: larger;
}

form {
  margin-top: 2em;
}

.ctlbox {
  margin-top: 0.75em;
  margin-bottom: 0.5em;
}

.ctlbox div {
  margin-top: 0.25em;
  margin-right: 1em;
}

.btnbox {
  margin-top: 0.75em;
  margin-bottom: 0.5em;
  text-align: right;
}

.pwbox {
  width: 100%;
  border: thin solid;
  padding: 0.5em;
}

.btn {
  border: medium outset;
  padding: 0.5em;
  font-size: larger;
  cursor: pointer;
}

.btn:active {
  border: medium inset;
}

.txbox {
  width: 100%;
  border: thin solid;
  padding: 0.5em;
  font-family: monospace;
}

textarea {
  width: 100%;
  height: 12em;
  border: thin solid;
  padding: 0.5em;
  font-family: monospace;
  resize: vertical;
}

.slbox {
  width: 100%;
  border: thin solid;
  padding: 0.5em;
  font-family: monospace;
  background-color: white;
}

    </style>
  </head>
  <body>};

my $boilerplate_3 = q{  </body>
</html>
};

# The complete response message sent if client is not in HTTPS
#
my $err_insecure =
  "Content-Type: text/html; charset=utf-8\r\n"
  . "Status: 403 Forbidden\r\n"
  . "Cache-Control: no-store\r\n"
  . "\r\n"
  . Yip::Admin->format_html('403 Forbidden', q{
    <h1>403 Forbidden</h1>
    <p>You must use HTTPS to access this script.</p>
});

# The complete response message sent if client is not authorized
#
my $err_unauth =
  "Content-Type: text/html; charset=utf-8\r\n"
  . "Status: 403 Forbidden\r\n"
  . "Cache-Control: no-store\r\n"
  . "\r\n"
  . Yip::Admin->format_html('403 Forbidden', q{
    <h1>403 Forbidden</h1>
    <p>You must be logged in to use this script.</p>
});

# Standard response sent when client indicates method not supported
#
my $err_method =
  "Content-Type: text/html; charset=utf-8\r\n"
  . "Status: 405 Method Not Allowed\r\n"
  . "Cache-Control: no-store\r\n"
  . "\r\n"
  . Yip::Admin->format_html('405 Method Not Allowed', q{
    <h1>405 Method Not Allowed</h1>
    <p>Unsupported HTTP request method was used.</p>
});

# Standard response sent when client didn't send a valid POST request
#
my $err_request =
  "Content-Type: text/html; charset=utf-8\r\n"
  . "Status: 400 Bad Request\r\n"
  . "Cache-Control: no-store\r\n"
  . "\r\n"
  . Yip::Admin->format_html('400 Bad Request', q{
    <h1>400 Bad Request</h1>
    <p>Client did not send a valid request.</p>
});

# ===============
# Local functions
# ===============

# valid_tval(val, depth)
#
# Check whether the given val parameter is valid as a template variable
# value.  depth counts the depth of template array nesting, and must be
# an integer that is greater than zero; it should be set to one by
# callers.
#
# The first check is that the depth does not exceed 64.  Each time there
# is a nested template array, the depth will increase by one.  This
# prevents loops within references.
#
# The second check is that val is either a scalar or an array reference.
#
# If val is a scalar, then it is checked as a string that each element
# is in Unicode codepoint range and nothing is in surrogate range.
#
# If val is an array reference, then it is checked that every array
# element is a hash reference.  (An empty array is also OK.)  Each of
# this referenced hashes must have each property name be a string of one
# to 31 ASCII lowercase letters, digits, and underscores, where the
# first character is not an underscore.  Each property value must
# recursively satisfy valid_tval() with the depth increased by one.
#
# Return value is 1 if valid, 0 if not valid.
#
sub valid_tval {
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get parameters and check
  my $val   = shift;
  my $depth = shift;
  
  ((not ref($depth)) and (int($depth) == $depth)) or
    die "Wrong parameter type, stopped";
  $depth = int($depth);
  ($depth > 0) or die "Invalid parameter value, stopped";
  
  # Check depth
  ($depth <= 64) or return 0;
  
  # Check cases
  if (not ref($val)) {
    # Scalar, check string
    ($val =~ /\A[\x{0}-\x{d7ff}\x{e000}-\x{10ffff}]*\z/) or return 0;
    
  } elsif (ref($val) eq 'ARRAY') {
    # Array reference, check each element
    for my $e (@$val) {
    
      # Make sure element is a hash reference
      (ref($e) eq 'HASH') or return 0;
      
      # Check each property of the hash reference
      for my $p (keys %$e) {
      
        # Check property name
        ($p =~ /\A[a-z0-9][a-z0-9_]{0,30}\z/) or return 0;
        
        # Recursively check property value
        (valid_tval($e->{$p}, $depth + 1)) or return 0;
      }
    }
  
  } else {
    # Not a scalar and not an array ref
    return 0;
  }
  
  # If we got here, it checks out
  return 1;
}

# encode_tval(val, depth)
#
# Make a deep copy of the given val parameter and make sure that all
# strings are encoded into UTF-8 in the copy.  depth counts the depth of
# template array nesting, and must be an integer that is greater than
# zero; it should be set to one by callers.
#
# First, the function checks that the depth does not exceed 64, or a
# fatal error occurs.  Each time there is a nested template array, the
# depth will increase by one.  This prevents loops within references.
#
# If val is a scalar, then it will be encoded as a binary string into
# UTF-8 and the encoded string will be returned.
#
# If val is an array reference, then a new array will be created and
# copies of each element made one by one.  (Empty array is also OK.)
# Each element must be a hash ref.  A new hash ref is created in the
# copy, an each property is copied over.  However, property values are
# recursively copied with encode_tval(), except the depth is increased
# by one.  The return value is an array reference to the encoded copy.
#
sub encode_tval {
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get parameters and check depth
  my $val   = shift;
  my $depth = shift;
  
  ((not ref($depth)) and (int($depth) == $depth)) or
    die "Wrong parameter type, stopped";
  $depth = int($depth);
  (($depth > 0) and ($depth <= 64)) or
    die "Depth out of range, stopped";
  
  # Handle cases
  if (not ref($val)) {
    # Scalar, return encoded string
    return encode('UTF-8', $val, Encode::FB_CROAK);
    
  } elsif (ref($val) eq 'ARRAY') {
    # Array reference, make new array
    my @na;
    
    # Copy all elements and encode them
    for my $e (@$val) {
    
      # Make sure element is a hash reference
      (ref($e) eq 'HASH') or die "Invalid array element, stopped";
      
      # Create new hash
      my $hv = { };
      
      # Encode each property
      for my $p (keys %$e) {
        $hv->{$p} = encode_tval($e->{$p}, $depth + 1);
      }
      
      # Add the hash reference to the array
      push @na, ($hv);
    }
    
    # Return reference to encoded array
    return \@na;
  
  } else {
    # Not a scalar and not an array ref
    die "Invalid value type, stopped";
  }
}

=head1 CLASS METHODS

=over 4

=item B<http_method()>

Check that there is a CGI environment variable REQUEST_METHOD and fatal
error if not.  Then, get the REQUEST_METHOD and normalize it to 'GET' or
'POST'.  If it can't be normalized to one of those two, invoke
invalid_method.  Next, check that the CGI environment variable HTTPS is
defined, invoking insecure_protocol if it is not.  Finally, return the
normalized method, which is either 'GET' or 'HEAD'.

=cut

sub http_method {
  # Check parameter count
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # REQUEST_METHOD must be defined
  (exists $ENV{'REQUEST_METHOD'}) or
    die "Script must be invoked as a CGI script, stopped";
  
  # Get method and normalize to GET or POST
  my $request_method = $ENV{'REQUEST_METHOD'};
  if (($request_method =~ /\AGET\z/i)
      or ($request_method =~ /\AHEAD\z/i)) {
    $request_method = "GET";
  
  } elsif ($request_method =~ /\APOST\z/i) {
    $request_method = "POST";
  
  } else {
    Yip::Admin->invalid_method();
  }
  
  # Make sure we are in HTTPS
  (exists $ENV{'HTTPS'}) or Yip::Admin->insecure_protocol;
  
  # Return the normalized method
  return $request_method;
}

=item B<check_form()>

Check that CGI environment variable REQUEST_METHOD is set to POST or
fatal error otherwise.  Then, check that there is a CGI environment
variable CONTENT_TYPE that is C<application/x-www-form-urlencoded> or
else send 400 Bad Request back to client.

=cut

sub check_form {
  # Check parameter count
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Make sure we are in POST mode
  (exists $ENV{'REQUEST_METHOD'}) or
    die "Must use in CGI script, stopped";
  ($ENV{'REQUEST_METHOD'} =~ /\APOST\z/i) or
    die "Must use with POST method, stopped";
  
  # Check that CONTENT_TYPE is correctly defined
  (exists $ENV{'CONTENT_TYPE'}) or Yip::Admin->bad_request();
  ($ENV{'CONTENT_TYPE'} =~
    /\Aapplication\/x-www-form-urlencoded(?:;.*)?\z/i) or
    Yip::Admin->bad_request();
}

=item B<check_upload()>

Check that CGI environment variable REQUEST_METHOD is set to POST or
fatal error otherwise.  Then, check that there is a CGI environment
variable CONTENT_TYPE that is C<multipart/form-data> or else send 400
Bad Request back to client.

=cut

sub check_upload {
  # Check parameter count
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Make sure we are in POST mode
  (exists $ENV{'REQUEST_METHOD'}) or
    die "Must use in CGI script, stopped";
  ($ENV{'REQUEST_METHOD'} =~ /\APOST\z/i) or
    die "Must use with POST method, stopped";
  
  # Check that CONTENT_TYPE is correctly defined
  (exists $ENV{'CONTENT_TYPE'}) or Yip::Admin->bad_request();
  ($ENV{'CONTENT_TYPE'} =~
    /\Amultipart\/form-data(?:;.*)?\z/i) or
    Yip::Admin->bad_request();
}

=item B<read_client()>

Read data sent by an HTTP client and return it as a raw binary string.

First, this checks that the CGI environment variable REQUEST_METHOD is
defined as POST, causing a fatal error if it is not.  Next, this checks
for CONTENT_LENGTH environment variable, then reads exactly that from
standard input, returning the raw bytes in a binary string.  If
CONTENT_LENGTH is zero or empty or not defined, then an empty string is
returned instead.

Fatal errors occur if there are any problems with the CONTENT_LENGTH
variable or with reading the data.

B<Note:> This function might set standard input into raw binary mode.

=cut

sub read_client {
  # Check parameter count
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Make sure we are in POST mode
  (exists $ENV{'REQUEST_METHOD'}) or
    die "Must use in CGI script, stopped";
  ($ENV{'REQUEST_METHOD'} =~ /\APOST\z/i) or
    die "Must use with POST method, stopped";
  
  # Start with an empty data result string
  my $data = '';
  
  # Only proceed if CONTENT_LENGTH is defined and not empty and not
  # zero
  if ((defined $ENV{'CONTENT_LENGTH'}) and
        (not ($ENV{'CONTENT_LENGTH'} =~ /\A0*\z/))) {
    
    # Parse (non-zero) content length
    ($ENV{'CONTENT_LENGTH'} =~ /\A0*[1-9][0-9]{0,8}\z/) or
      die "Invalid content length, stopped";
    my $clen = int($ENV{'CONTENT_LENGTH'});
    
    # Set raw input
    binmode(STDIN, ":raw") or die "Failed to set binary input, stopped";
    
    # Read the data
    (sysread(STDIN, $data, $clen) == $clen) or
      die "Failed to read POSTed data, stopped";
  }
  
  # Return the data or empty string
  return $data;
}

=item B<parse_form($str)>

Given a string in application/x-www-form-urlencoded format, parse it
into a hash reference containing the decoded key/value map with possible
Unicode in the strings.  If there are any problems, sends 400 Bad
Request back to client and exits without returning.

You can use this both with POSTed data in that format and also to
interpret query strings on GET requests.  If you are reading POSTed
data, you should use C<check_form> to make sure the client sent the
right kind of data first.

=cut

sub parse_form {
  # Check parameter count
  ($#_ == 1) or die "Wrong number of arguments, stopped";
  
  # Ignore class argument
  shift;
  
  # Get the string argument
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  $str = "$str";
  
  # Make sure string is 7-bit US-ASCII (Unicode should be encoded in
  # percent escapes)
  ($str =~ /\A[ \t\r\n\x{20}-\x{7e}]*\z/) or Yip::Admin->bad_request();
  
  # Drop all literal whitespace (actual whitespace is encoded)
  $str =~ s/[ \t\r\n]+//g;
  
  # Drop any trailing ampersands
  $str =~ s/&+\z//;
  
  # Split into definitions separated by ampersands
  my @dfs = split /&/, $str;
  
  # Start the hash off empty
  my %result;
  
  # Add all definitions
  for my $ds (@dfs) {
    # Parse this definition string into encoded name and encoded value
    ($ds =~ /\A([^=]+)=(.*)\z/) or Yip::Admin->bad_request();
    my $dname = $1;
    my $dval  = $2;
    
    # Decode both the same way
    for(my $i = 0; $i < 2; $i++) {
    
      # Get the current value we are decoding
      my $v;
      if ($i == 0) {
        $v = $dname;
      } elsif ($i == 1) {
        $v = $dval;
      } else {
        die "Unexpected";
      }
      
      # First decoding step is replace plus signs by spaces
      $v =~ s/\+/ /g;
      
      # Second decoding step is to replace percent escapes for literal
      # percents with special character 0x100 which will be handled
      # specially later
      $v =~ s/%25/\x{100}/g;
      
      # Find the positions of all percent escapes
      my @pci;
      while ($v =~ /%[0-9A-Fa-f]{2}/g) {
        push @pci, (pos($v) - 3);
      }
      
      # Starting with last percent escape and moving to first, replace
      # all with the encoded byte values
      for(my $j = $#pci; $j >= 0; $j--) {
        # Get the encoded character as a string
        my $ec = chr(hex(substr($v, $pci[$j] + 1, 2)));
        
        # Splice the character back into the string
        substr($v, $pci[$j], 3) = $ec;
      }
      
      # Make sure there are no remaining percents (encoded percents were
      # temporarily set to 0x100 recall)
      (not ($v =~ /%/)) or Yip::Admin->bad_request();
      
      # Now replace 0x100 with percent signs to get the decoded binary
      # string
      $v =~ s/\x{100}/%/g;
      
      # Decode binary string as UTF-8
      eval {
        $v = decode('UTF-8', $v, Encode::FB_CROAK);
      };
      if ($@) {
        Yip::Admin->bad_request();
      }
      
      # Update with the decoded value
      if ($i == 0) {
        $dname = $v;
      } elsif ($i == 1) {
        $dval = $v;
      } else {
        die "Unexpected";
      }
    }
    
    # Make sure we don't already have this variable
    (not (exists $result{$dname})) or Yip::Admin->bad_request();
    
    # Add variable to hash result
    $result{$dname} = $dval;
  }
  
  # Return result reference
  return \%result;
}

=item B<parse_upload($str)>

Given a string in multipart/form-data format, parse it into a hash
reference containing the decoded key/value map with strings and uploaded
files as binary string.  If there are any problems, sends 400 Bad
Request back to client and exits without returning.

This will call check_upload automatically because it needs to access the
CONTENT_TYPE CGI environment variable to function.  This is in contrast
to the C<parse_form> function, which does not check any CGI environment
variables.

B<Note:> Strings are always left in binary format.  This is in contrast
to the C<parse_form> function, which decodes strings to Unicode.  This
difference is to allow for raw binary files.

B<Note:> Does not support multiple files uploaded for a single field.
Each file control may only upload a single file.

B<Warning:> Everything parsed in memory, so if client sends huge upload,
you can exhaust memory space.  Make sure clients are authorized before
attempting to read what they are uploading in any way.

You should use C<check_upload> to make sure the client sent the right
kind of data first.

=cut

sub parse_upload {
  # Check parameter count
  ($#_ == 1) or die "Wrong number of arguments, stopped";
  
  # Ignore class argument
  shift;
  
  # Get the string argument
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";

  # Make sure the CGI environment state is correct
  Yip::Admin->check_upload;
  
  # Insert the Content-Type header so that we can parse the MIME
  # correctly
  my $ct = $ENV{'CONTENT_TYPE'};
  $ct =~ s/\A[ \t]+//;
  $ct =~ s/[ \t\r\n]+\z//;
  $str = "Content-Type: $ct\r\n\r\n" . $str;

  # Create MIME parser with everything set to in-memory mode
  my $parser = new MIME::Parser;
  $parser->output_to_core(1);
  $parser->tmp_to_core(1);
  
  # Parse the data into an entity
  my $entity;
  eval {
    $entity = $parser->parse_data($str);
  };
  if ($@) {
    Yip::Admin->bad_request;
  }

  # Check that MIME object is appropriate type and multipart
  ($entity->effective_type =~ /\Amultipart\/form-data(?:;.*)?\z/i) or
    Yip::Admin->bad_request;
  ($entity->is_multipart) or Yip::Admin->bad_request;
  
  # Start the hash off empty
  my %result;
  
  # Go through each MIME part
  my $part_count = scalar($entity->parts);
  for(my $i = 0; $i < $part_count; $i++) {
    # Get the current part
    my $part = $entity->parts($i);
    
    # We don't support multi-file controls, so no part should be
    # recursively multipart
    (not $part->is_multipart) or Yip::Admin->bad_request;
    
    # Make sure this is form data
    ($part->head->mime_attr('content-disposition') =~
        /\Aform\-data\z/i) or Yip::Admin->bad_request;
    
    # Get the data field name
    my $dfield = $part->head->mime_attr('content-disposition.name');
    (defined $dfield) or Yip::Admin->bad_request;
    
    # Make sure field name not defined yet in hash
    (not (exists $result{$dfield})) or Yip::Admin->bad_request;
    
    # Store all the body data in the hash
    $result{$dfield} = $part->bodyhandle->as_string;
  }
  
  # Return result reference
  return \%result;
}

=item B<format_html(title, body_code)>

Generate HTML or an HTML template according to the "house style" for
administration scripts.  C<title> is the page title to write into the
head section I<which should be escaped properly> but I<not> include the
surrounding title element start and end blocks.  C<body_code> is what
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

=cut

sub format_html {
  
  # Check parameter count
  ($#_ == 2) or die "Wrong number of arguments, stopped";
  
  # Drop the class argument
  shift;
  
  # Get parameters and check
  my $title = shift;
  my $body  = shift;
  
  (not ref($title)) or die "Wrong parameter type, stopped";
  (not ref($body )) or die "Wrong parameter type, stopped";
  
  $title = "$title";
  $body  = "$body";
  
  # Assemble the full code
  my $code =
    $boilerplate_1
    . $title
    . $boilerplate_2
    . $body
    . $boilerplate_3;
  
  # Normalize line breaks to CR+LF
  $code =~ s/\r//g;
  $code =~ s/\n/\r\n/g;
  
  # Return assembled code
  return $code;
}

=item B<insecure_protocol()>

Send an HTTP 403 Forbidden with message indicating that HTTPS is
required back to the client and exit without returning.

=cut

sub insecure_protocol {
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  binmode(STDOUT, ":raw") or die "Failed to set binary output, stopped";
  print encode('UTF-8', $err_insecure, Encode::FB_CROAK);
  exit;
}

=item B<not_authorized()>

Send an HTTP 403 Forbidden with message indicating client must log in
back to the client and exit without returning.

=cut

sub not_authorized {
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  binmode(STDOUT, ":raw") or die "Failed to set binary output, stopped";
  print encode('UTF-8', $err_unauth, Encode::FB_CROAK);
  exit;
}

=item B<invalid_method()>

Send an HTTP 405 Method Not Allowed back to the client and exit without
returning.

=cut

sub invalid_method {
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  binmode(STDOUT, ":raw") or die "Failed to set binary output, stopped";
  print encode('UTF-8', $err_method, Encode::FB_CROAK);
  exit;
}

=item B<bad_request()>

Send an HTTP 400 Bad Request back to the client and exit without
returning.

=cut

sub bad_request {
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  binmode(STDOUT, ":raw") or die "Failed to set binary output, stopped";
  print encode('UTF-8', $err_request, Encode::FB_CROAK);
  exit;
}

=back

=head1 CONSTRUCTOR

=over 4

=item B<load(dbc)>

Construct a new administrator utilities object.  C<dbc> is the
C<Yip::DB> object that should be used to load the configuration
variables.  All the configuration variables will be loaded in a single
read-only work block.  If you want all database activity to be in a
single transaction, including this configuration load, you should begin
a work block on the C<Yip::DB> object before calling this constructor.

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

You can set all these variables using the C<resetdb.pl> script.  Any
variables beyond the ones listed above will be ignored.

All of the path variables will be decoded from UTF-8 into a Unicode
string and checked that they begin with a slash.  The C<epoch>
C<lastmod> C<authlimit> and C<authcost> variables will be range-checked
and decoded into integer values.  All other variables will be checked
and stored as strings.  Fatal errors occur if there are any problems.

Finally, the constructor checks for a CGI environment variable named
C<HTTP_COOKIE>.  If the environment variable is present and it contains
a valid list of cookies that includes a cookie with name C<__Host->
suffixed with the C<authsuffix> value, and this cookie consists of a
valid verification payload, then an internal flag will be set indicating
that the client is verified.  In all other cases, the internal flag will
be cleared indicating the client is not verified.

A valid verification payload is two base-16 strings separated by a
vertical bar.  The first base-16 string is the number of minutes since
the Unix epoch and the second base-16 string is an HMAC-MD5 digest using
the C<authsecret> value as the secret key.  Apart from the HMAC-MD5
being valid, the time encoded in the payload must not be further than
C<authlimit> minutes in the past, and must not be more than one minute
in the future.

=cut

sub load {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameter
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Yip::DB')) or
    die "Wrong parameter type, stopped";
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_cvar' property will store the configuration variables
  $self->{'_cvar'} = { };
  
  # The '_verify' property will be set only if a valid verification
  # cookie is detected
  $self->{'_verify'} = 0;
  
  # The '_cookie' property stores cookie behavior for the send
  # functions; the default value of zero means refresh client cookie if
  # the client already has a valid cookie; a value of one means always
  # send client fresh cookie even if they don't have one; a value of -1
  # means cancel the client's cookie
  $self->{'_cookie'} = 0;
  
  # The '_tvar' property is a reference to a hash that stores template
  # variables; it will be initialized with all the path variables, with
  # an underscore prefixed to each of the path variable names; clients
  # can later add their own custom parameters provided that those names
  # don't begin with an underscore
  $self->{'_tvar'} = { };
  
  # The '_status' property is a reference to an array of two values, the
  # first of which is the integer HTTP status code and the second of
  # which is the string description
  $self->{'_status'} = [200, 'OK'];
  
  # Create a hash where all recognized configuration variables are
  # initially mapped to zero
  my %ch = (
    'epoch'        => 0,
    'lastmod'      => 0,
    'authsuffix'   => 0,
    'authsecret'   => 0,
    'authlimit'    => 0,
    'authcost'     => 0,
    'authpswd'     => 0,
    'pathlogin'    => 0,
    'pathlogout'   => 0,
    'pathreset'    => 0,
    'pathadmin'    => 0,
    'pathlist'     => 0,
    'pathdrop'     => 0,
    'pathedit'     => 0,
    'pathupload'   => 0,
    'pathimport'   => 0,
    'pathdownload' => 0,
    'pathexport'   => 0,
    'pathgenuid'   => 0
  );
  
  # Load all the configuration variables
  my $dbh = $dbc->beginWork('r');
  my $qr  = $dbh->selectall_arrayref(
              'SELECT cvarskey, cvarsval FROM cvars');
  (ref($qr) eq 'ARRAY') or die
    "Failed to load variables, stopped";
  
  for my $q (@$qr) {
    
    # Get current property key and value
    my $k    = $q->[0];
    my $pval = $q->[1];
    
    # Ignore if not recognized
    unless (exists $ch{$k}) {
      next;
    }
    
    # Check that not yet defined and then set flag
    (not $ch{$k}) or die "Duplicate variable, stopped";
    $ch{$k} = 1;
    
    # Check the property value string, decoding from UTF-8 for paths
    if (($k eq 'epoch') or ($k eq 'lastmod')) {
      (($pval =~ /\A[0-9A-Fa-f]{1,13}\z/) or
        ($pval =~ /\A1[0-9A-Fa-f]{13}\z/)) or
        die "Variable '$k' out of range, stopped";
    
    } elsif ($k eq 'authsuffix') {
      ($pval =~ /\A[A-Za-z0-9_]{1,24}\z/) or
        die "Variable '$k' is invalid, stopped";
        
    } elsif ($k eq 'authsecret') {
      ($pval =~ /\A[A-Za-z0-9\+\/]{16}\z/) or
        die "Variable '$k' is invalid, stopped";
      
    } elsif ($k eq 'authlimit') {
      ($pval =~ /\A0*[1-9][0-9]{0,9}\z/) or
        die "Variable '$k' is invalid, stopped";
      
    } elsif ($k eq 'authcost') {
      ($pval =~ /\A0*[1-9][0-9]?\z/) or
        die "Variable '$k' is invalid, stopped";
    
    } elsif ($k eq 'authpswd') {
      ($pval =~ /\A[\x{21}-\x{7e}]+\z/) or
        die "Variable '$k' is invalid, stopped";
      
    } elsif ($k =~ /\Apath/) {
      $pval = decode('UTF-8', $pval, Encode::FB_CROAK);
      ($pval =~ /\A\//) or
        die "Variable '$k' is invalid, stopped";
      
    } else {
      die "Unexpected";
    }
    
    # Convert integer values to integers and range-check them
    if ($k eq 'epoch') {
      $pval = hex($pval);
      (($pval >= 0) and ($pval <= 0x1fffffffffffff)) or
        die "Variable '$k' is invalid, stopped";
      
    } elsif ($k eq 'lastmod') {
      $pval = hex($pval);
      (($pval >= 0) and ($pval <= 0xffffffff)) or
        die "Variable '$k' is invalid, stopped";
      
    } elsif ($k eq 'authlimit') {
      $pval = int($pval);
      ($pval > 0) or die "Variable '$k' is invalid, stopped";
      
    } elsif ($k eq 'authcost') {
      $pval = int($pval);
      (($pval >= 5) and ($pval <= 31)) or
        die "Variable '$k' is invalid, stopped";
    }
    
    # Store the variable in the cache
    $self->{'_cvar'}->{$k} = $pval;
  }
  
  $dbc->finishWork;
  
  # Make sure all configuration variables were loaded
  for my $pname (keys %ch) {
    ($ch{$pname}) or die "Variable '$pname' undefined, stopped";
  }
  
  # Add all the path variables to the template variable hash, with an
  # underscore prefixed to their names; also, encode their values into
  # UTF-8 since the template processor works in binary
  for my $pname (keys %ch) {
    if ($pname =~ /\Apath/) {
      $self->{'_tvar'}->{"_$pname"} = encode(
                                        'UTF-8',
                                        $self->{'_cvar'}->{$pname},
                                        Encode::FB_CROAK);
    }
  }
  
  # Proceed with cookie check if cookie environment variable
  if (exists $ENV{'HTTP_COOKIE'}) {
    
    # Split the cookie jar into definitions
    my @jar = split /;/, $ENV{'HTTP_COOKIE'};
    
    # Determine the cookie name we look for
    my $target_cookie = '__Host-' . $self->{'_cvar'}->{'authsuffix'};
    
    # Look through each definition for the verification cookie
    for my $ck (@jar) {
      # Drop whitespace
      $ck =~ s/[ \t\r\n]+//g;
      
      # Only proceed if we can parse the cookie
      if ($ck =~ /\A([A-Za-z0-9_\-]+)=([\x{21}-\x{7e}]+)\z/) {
      
        # Get name and value
        my $ck_name = $1;
        my $ck_val  = $2;
        
        # Only proceed if name matches
        if ($ck_name eq $target_cookie) {
          
          # Parse the payload or fail verification
          ($ck_val =~ /\A([0-9A-Fa-f]{1,13})\|([0-9A-Fa-f]{32})\z/) or
            last;
          my $ck_htime = $1;
          my $ck_hmac  = $2;
          
          my $ck_time  = hex($1);
          $ck_hmac  =~ tr/A-Z/a-z/;
          $ck_htime =~ tr/A-Z/a-z/;
          
          # Get current timestamp in minutes
          my $c_min = int(time / 60);
          
          # Make sure cookie time not more than one minute in future
          ($ck_time <= $c_min + 1) or last;
          
          # Make sure cookie time not too far in the past
          ($c_min - $ck_time <= $self->{'_cvar'}->{'authlimit'}) or
            last;
          
          # Check HMAC and set verify flag only if equal to payload
          # value
          if (hmac_md5_hex($ck_htime, $self->{'_cvar'}->{'authsecret'})
                eq $ck_hmac) {
            $self->{'_verify'} = 1;
          }
        }
      }
    }
  }
  
  # Return the new object
  return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item B<hasCookie()>

Returns 1 if the HTTP client has a valid verification cookie, 0 if not.
You should only use this function if the script supports both authorized
and unauthorized clients.  In the more usual case that only authorized
clients are allowed, see C<checkCookie>.

=cut

sub hasCookie {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return result
  return $self->{'_verify'};
}

=item B<checkCookie()>

Make sure the HTTP client has a valid verification cookie.  If so, then
this function returns without doing anything further.  If not, the
C<not_authorized> function is invoked.

=cut

sub checkCookie {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Print error if client not authorized
  ($self->{'_verify'}) or Yip::Admin->not_authorized;
}

=item B<getVar(key)>

Get the cached value of a variable from the C<cvars> table.  C<key> is
the name of the variable to query.  A fatal error occurs if the key is
not recognized.  C<epoch> C<lastmod> C<authlimit> and C<authcost> are
returned as integer values, everything else is returned as strings.
Path variables will already have been decoded from UTF-8.

=cut

sub getVar {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self and parameter
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $k = shift;
  (not ref($k)) or die "Wrong parameter type, stopped";
  $k = "$k";
  
  # Check that key is known
  (exists $self->{'_cvar'}->{$k}) or die "Unrecognized key, stopped";
  
  # Return the cached key value
  return $self->{'_cvar'}->{$k};
}

=item B<cookieLogin()>

Set the special I<login> behavior for cookies when using the send
functions.  In this behavior, a fresh verification cookie is always sent
to the client, even if they don't have a verification cookie.  This is
only appropriate during the login process.

This function does not actually send any cookie header, but rather just
changes an internal setting that will be applied when one of the send
functions is called.

=cut

sub cookieLogin {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Set state
  $self->{'_cookie'} = 1;
}

=item B<cookieCancel()>

Set the special I<cancel> behavior for cookies when using the send
functions.  In this behavior, any existing client verification cookie
will be overwritten with an invalid value and then immediately expired.
This is only appropriate during the logout process.  Note that this
function does I<not> change the secret key, which should also be done
during the logout process.

This function does not actually send any cookie header, but rather just
changes an internal setting that will be applied when one of the send
functions is called.

=cut

sub cookieCancel {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Set state
  $self->{'_cookie'} = -1;
}

=item B<cookieDefault()>

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

B<Note:>  If a logout simultaneously happens from another script, the
default behavior is still to refresh the client cookie if they already
had one.  This would appear to be a security flaw in that clients could
get their cookies refreshed across a logout, which isn't supposed to be
possible.  However, there is actually no flaw here.  All the cookie
configuration values were cached during construction, and the refreshed
cookie uses these cached values.  Since the cached values includes the
secret key I<before> the logout happened, the "refreshed" cookie will
not in fact be valid since the secret key has since changed.  This is
the appropriate behavior.

=cut

sub cookieDefault {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Set state
  $self->{'_cookie'} = 0;
}

=item B<customParam(name, value)>

Add a custom template parameter that will be available to templates sent
to the C<sendTemplate> function.

By default, all of the path variables from the C<cvars> table will be
available as template variables, with underscores prefixed to all of
the variable names.  (So, for example, C<_pathlogin> is the template
variable for the C<pathlogin> in the C<cvars> table.)

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
codepoints, excluding surrogates) or a I<template array>.  A template
array is an array reference where each element of the array is a hash
reference.  Each property of those hashes must have a name that is a
sequence of one to 31 ASCII lowercase letters, digits, and underscores,
where the first character is not an underscore.  Each value of those
properties must either be a string (which can hold any Unicode
codepoints, excluding surrogates) or another template array.  The
maximum depth of nested template arrays is 64.

=cut

sub customParam {
  
  # Check parameter count
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  # Get self and parameters
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $tname = shift;
  my $tval  = shift;
  
  (not ref($tname)) or die "Wrong parameter type, stopped";
  $tname = "$tname";
  
  ($tname =~ /\A[a-z0-9][a-z0-9_]{0,30}\z/) or
    die "Invalid parameter name, stopped";
  (valid_tval($tval, 1)) or die "Invalid parameter value, stopped";
  
  # Set parameter, making a copy and encoding it into UTF-8 since
  # template processor works in binary
  $self->{'_tvar'}->{$tname} = encode_tval($tval, 1);
}

=item B<setStatus(numeric, string)>

Set the HTTP status code that will be returned.  By default this is
200 'OK'.

Setting the status here will not actually send the status code.
Instead, it will update internal state.  The status code will actually
be sent when one of the send functions is invoked.

The C<numeric> parameter must be an integer in range 100-599.  The
C<string> parameter must be a string of US-ASCII printing characters in
range [U+0020, U+007E] that names the status code.

=cut

sub setStatus {
  
  # Check parameter count
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  # Get self and parameters
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $snum = shift;
  my $sstr = shift;
  
  ((not ref($snum)) and (not ref($sstr))) or
    die "Wrong parameter type, stopped";
  (int($snum) == $snum) or die "Wrong parameter type, stopped";
  
  $snum = int($snum);
  $sstr = "$sstr";
  
  (($snum >= 100) and ($snum <= 599)) or
    die "Status code out of range, stopped";
  ($sstr =~ /\A[\x{20}-\x{7e}]*\z/) or
    die "Invalid status code description, stopped";
  
  # Set status
  $self->{'_status'}->[0] = $snum;
  $self->{'_status'}->[1] = $sstr;
}

=item B<sendTemplate(tcode)>

Send a template back to the HTTP client and exit script without
returning to caller.

This is a wrapper around C<sendHTML>.  This wrapper runs the template
and then sends the generated templated to the C<sendHTML> function.  By
default the template variables available are all the standard path
variables from the C<cvars> table, except each of their names is
prefixed with an underscore.  Custom parameters that were defined by the
C<customParam> function will also be available.

See the C<sendHTML> function for further details on what happens.

=cut

sub sendTemplate {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self and parameter
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $tcode = shift;
  (not ref($tcode)) or die "Wrong parameter type, stopped";
  $tcode = "$tcode";
  
  # HTML::Template works with binary strings, so encode UTF-8
  $tcode = encode('UTF-8', $tcode, Encode::FB_CROAK);
  
  # Open the template
  my $template = HTML::Template->new(
                    scalarref => \$tcode,
                    die_on_bad_params => 0,
                    no_includes => 1);
  
  # Set template parameters
  $template->param($self->{'_tvar'});
  
  # Compile template
  my $html = $template->output;
  
  # Get back a Unicode string
  $html = decode('UTF-8', $html, Encode::FB_CROAK);
  
  # Send the HTML
  $self->sendHTML($html);
}

=item B<sendHTML(html)>

Send HTML code back to the HTTP client and exit script without returning
to caller.

This is a wrapper around sendRaw that encodes the given string into
UTF-8 and then sends it along with C<text/html; charset=utf-8> as the
MIME type.

See the C<sendRaw> function for further details on what happens.

=cut

sub sendHTML {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self and parameter
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $html = shift;
  (not ref($html)) or die "Wrong parameter type, stopped";
  $html = "$html";
  
  # Encode HTML into UTF-8
  $html = encode('UTF-8', $html, Encode::FB_CROAK);
  
  # Send the response
  $self->sendRaw($html, 'text/html; charset=utf-8', undef);
}

=item B<sendRaw(octets, mime, filename)>

Send a raw resource back to the HTTP client and exit script without
returning to caller.

C<octets> is a raw binary string containing the data to send.  C<mime>
is the MIME type of the data, which must be a sequence of printing ASCII
characters in range [U+0020, U+007E].

C<filename> should normally be undefined to indicate that the resource
will be sent with the usual inline disposition.  If you want to send
something that should be downloaded as a binary file rather than
displayed in the browser, provide a C<filename> parameter that will be
the default filename.  It must be a string of one or more ASCII
alphanumerics and underscores, dots, and hyphens.

First, the core status headers are written to the client, using the
given MIME type for the content type, sending the current HTTP status
(200 OK by default, or else whatever it was last changed to with
C<setStatus>), and specifying C<no-store> behavior for caching.  If the
C<filename> parameter was specified, a content disposition header is
written with attachment disposition and the given recommended filename.

Next, there may be a C<Set-Cookie> header sent to the HTTP client,
depending on the current cookie state.  See C<cookieDefault> for the
default behavior, and C<cookieLogin> and C<cookieCancel> for the other
behaviors.

The CGI response head is then finished and the resource is sent.
Finally, the script exits without returning to caller.

=cut

sub sendRaw {
  
  # Check parameter count
  ($#_ == 3) or die "Wrong number of parameters, stopped";
  
  # Get self and parameters
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $octets = shift;
  (not ref($octets)) or die "Wrong parameter type, stopped";
  ($octets =~ /\A[\x{0}-\x{ff}]*\z/) or
    die "Wrong parameter type, stopped";
  
  my $mime = shift;
  (not ref($mime)) or die "Wrong parameter type, stopped";
  ($mime =~ /\A[\x{20}-\x{7e}]*\z/) or
    die "Invalid MIME type, stopped";
  
  my $fname = shift;
  if (defined($fname)) {
    (not ref($fname)) or die "Wrong parameter type, stopped";
    ($fname =~ /\A[A-Za-z0-9_\.\-]+\z/) or
      die "Invalid filename format, stopped";
  }
  
  # Determine the cookie name
  my $cookie_name = '__Host-' . $self->{'_cvar'}->{'authsuffix'};
  
  # Based on the cookie setting and the verify flag, determine the
  # cookie header line to send, or an empty string if no cookie header
  # should be sent
  my $ckh = '';
  if (($self->{'_cookie'} > 0) or
        ($self->{'_verify'} and ($self->{'_cookie'} == 0))) {
    # Cookie mode is in login OR we are in default mode and the client
    # already has a cookie, so we need to send them a fresh verification
    # cookie in both cases
    my $auth_time = sprintf("%x", int(time / 60));
    my $auth_hmac = hmac_md5_hex(
                      $auth_time, $self->{'_cvar'}->{'authsecret'});
    my $payload = "$auth_time|$auth_hmac";
    
    $ckh = "Set-Cookie: $cookie_name=$payload; Secure; Path=/\r\n";
    
  } elsif ($self->{'_cookie'} < 0) {
    # Cookie mode is in cancel, so we need to send them an invalid,
    # expired cookie
    $ckh = "Set-Cookie: $cookie_name=0; Max-Age=0; Secure; Path=/\r\n";
  }
  
  # Determine status code and description
  my $status = "$self->{'_status'}->[0] $self->{'_status'}->[1]";
  
  # Set binary output
  binmode(STDOUT, ":raw") or die "Failed to set binary output, stopped";
  
  # Print the full CGI response
  print "Content-Type: $mime\r\n";
  print "Status: $status\r\n";
  if (defined($fname)) {
    print "Content-Disposition: attachment; filename=\"$fname\"\r\n";
  }
  print "Cache-Control: no-store\r\n";
  print "$ckh\r\n";
  print "$octets";
  
  # Exit script
  exit;
}

=back

=head1 AUTHOR

Noah Johnson, C<noah.johnson@loupmail.com>

=head1 COPYRIGHT AND LICENSE

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

=cut

# End with something that evaluates to true
#
1;
