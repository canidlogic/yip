package Yip::Admin;
use strict;

# Core dependencies
use Encode qw(decode);

# Non-core dependencies
use Digest::HMAC_MD5 qw(hmac_md5_hex);

=head1 NAME

Yip::Admin - Common utilities for administration CGI scripts.

=head1 SYNOPSIS

  use Yip::DB;
  use Yip::Admin;
  use YipConfig;
  
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $yad = Yip::Admin->load($dbc);
  
  # Check that invoked as CGI script and get method
  my $method = Yip::Admin->http_method;
  
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
  
  # Generate HTML or HTML template in standard format
  my $html = Yip::Admin->format_html($title, $body_code);
  
  # Send a standard error response for an invalid request method
  Yip::Admin->invalid_method;
  
  # Send a standard error response for a bad request
  Yip::Admin->bad_request;
  
  # Read data sent from HTTP client as raw bytes
  my $octets = Yip::Admin->read_client;

=head1 DESCRIPTION

Module that contains common support functions for administration CGI
scripts.  Some functions are available as class methods, others need a
utility object to be constructed, as described below.

First, you connect to the Yip CMS database using C<Yip::DB>.  Then, you
pass that database connection object to the C<Yip::Admin> constructor to
load the administrator utility object.  This constructor will make sure
that the connection is HTTPS by checking for a CGI environment variable
named C<HTTPS>, load a copy of all configuration variables into memory,
and check whether the CGI environment variable C<HTTP_COOKIE> contains a
currently valid verification cookie.  It is a fatal error if the
protocol is not HTTPS or if loading configuration variables fails, but
it is okay if there is no valid verification cookie.

Once the administrator utility object is loaded, you should check
whether there is a valid verification cookie.  For the common case of
administrator scripts that only work when verified, you can just use the
C<checkCookie> instance method which sends an HTTP error back to the
client and exits if there is no verification cookie.  For certain
special scripts that can function even without verification, you can use
the C<hasCookie> instance method to check whether the client is verified
or not.

At any point after construction, you can get the cached values of the
configuration variables with the C<getVar> function.

Finally, when you are printing out a CGI response, you can use the
C<sendCookie> instance function to print out a C<Set-Cookie> header line
that sets the verification cookie.  Most administrator scripts should do
this at the end of a successful invocation while writing the CGI headers
so that the time in the client's verification cookie is updated.  Don't
send a cookie if the client was never verified in the first place,
though!

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

=head1 CONSTRUCTOR

=over 4

=item B<load(dbc)>

Construct a new administrator utilities object.  C<dbc> is the
C<Yip::DB> object that should be used to load the configuration
variables.  All the configuration variables will be loaded in a single
read-only work block.  If you want all database activity to be in a
single transaction, including this configuration load, you should begin
a work block on the C<Yip::DB> object before calling this constructor.

This constructor will also verify that the CGI environment variable
C<HTTPS> is defined, indicating that the connection is secured over
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
  
  # Set raw input and output
  binmode(STDIN, ":raw") or die "Failed to set binary input, stopped";
  binmode(STDOUT, ":raw") or die "Failed to set binary output, stopped";
  
  # Make sure we are in HTTPS
  unless (exists $ENV{'HTTPS'}) {
    print "$err_insecure";
    exit;
  }
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_cvar' property will store the configuration variables
  $self->{'_cvar'} = { };
  
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
  
  # Start with verify flag cleared
  $self->{'_verify'} = 0;
  
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
this function returns without doing anything further.  If not, an error
message is set to the HTTP client and this function will exit the script
without returning.

=cut

sub checkCookie {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Print error if client not authorized
  unless ($self->{'_verify'}) {
    print "$err_unauth";
    exit;
  }
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

=item B<sendCookie()>

Print a C<Set-Cookie> HTTP header that contains a fresh, valid
authorization cookie.  The C<Set-Cookie> line is printed directly to
standard output, followed by a CR+LF break.

=cut

sub sendCookie {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Determine the cookie name
  my $cookie_name = '__Host-' . $self->{'_cvar'}->{'authsuffix'};
  
  # Determine the cookie payload
  my $auth_time = sprintf("%x", int(time / 60));
  my $auth_hmac = hmac_md5_hex(
                    $auth_time, $self->{'_cvar'}->{'authsecret'});
  my $payload = "$auth_time|$auth_hmac";
  
  # Send the cookie header
  print "Set-Cookie: $cookie_name=$payload; Secure; Path=/\r\n";
}

=item B<cancelCookie()>

Print a C<Set-Cookie> HTTP header that overwrites any authorization
cookie the client may have with an invalid value and then immediately
expires the cookie.  The C<Set-Cookie> line is printed directly to
standard output, followed by a CR+LF break.

=cut

sub cancelCookie {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Determine the cookie name
  my $cookie_name = '__Host-' . $self->{'_cvar'}->{'authsuffix'};
  
  # Send the cookie header
  print "Set-Cookie: $cookie_name=0; Max-Age=0; Secure; Path=/\r\n";
}

=back

=head1 STATIC CLASS METHODS

=over 4

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
  
  # Drop the self argument
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

=item B<invalid_method()>

Send an HTTP 405 Method Not Allowed back to the client and exit without
returning.

=cut

sub invalid_method {
  ($#_ <= 0) or die "Wrong number of arguments, stopped";
  print "$err_method";
  exit;
}

=item B<bad_request()>

Send an HTTP 400 Bad Request back to the client and exit without
returning.

=cut

sub bad_request {
  ($#_ <= 0) or die "Wrong number of arguments, stopped";
  print "$err_request";
  exit;
}

=item B<read_client()>

Read data sent by an HTTP client.  This checks for CONTENT_LENGTH
environment variable, then reads exactly that from standard input,
returning the raw bytes in a binary string.  If there are any problems,
sends 400 Bad Request back to client and exits without returning.

=cut

sub read_client {
  # Check parameter count
  ($#_ <= 0) or die "Wrong number of arguments, stopped";
  
  # CONTENT_LENGTH must be defined
  (exists $ENV{'CONTENT_LENGTH'}) or bad_request();
  
  # Parse content length
  ($ENV{'CONTENT_LENGTH'} =~ /\A0*[0-9]{1,9}\z/) or bad_request();
  my $clen = int($ENV{'CONTENT_LENGTH'});
  
  # Set raw input
  binmode(STDIN, ":raw") or die "Failed to set binary input, stopped";
  
  # Read the data
  my $data = '';
  (sysread(STDIN, $data, $clen) == $clen) or bad_request();
  
  # Return the data
  return $data;
}

=item B<parse_form($str)>

Given a string in application/x-www-form-urlencoded format, parse it
into a hash reference containing the decoded key/value map with possible
Unicode in the strings.  If there are any problems, sends 400 Bad
Request back to client and exists without returning.

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
  ($str =~ /\A[ \t\r\n\x{20}-\x{7e}]*\z/) or bad_request();
  
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
    ($ds =~ /\A([^=]+)=(.*)\z/) or bad_request();
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
      (not ($v =~ /%/)) or bad_request();
      
      # Now replace 0x100 with percent signs to get the decoded binary
      # string
      $v =~ s/\x{100}/%/g;
      
      # Decode binary string as UTF-8
      eval {
        $v = decode('UTF-8', $v, Encode::FB_CROAK);
      };
      if ($@) {
        bad_request();
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
    (not (exists $result{$dname})) or bad_request();
    
    # Add variable to hash result
    $result{$dname} = $dval;
  }
  
  # Return result reference
  return \%result;
}

=item B<http_method()>

Check that there is a CGI environment variable REQUEST_METHOD and fatal
error if not.  Then, get the REQUEST_METHOD and normalize it to 'GET' or
'POST'.  If it can't be normalized to one of those two, invoke
invalid_method.  Return the normalized method.

=cut

sub http_method {
  # Check parameter count
  ($#_ <= 0) or die "Wrong number of arguments, stopped";
  
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
    invalid_method();
  }
  
  # Return the normalized method
  return $request_method;
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
