#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Non-core dependencies
use Date::Calc qw(Add_Delta_Days);

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;
use Yip::Post;

=head1 NAME

yipexport.pl - Post export administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipexport.pl?post=814570

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles exporting posts along with their attachments.  The client
must have an authorization cookie to use this script.

The GET request must be provided with a query string variable C<post>
that contains the unique ID of the post to export.  The response will be
an encoded MIME message that contains the exported post and all its
attachments.  See the C<Yip::Post> module for further details about the
format of this MIME message.  You can use the C<runyip.pl> utility
script for working with this MIME message format.

=cut

# =========
# Templates
# =========

# Malformed request error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Export post', q{
    <h1>Export post</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <p>Export operation failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!</p>
});

# Missing resource error template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $missing_template = Yip::Admin->format_html('Export post', q{
    <h1>Export post</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <p>Not found!</p>
});

# ===============
# Local functions
# ===============

# send_error(yap, errmsg)
#
# Send the custom error template back to the client, indicating that the
# operation failed.  The provided error message will be included in the
# error page.
#
# Do not use for sending the not found error.  Instead, use
# send_missing.
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
  $yap->customParam('reason', $emsg);
  
  # Set status and send error
  $yap->setStatus(400, 'Bad Request');
  $yap->sendTemplate($err_template);
}

# send_missing(yap)
#
# Send an error page back to the client indicating that the request
# resource was not found.
#
# Provide a Yip::Admin utility object.  This function does not return.
#
sub send_missing {
  # Check parameter count
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  # Get parameter and check
  my $yap = shift;
  (ref($yap) and $yap->isa('Yip::Admin')) or
    die "Wrong parameter type, stopped";
  
  # Set status and send error
  $yap->setStatus(404, 'Not Found');
  $yap->sendTemplate($missing_template);
}

# decode_time(time, epoch)
#
# Decode an integer time value from the database into a standard
# datetime string.
#
# time is the time value to decode and epoch is the epoch value from the
# database cvars table.
#
# Returns a string in yyyy-mm-ddThh:mm:ss format.
#
sub decode_time {
  # Check parameter count
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  # Get parameters and check
  my $ti = shift;
  my $ep = shift;
  
  ((not ref($ti)) and (not ref($ep))) or
    die "Wrong parameter type, stopped";
  ((int($ti) == $ti) and (int($ep) == $ep)) or
    die "Wrong parameter type, stopped";
  
  $ti = int($ti);
  $ep = int($ep);
  
  # Get number of seconds since Unix epoch
  $ti = $ti + $ep;
  ($ti >= 0) or die "Time value out of range, stopped";
  
  # Divide into day count and remaining time value
  my $dc = int($ti / 86400);
  $ti = $ti - ($dc * 86400);
  
  # Get date from day count
  my ($year, $month, $day) = Add_Delta_Days(1970, 1, 1, $dc);
  (($year >= 1970) and ($year <= 4999)) or
    die "Time value out of range, stopped";
  
  # Break remaining time value into hours minutes seconds
  my $hr = int($ti / 3600);
  $ti = $ti % 3600;
  my $mn = int($ti / 60);
  my $sc = $ti % 60;
  
  # Return formatted datetime string
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
                  $year, $month, $day,
                  $hr,   $mn,    $sc);
}

# ==============
# CGI entrypoint
# ==============

# Get normalized method and make sure it is GET
#
my $request_method = Yip::Admin->http_method;
($request_method eq 'GET') or Yip::Admin->invalid_method;

# Start by connecting to database and loading admin utilities
#
my $dbc = Yip::DB->connect($config_dbpath, 0);
my $yap = Yip::Admin->load($dbc);

# Check that client is authorized
#
$yap->checkCookie;

# Update backlink
#
$yap->setBacklink($yap->getVar('pathlist') . '?report=posts');

# Get query string
#
my $qs = '';
if (defined $ENV{'QUERY_STRING'}) {
  $qs = $ENV{'QUERY_STRING'};
}

# Parse query string
#
my $vars = Yip::Admin->parse_form($qs);

# Make sure we got the "post" variable
#
(exists $vars->{'post'}) or
  send_error($yap, 'Must provide a post variable in query string');

# Get and check the UID
#
my $uid = $vars->{'post'};
($uid =~ /\A[1-9][0-9]{5}\z/) or
  send_error($yap, 'Invalid unique ID format');
$uid = int($uid);

# Begin transaction
#
my $dbh = $dbc->beginWork('r');

# Look up the main post record
#
my $qr = $dbh->selectrow_arrayref(
              'SELECT postid, postdate, postcode '
              . 'FROM post WHERE postuid=?',
              undef,
              $uid);
(ref($qr) eq 'ARRAY') or send_missing($yap);

my $postid   = $qr->[0];
my $postdate = $qr->[1];
my $postcode = $qr->[2];

# Encode date into datetime string
#
$postdate = decode_time($postdate, $yap->getVar('epoch'));

# Decode postcode from UTF-8
#
$postcode = decode('UTF-8', $postcode,
              Encode::FB_CROAK | Encode::LEAVE_SRC);

# Create a new MIME message that we will fill in
#
my $yp = Yip::Post->create;

# Set the UID, date, and body
#
$yp->uid($uid);
$yp->date($postdate);
$yp->body($postcode);

# Now get all the attachments and add them to message
#
$qr = $dbh->selectall_arrayref(
              'SELECT attidx, rtypename, attraw '
              . 'FROM att '
              . 'INNER JOIN rtype ON att.rtypeid = rtype.rtypeid '
              . 'WHERE postid=? ORDER BY attidx ASC',
              undef,
              $postid);
if (ref($qr) eq 'ARRAY') {
  for my $ao (@$qr) {
    $yp->attnew($ao->[0], $ao->[1], $ao->[2]);
  }
}

# Encode everything into a MIME message
#
my $mime = $yp->encodeMIME;

# End transaction
#
$dbc->finishWork;

# Send the message to client as generic binary data
#
$yap->sendRaw($mime, 'application/octet-stream', "post-$uid");

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
