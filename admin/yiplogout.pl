#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use MIME::Base64;

# Non-core dependencies
use Crypt::Random qw(makerandom_octet);
use HTML::Template;

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
# This template uses the following template variables:
#
#   pageself : path to this script itself
#
# The form action POSTs back to this script.
#
my $get_template = q{<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Logout</title>
  </head>
  <body>
    <h1>Logout</h1>
    <form
        action="<TMPL_VAR NAME=pageself>"
        method="post"
        enctype="application/x-www-form-urlencoded">
      <input type="hidden" name="logout" value="1">
      <p><input type="submit" value="Log out"></p>
    </form>
  </body>
</html>
};

# POST success page (NOT a template!).
#
my $done_page = q{<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Logout</title>
  </head>
  <body>
    <h1>Logout</h1>
    <p>You are now logged out.</p>
  </body>
</html>
};

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
  
  # Check that client is authorized
  $yad->checkCookie;
  
  # Fill in template state
  my %tvar;
  $tvar{'pageself'} = $yad->getVar('pathlogout');
  
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
  # utilities; start a read-write work block (with no lastmod update)
  # before admin is loaded so that everything will be in a single
  # transaction
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $dbh = $dbc->beginWork('w');
  my $yad = Yip::Admin->load($dbc);
  
  # Check that client is authorized
  $yad->checkCookie;
  
  # Read all the POSTed form variables
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
  
  # Write main response headers
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Cache-Control: no-store\r\n";
  
  # Cancel client's cookie
  $yad->cancelCookie;
  
  # Finish headers and print logout page
  print "\r\n$done_page";
  
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
