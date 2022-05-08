#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);
use MIME::Base64;

# Non-core dependencies
use Crypt::Bcrypt qw(bcrypt bcrypt_check);
use Crypt::Random qw(makerandom_octet);

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yipreset.pl - Password reset administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipreset.pl

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles resetting or changing the administrator password.  After
a new Yip CMS database is created with C<createdb.pl> and initialized
with C<resetdb.pl>, this script is the next step, to set an
administrator password.  This script can also be used after a password
reset with C<resetdb.pl> to set the new password after reset.  Finally,
this script can be used to change an existing password.

This is one of the few administrator CGI scripts that can function
without an authorization cookie.  If a valid authorization cookie is
present, then the GET form and the error page will provide a links back
to the administrator control panel.  Otherwise, the links will not be
provided.  That is the only difference between authorized and
unauthorized operation.

The operation of the script also varies depending on whether there is a
current administrator password in the Yip CMS database, or whether the
password is currently in a reset state.  If the password is in a reset
state, this script only asks for a new password to set and will set it
on a first-come first-serve basis.  If the password is not in a reset
state, then the current password must be provided in order to reset it.

Accessing this script with a GET request will display a form that asks
for the new password, another copy of the new password (to verify
against typos), and the current password (unless in a password reset
state).

This script is also the POST request target of the form it provides in
the GET request.  If the operation succeeds, a logout operation is
performed in addition to changing the password, and the success page
provides a link to the login page.  If the operation fails, an error
message is shown and the logout action is not performed.

=cut

# =========
# Templates
# =========

# GET form template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom variables:
#
#   hasauth : 1 if client authorized and we should show link to control
#   panel, 0 if client not authorized
#
#   haspass : 1 if there is a current administrator password, 0 if we
#   are in password reset state
#
# The form action POSTs back to this script.  It has the following 
# fields:
#
#   oldpass : [not present if password reset state] the old password
#
#   newpass : the new password
#
#   checkpass : should be an exact copy of the new password
#
my $get_template = Yip::Admin->format_html('Password reset', q{
    <h1>Password reset</h1>
<TMPL_IF NAME=hasauth>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Back &laquo;</a></p>
    </div>
</TMPL_IF>
    <form
        action="<TMPL_VAR NAME=_pathreset>"
        method="post"
        enctype="application/x-www-form-urlencoded">
<TMPL_IF NAME=haspass>
      <div class="ctlbox">
        <div>Current password:</div>
        <div><input type="password" name="oldpass" class="pwbox"></div>
      </div>
      <div>&nbsp;</div>
</TMPL_IF>
      <div class="ctlbox">
        <div>New password:</div>
        <div><input type="password" name="newpass" class="pwbox"></div>
      </div>
      <div class="ctlbox">
        <div>Retype password:</div>
        <div>
          <input type="password" name="checkpass" class="pwbox">
        </div>
      </div>
      <div>&nbsp;</div>
      <div class="btnbox">
        <input type="submit" value="Submit" class="btn">
      </div>
    </form>
});

# POST error result template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom variables:
#
#   hasauth : 1 if client authorized and we should show link to control
#   panel, 0 if client not authorized
#
#   errmsg : the error message to report
#
my $err_template = Yip::Admin->format_html('Password reset', q{
    <h1>Password reset</h1>
<TMPL_IF NAME=hasauth>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a></p>
    </div>
</TMPL_IF>
    <p>
      Password reset failed.
      <TMPL_VAR NAME=errmsg ESCAPE=HTML>!
    </p>
    <p><a href="<TMPL_VAR NAME=_pathreset>">Try again</a></p>
  </body>
</html>
});

# POST success result template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $done_template = Yip::Admin->format_html('Password reset', q{
    <h1>Password reset</h1>
    <p>Password has been reset.</p>
    <p><a href="<TMPL_VAR NAME=_pathlogin>">Log in</a></p>
});

# ===============
# Local functions
# ===============

# send_error(yap, errmsg)
#
# Send the custom error template back to the client, indicating that the
# password reset failed.  The provided error message will be included in
# the error page.
#
# Provide a Yip::Admin utility object.  This function does not return.
#
sub send_error {
  # Check parameter count
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  # Get parameters and check
  my $yap = shift;
  (ref($yap) and $yap->isa('Yip::Admin')) or
    die "Wrong parameter type, stopped";
  
  my $emsg = shift;
  (not ref($emsg)) or die "Wrong parameter type, stopped";
  $emsg = "$emsg";
  
  # Fill in custom parameters
  if ($yap->hasCookie) {
    $yap->customParam('hasauth', 1);
  } else {
    $yap->customParam('hasauth', 0);
  }
  
  $yap->customParam('errmsg', $emsg);
  
  # Set status and send error
  $yap->setStatus(403, 'Forbidden');
  $yap->sendTemplate($err_template);
}

# send_done(yap)
#
# Send the success template back to the client, indicating that the
# password reset succeded.  This will also clear the client's
# authorization cookie.
#
# Provide a Yip::Admin utility object.  This function does not return.
#
sub send_done {
  # Check parameter count
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  # Get parameter and check
  my $yap = shift;
  (ref($yap) and $yap->isa('Yip::Admin')) or
    die "Wrong parameter type, stopped";
  
  # Cancel the user's cookie and send done page
  $yap->cookieCancel;
  $yap->sendTemplate($done_template);
}

# ==============
# CGI entrypoint
# ==============

# Get normalized method
#
my $request_method = Yip::Admin->http_method;

# Handle the different methods
#
if ($request_method eq 'GET') { # ======================================
  # GET method so start by connecting to database and loading admin
  # utilities
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $yap = Yip::Admin->load($dbc);
  
  # Fill in custom parameters
  if ($yap->hasCookie) {
    $yap->customParam('hasauth', 1);
  } else {
    $yap->customParam('hasauth', 0);
  }
  
  if ($yap->getVar('authpswd') eq '?') {
    $yap->customParam('haspass', 0);
  } else {
    $yap->customParam('haspass', 1);
  }
  
  # Send the GET form template
  $yap->sendTemplate($get_template);
  
} elsif ($request_method eq 'POST') { # ================================
  # POST method so start by connecting to database and loading admin
  # utilities; start a read-write work block (with no lastmod update)
  # before admin is loaded so that everything will be in a single
  # transaction
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $dbh = $dbc->beginWork('w');
  my $yap = Yip::Admin->load($dbc);
  
  # Read all the POSTed form variables
  Yip::Admin->check_form;
  my $vars = Yip::Admin->parse_form(Yip::Admin->read_client);
  
  # We should always have "newpass" and "checkpass" variables
  ((exists $vars->{'newpass'}) and (exists $vars->{'checkpass'})) or
    Yip::Admin->bad_request;
  
  # If the password is not in reset state, then "oldpass" must have been
  # provided and it must match the password hash
  if ($yap->getVar('authpswd') ne '?') {
    # Make sure we were given the old password
    (exists $vars->{'oldpass'}) or
      send_error($yap, 'Old password does not match');
    
    # Make sure it matches after encoding into UTF-8 byte string and
    # checking that it isn't longer than 72 bytes (a bcrypt limit)
    my $old_pass = encode(
                    'UTF-8', $vars->{'oldpass'}, Encode::FB_CROAK);
    (length($old_pass) <= 72) or
      send_error($yap, 'Old password does not match');
    (bcrypt_check($old_pass, $yap->getVar('authpswd'))) or
      send_error($yap, 'Old password does not match');
  }
  
  # If we got here, then we are authorized for the operation, either
  # because the old password was provided and matches, or because the
  # Yip CMS database is in password reset state; next is to check that
  # newpass and checkpass are equal
  ($vars->{'newpass'} eq $vars->{'checkpass'}) or
    send_error($yap, 'New password was not the same the second time');
  
  # Encode the password as a binary string in UTF-8 and make sure the
  # result is at most 72 bytes (a bcrypt limit)
  my $new_pass = encode('UTF-8', $vars->{'newpass'}, Encode::FB_CROAK);
  (length($new_pass) <= 72) or
    send_error($yap,
              'Password may be at most 72 bytes when UTF-8 encoded');
  
  # Get 16 random bytes for use in the salt
  my $salt = makerandom_octet(Length => 16, Strength => 0);
  
  # Get a password hash for the new password
  my $phash = bcrypt($new_pass, '2b', $yap->getVar('authcost'), $salt);
  
  # Update the password hash
  $dbh->do('UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
            undef,
            $phash, 'authpswd');
  
  # Generate a new secret key so we can perform a logout action
  my $skey = encode_base64(
                makerandom_octet(Length => 12, Strength => 0), '');
  
  # Update the secret key
  $dbh->do('UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
            undef,
            $skey, 'authsecret');
  
  # Finish the transaction
  $dbc->finishWork;
  
  # Send the success response to the user and cancel their cookie
  send_done($yap);
  
} else { # =============================================================
  die "Unexpected";
}

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
