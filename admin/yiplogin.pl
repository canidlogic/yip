#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Non-core dependencies
use Crypt::Bcrypt qw(bcrypt_check);
use HTML::Template;

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yiplogin.pl - Login administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yiplogin.pl

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles logging in the user.  You must first set the password
with C<yipreset.pl> before login will work.

This is one of the few administrator CGI scripts that can function
without an authorization cookie.  A new authorization cookie is issued
if the user successfully logs in, otherwise authorization cookies are
left alone.

Accessing this script with a GET request will display a form that asks
for the password.

This script is also the POST request target of the form it provides in
the GET request.  If the login succeeds, the HTTP client is issued a
fresh verification cookie and provided a link to the administrator
control panel.  If the operation fails, an error message is shown and
a link is provided to the login page to retry.

=cut

# =========
# Templates
# =========

# GET form template.
#
# This template uses the following template variables:
#
#   pageself : path to this script itself
#
# The form action POSTs back to this script.  It has the following 
# fields:
#
#   pass : the password
#
my $get_template = Yip::Admin->format_html('Login', q{
    <h1>Login</h1>
    <form
        action="<TMPL_VAR NAME=pageself>"
        method="post"
        enctype="application/x-www-form-urlencoded">
      <div class="ctlbox">
        <div>Password:</div>
        <div><input type="password" name="pass" class="pwbox"></div>
      </div>
      <div>&nbsp;</div>
      <div class="btnbox">
        <input type="submit" value="Submit" class="btn">
      </div>
    </form>
});

# POST error result template.
#
# This template uses the following template variables:
#
#   pageself : path to this script itself
#
my $err_template = Yip::Admin->format_html('Login', q{
    <h1>Login</h1>
    <p>Login failed.  <a href="<TMPL_VAR NAME=pageself>">Try
    again</a></p>
});

# POST success result template.
#
# This template uses the following template variables:
#
#   homelink : path to the control panel
#
my $done_template = Yip::Admin->format_html('Login', q{
    <h1>Login</h1>
    <p>You are now logged in.</p>
    <div id="homelink">
    <a href="<TMPL_VAR NAME=homelink>">&raquo; Control panel &laquo;</a>
    </div>
});

# ===============
# Local functions
# ===============

# send_error(yad)
#
# Send the custom error template back to the client, indicating that the
# login failed.
#
# Provide a Yip::Admin utility object.  This function does not return.
#
sub send_error {
  # Check parameter count
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  # Get parameter and check
  my $yad = shift;
  (ref($yad) and $yad->isa('Yip::Admin')) or
    die "Wrong parameter type, stopped";
  
  # Fill in template state
  my %tvar;  
  $tvar{'pageself'} = $yad->getVar('pathlogin');

  # Open the template
  my $template = HTML::Template->new(
                    scalarref => \$err_template,
                    die_on_bad_params => 0,
                    no_includes => 1);
  
  # Set parameters
  $template->param(\%tvar);
  
  # Compile template
  my $tcode = $template->output;
  
  # Write response headers
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Status: 403 Forbidden\r\n";
  print "Cache-Control: no-store\r\n";
  
  # Finish headers, print generated template, and exit script
  print "\r\n$tcode";
  exit;
}

# send_done(yad)
#
# Send the success template back to the client, indicating that the
# login succeded.  This will also give the client an authorization
# cookie.
#
# Provide a Yip::Admin utility object.  This function does not return.
#
sub send_done {
  # Check parameter count
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  # Get parameter and check
  my $yad = shift;
  (ref($yad) and $yad->isa('Yip::Admin')) or
    die "Wrong parameter type, stopped";
  
  # Fill in template state
  my %tvar;
  
  $tvar{'homelink'} = $yad->getVar('pathadmin');
  
  # Open the template
  my $template = HTML::Template->new(
                    scalarref => \$done_template,
                    die_on_bad_params => 0,
                    no_includes => 1);
  
  # Set parameters
  $template->param(\%tvar);
  
  # Compile template
  my $tcode = $template->output;

  # Write main response headers
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Cache-Control: no-store\r\n";
  
  # Give the user a cookie
  $yad->sendCookie;
  
  # Finish headers, print generated template, and exit
  print "\r\n$tcode";
  exit;
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
  my $yad = Yip::Admin->load($dbc);
  
  # Fill in template state
  my %tvar;
  $tvar{'pageself'} = $yad->getVar('pathlogin');
  
  # Open the template
  my $template = HTML::Template->new(
                    scalarref => \$get_template,
                    die_on_bad_params => 0,
                    no_includes => 1);
  
  # Set parameters
  $template->param(\%tvar);
  
  # Compile template
  my $tcode = $template->output;
  
  # Write response headers
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Cache-Control: no-store\r\n";
  
  # Finish headers and print generated template
  print "\r\n$tcode";
  
} elsif ($request_method eq 'POST') { # ================================
  # POST method so start by connecting to database and loading admin
  # utilities
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $yad = Yip::Admin->load($dbc);
  
  # Read all the POSTed form variables
  my $vars = Yip::Admin->parse_form(Yip::Admin->read_client);
  
  # We should have a "pass" variable
  (exists $vars->{'pass'}) or Yip::Admin->bad_request;
  
  # If password is in reset state, always fail
  ($yad->getVar('authpswd') ne '?') or send_error($yad);
  
  # Make sure password matches after encoding into UTF-8 byte string and
  # checking that it isn't longer than 72 bytes (a bcrypt limit)
  my $pass = encode('UTF-8', $vars->{'pass'}, Encode::FB_CROAK);
  (length($pass) <= 72) or send_error($yad);
  (bcrypt_check($pass, $yad->getVar('authpswd'))) or send_error($yad);
  
  # Send the success response to the user and give them their cookie
  send_done($yad);
  
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
