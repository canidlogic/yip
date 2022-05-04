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

=head1 DESCRIPTION

Module that contains common support functions for administration CGI
scripts.

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

# The complete response message sent if client is not in HTTPS
#
my $err_insecure = q{Content-Type: text/plain
Status: 403 Forbidden

HTTP 403: Forbidden
This script must be accessed over HTTPS
};

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
      if ($ck =~ /\A([A-Za-z0-9_]+)=([\x{21}-\x{7e}]+)\z/) {
      
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
          if (hmac_md5($ck_htime, $self->{'_cvar'}->{'authsecret'})
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

# @@TODO:

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
