#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Non-core dependencies
use Date::Calc qw(check_date Date_to_Days);
use DBI qw(:sql_types);
use Digest::SHA qw(sha1_hex);

# Yip modules
use Yip::DB;
use Yip::Admin;
use YipConfig;
use Yip::Post;

=head1 NAME

yipimport.pl - Post import administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yipimport.pl

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles importing posts along with their attachments.  It can be
used both for creating new posts within the database or for overwriting
existing posts.  The client must have an authorization cookie to use
this script.

The GET request will provide a form allowing a MIME message to be
uploaded containing the post, all necessary metainformation for the
post, and any attachments.  See the C<Yip::Post> module for further
details about the format of this MIME message.  You can use the
C<runyip.pl> utility script for working with this MIME message format.

This script is also the POST request target of the form it provides in
the GET request.  The POST request will read the uploaded MIME message,
parse it, and update the database accordingly.  If a post with a UID
matching what is given within the MIME message already exists, it will
be deleted and then immediately replaced with the new post.  If no post
with a matching UID already exists, a new post will be added.

=cut

# =========
# Templates
# =========

# GET form template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
# The form action POSTs back to this script in MIME format with file
# upload, with the following form variables:
#
#   upload - the uploaded MIME message file
#
my $get_template = Yip::Admin->format_html('Import post', q{
    <h1>Import post</h1>
    <div id="homelink"><a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Back
      &laquo;</a></div>
    <form
        action="<TMPL_VAR NAME=_pathimport>"
        method="post"
        enctype="multipart/form-data">
      <div class="ctlbox">
        <div>Select MIME post to upload:</div>
        <div>
          <input type="file" name="upload">
        </div>
      </div>
      <div>&nbsp;</div>
      <div class="btnbox">
        <input type="submit" value="Upload" class="btn">
      </div>
    </form>
});

# POST success template.
#
# This template uses the standard template variables defined by
# Yip::Admin.
#
my $done_template = Yip::Admin->format_html('Import post', q{
    <h1>Import post</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a>
    </div>
    <p>Import operation successful.</p>
});

# POST error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Import post', q{
    <h1>Import post</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_pathadmin>">&raquo; Home &laquo;</a>
    </div>
    <p>Import operation failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!</p>
});

# ===============
# Local functions
# ===============

# send_error(yap, errmsg)
#
# Send the custom error template back to the client, indicating that the
# operation failed.  The provided error message will be included in the
# error page.  May also be used by the GET page in certain cases.
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

# encode_time(str, epoch)
#
# Encode a string in yyyy-mm-ddThh:mm:ss format into an integer time
# value for the database according to a given epoch.
#
# epoch is the epoch value from the database cvars table.
#
# Returns an integer.  Causes fatal errors if there are any problems.
#
sub encode_time {
  # Check parameter count
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  # Get parameters and check
  my $str = shift;
  my $ep  = shift;
  
  ((not ref($str)) and (not ref($ep))) or
    die "Wrong parameter type, stopped";
  (int($ep) == $ep) or
    die "Wrong parameter type, stopped";
  
  $str = "$str";
  $ep  = int($ep);
  
  # Parse the string
  ($str =~ /\A
            ([0-9]{4})
              \-
            ([0-9]{2})
              \-
            ([0-9]{2})
              T
            ([0-9]{2})
              :
            ([0-9]{2})
              :
            ([0-9]{2})
          \z/x) or
    die "Invalid datetime string";
  
  my $year  = int($1);
  my $month = int($2);
  my $day   = int($3);
  my $hr    = int($4);
  my $mn    = int($5);
  my $sc    = int($6);
  
  # Range-check fields
  (($year >= 1970) and ($year <= 4999)) or
    die "Year out of range";
  (($month >= 1) and ($month <= 12)) or
    die "Month out of range";
  (($day >= 1) and ($day <= 31)) or
    die "Day out of range";
  (($hr >= 0) and ($hr <= 23)) or
    die "Hour out of range";
  (($mn >= 0) and ($mn <= 59)) or
    die "Minute out of range";
  (($sc >= 0) and ($sc <= 59)) or
    die "Second out of range";
  (check_date($year, $month, $day)) or
    die "Date is invalid";
  
  # Get number of days since Unix epoch
  my $dc = Date_to_Days($year, $month, $day) - Date_to_Days(1970, 1, 1);
  
  # Compute the seconds since Unix epoch
  my $tv = ($dc * 86400)
              + ($hr * 3600)
              + ($mn * 60)
              + $sc;
  
  # Adjust by epoch
  $tv = $tv - $ep;
  
  # Return value
  return $tv;
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
  
  # Check that client is authorized
  $yap->checkCookie;
  
  # Send the form template to client
  $yap->sendTemplate($get_template);
  
} elsif ($request_method eq 'POST') { # ================================
  # POST method so start by connecting to database and loading admin
  # utilities
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $yap = Yip::Admin->load($dbc);
  
  # Check that client is authorized
  $yap->checkCookie;
  
  # Read all the POSTed form uploads
  Yip::Admin->check_upload;
  my $vars = Yip::Admin->parse_upload(Yip::Admin->read_client);
  
  # Check that we got the upload and get it
  (exists $vars->{'upload'}) or Yip::Admin->bad_request;
  my $upload = $vars->{'upload'};
  
  # Check that a file was uploaded
  (length($upload) > 0) or
    send_error($yap, 'Must upload a non-empty file');
  
  # Parse the uploaded MIME message
  my $yp = Yip::Post->create;
  eval {
    $yp->loadMIME($upload);
  };
  if ($@) {
    send_error($yap, "MIME message error: $@");
  }
  
  # Encode the post datetime according to the database epoch
  my $encdate = encode_time($yp->date, $yap->getVar('epoch'));
  
  # Start the update transaction
  my $dbh = $dbc->beginWork('rw');
  
  # If post with that unique ID already exists, begin by deleting that
  # old version of the post and all its attachments
  my $oqr = $dbh->selectrow_arrayref(
                    'SELECT postid FROM post WHERE postuid=?',
                    undef,
                    $yp->uid);
  if (ref($oqr) eq 'ARRAY') {
    $oqr = $oqr->[0];
    $dbh->do('DELETE FROM att WHERE postid=?', undef, $oqr);
    $dbh->do('DELETE FROM post WHERE postid=?', undef, $oqr);
  }
  
  # Insert the main post record
  $dbh->do('INSERT INTO post(postuid, postdate, postcode) '
            . 'VALUES (?,?,?)',
            undef,
            $yp->uid,
            $encdate,
            encode('UTF-8', $yp->body, Encode::FB_CROAK));
  
  # Get the postid of the record we just inserted
  my $postid = $dbh->selectrow_arrayref(
                'SELECT postid FROM post WHERE postuid=?',
                undef,
                $yp->uid);
  (ref($postid) eq 'ARRAY') or die "Unexpected";
  $postid = $postid->[0];
  
  # Now get the attachment index list
  my @attl = $yp->attlist;
  
  # Add all attachments and link them to the post
  for my $ati (@attl) {
    # Compute the digest for the data
    my $dig = sha1_hex($yp->attdata($ati));
    $dig =~ tr/A-Z/a-z/;
    
    # Look up the foreign key of the data type
    my $attn = $yp->atttype($ati);
    my $rti = $dbh->selectrow_arrayref(
                  'SELECT rtypeid FROM rtype WHERE rtypename=?',
                  undef,
                  $attn);
    (ref($rti) eq 'ARRAY') or
      send_error($yap, "Unknown attachment type in message: '$attn'");
    $rti = $rti->[0];
    
    # Insert the attachment
    my $sth = $dbh->prepare(
            'INSERT INTO att(postid, attidx, attdig, rtypeid, attraw) '
            . 'VALUES (?,?,?,?,?)');
    $sth->bind_param(1, $postid);
    $sth->bind_param(2, $ati);
    $sth->bind_param(3, $dig);
    $sth->bind_param(4, $rti);
    $sth->bind_param(5, $yp->attdata($ati), SQL_BLOB);
    $sth->execute();
  }
  
  # Finish the update transaction
  $dbc->finishWork;
  
  # Send the done template
  $yap->sendTemplate($done_template);
  
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
