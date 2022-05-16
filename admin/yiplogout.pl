#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use MIME::Base64;

# Non-core dependencies
use Crypt::Random qw(makerandom_octet);

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;

=head1 NAME

yiplogout.pl - Logout administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yiplogout.pl

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles logging out the user.  The client must have an
authorization cookie to use this script.

Accessing this script with a GET request will display a form that has
a hidden dummy field and a submit button.

This script is also the POST request target of the form it provides in
the GET request.  If POST is invoked (and the user has a currently valid
cookie), then the secret verification key will be changed to a different
random value (which has the effect of logging everyone out) and the
client's key will be canceled.

=cut

# =========
# Templates
# =========

# GET form template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
# The form action POSTs back to this script.
#
my $get_template = Yip::Admin->format_html('Logout', q{
    <h1>Logout</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">
        &raquo; Back &laquo;
      </a>
    </div>
    <form
        action="<TMPL_VAR NAME=_pathlogout>"
        method="post"
        enctype="application/x-www-form-urlencoded">
      <input type="hidden" name="logout" value="1">
      <div class="linkbar" style="text-align: center;">
        <input type="submit" value="Log out" class="btn">
      </div>
    </form>
});

# POST success page (NOT a template!).
#
my $done_page = Yip::Admin->format_html('Logout', q{
    <h1>Logout</h1>
    <p class="msg">You are now logged out.</p>
});

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
  
  # Check that client is authorized
  $yap->checkCookie;
  
  # Send the template form
  $yap->sendTemplate($get_template);
  
} elsif ($request_method eq 'POST') { # ================================
  # POST method so start by connecting to database and loading admin
  # utilities; start a read-write work block (with no lastmod update)
  # before admin is loaded so that everything will be in a single
  # transaction
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $dbh = $dbc->beginWork('w');
  my $yap = Yip::Admin->load($dbc);
  
  # Check that client is authorized
  $yap->checkCookie;
  
  # Read all the POSTed form variables
  Yip::Admin->check_form;
  my $vars = Yip::Admin->parse_form(Yip::Admin->read_client);
  
  # Generate a new secret key so we can perform a logout action
  my $skey = encode_base64(
                makerandom_octet(Length => 12, Strength => 0), '');
  
  # Update the secret key
  $dbh->do('UPDATE cvars SET cvarsval=? WHERE cvarskey=?',
            undef,
            $skey, 'authsecret');
  
  # Finish the transaction
  $dbc->finishWork;
  
  # Send the logged out page to client and cancel their cookie
  $yap->cookieCancel;
  $yap->sendHTML($done_page);
  
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
