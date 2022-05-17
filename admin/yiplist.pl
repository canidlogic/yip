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

=head1 NAME

yiplist.pl - Report list administration CGI script for Yip.

=head1 SYNOPSIS

  /cgi-bin/yiplist.pl?report=types
  /cgi-bin/yiplist.pl?report=vars
  /cgi-bin/yiplist.pl?report=templates
  /cgi-bin/yiplist.pl?report=archives
  /cgi-bin/yiplist.pl?report=globals
  /cgi-bin/yiplist.pl?report=posts

=head1 DESCRIPTION

This is a CGI script for administration of Yip.  This particular CGI
script handles listing entities currently within the database and
provides links for editing entities.  The client must have an
authorization cookie to use this script.

The GET request takes a query-string variable C<report> that indicates
which kind of entity should be displayed (C<types> C<vars> C<templates>
C<archives> C<globals> or C<posts>).

GET is the only method supported by this script.

=cut

# =========
# Templates
# =========

# Archive list template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   records - an array where each record has "uid" "aname" "adate"
#   corresponding to those fields of the archive, and "pdrop" which is
#   equal to _pathdrop
#
my $archive_template = Yip::Admin->format_html('Archives', q{
    <h1>Archives</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathedit>?class=archives" class="btn">
        Edit archives
      </a>
    </div>
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathgenuid>?table=archive" class="btn">
        Generate archive UID
      </a>
    </div>

    <table class="rtable">
      <tr>
        <th>UID</th>
        <th>Name</th>
        <th>Until</th>
        <th>*</th>
      </tr>
<TMPL_LOOP NAME=records>
      <tr>
        <td class="rcc"><TMPL_VAR NAME=uid></td>
        <td class="rcl"><TMPL_VAR NAME=aname ESCAPE=html></td>
        <td class="rcc"><TMPL_VAR NAME=adate></td>
        <td class="rcc">
          <a href="<TMPL_VAR NAME=pdrop>?archive=<TMPL_VAR NAME=uid>">
            Drop
          </a>
        </td>
      </tr>
</TMPL_LOOP>
    </table>
});

# Global resource list template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   records - an array where each record has "uid" and "tname" fields
#   where tname is the data type name, and "pdrop" which is equal to
#   _pathdrop and "pdown" which is equal to _pathdownload
#
my $global_template = Yip::Admin->format_html('Global resources', q{
    <h1>Global resources</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathupload>" class="btn">
        Upload resource
      </a>
    </div>
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathgenuid>?table=global" class="btn">
        Generate resource UID
      </a>
    </div>

    <table class="rtable">
      <tr>
        <th>UID</th>
        <th>Type</th>
        <th colspan="3">*</th>
      </tr>
<TMPL_LOOP NAME=records>
      <tr>
        <td class="rcc"><TMPL_VAR NAME=uid></td>
        <td class="rcl"><TMPL_VAR NAME=tname></td>
        <td class="rcc">
          <a
      href="<TMPL_VAR NAME=pdown>?global=<TMPL_VAR NAME=uid>&preview=1">
            View
          </a>
        </td>
        <td class="rcc">
          <a href="<TMPL_VAR NAME=pdown>?global=<TMPL_VAR NAME=uid>">
            Download
          </a>
        </td>
        <td class="rcc">
          <a href="<TMPL_VAR NAME=pdrop>?global=<TMPL_VAR NAME=uid>">
            Drop
          </a>
        </td>
      </tr>
</TMPL_LOOP>
    </table>
});

# Post list template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   records - an array where each record has "uid" and "tstamp" fields
#   corresponding to the post fields, and "pdrop" which is equal to
#   _pathdrop and "pex" which is equal to _pathexport
#
my $post_template = Yip::Admin->format_html('Posts', q{
    <h1>Posts</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathimport>" class="btn">
        Import post
      </a>
    </div>
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathgenuid>?table=post" class="btn">
        Generate post UID
      </a>
    </div>

    <table class="rtable">
      <tr>
        <th>UID</th>
        <th>Date</th>
        <th colspan="3">*</th>
      </tr>
<TMPL_LOOP NAME=records>
      <tr>
        <td class="rcc"><TMPL_VAR NAME=uid></td>
        <td class="rcc"><TMPL_VAR NAME=tstamp></td>
        <td class="rcc">
       <a href="<TMPL_VAR NAME=pex>?post=<TMPL_VAR NAME=uid>&preview=1">
            Inspect
          </a>
        </td>
        <td class="rcc">
          <a href="<TMPL_VAR NAME=pex>?post=<TMPL_VAR NAME=uid>">
            Export
          </a>
        </td>
        <td class="rcc">
          <a href="<TMPL_VAR NAME=pdrop>?post=<TMPL_VAR NAME=uid>">
            Drop
          </a>
        </td>
      </tr>
</TMPL_LOOP>
    </table>
});

# Template list template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   records - an array where each record has "tname" and "tcache" fields
#   as well as "pdrop" which is equal to _pathdrop and "pdown" which is
#   equal to _pathdownload and "pedit" which is equal to _pathedit
#
my $template_template = Yip::Admin->format_html('Templates', q{
    <h1>Templates</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    
    <h2>New</h2>
    <form
        action="<TMPL_VAR NAME=_pathedit>"
        method="get">
      <div class="ctlbox">
        <div>Template name:</div>
        <div>
          <input
            type="text"
            name="template"
            class="txbox"
            spellcheck="false">
        </div>
      </div>
      <div class="btnbox">
        <input type="submit" value="Edit" class="btn">
      </div>
    </form>

    <h2>Existing</h2>

    <table class="rtable">
      <tr>
        <th>Name</th>
        <th>Cache</th>
        <th colspan="4">*</th>
      </tr>
<TMPL_LOOP NAME=records>
      <tr>
        <td class="rcl"><TMPL_VAR NAME=tname></td>
        <td class="rcr"><TMPL_VAR NAME=tcache></td>
        <td class="rcc">
          <a
  href="<TMPL_VAR NAME=pdown>?template=<TMPL_VAR NAME=tname>&preview=1">
            View
         </a>
        </td>
        <td class="rcc">
         <a href="<TMPL_VAR NAME=pdown>?template=<TMPL_VAR NAME=tname>">
            Download
         </a>
        </td>
        <td class="rcc">
         <a href="<TMPL_VAR NAME=pedit>?template=<TMPL_VAR NAME=tname>">
            Edit
         </a>
        </td>
        <td class="rcc">
         <a href="<TMPL_VAR NAME=pdrop>?template=<TMPL_VAR NAME=tname>">
            Drop
         </a>
        </td>
      </tr>
</TMPL_LOOP>
    </table>
});

# Data type list template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   records - an array where each record has "tname" "tmime" and
#   "tcache" fields as well as "pdrop" which is equal to _pathdrop
#
my $type_template = Yip::Admin->format_html('Data types', q{
    <h1>Data types</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathedit>?class=types" class="btn">
        Edit types
      </a>
    </div>

    <table class="rtable">
      <tr>
        <th>Name</th>
        <th>MIME</th>
        <th>Cache</th>
        <th>*</th>
      </tr>
<TMPL_LOOP NAME=records>
      <tr>
        <td class="rcl"><TMPL_VAR NAME=tname></td>
        <td class="rcl"><TMPL_VAR NAME=tmime ESCAPE=HTML></td>
        <td class="rcr"><TMPL_VAR NAME=tcache></td>
        <td class="rcc">
          <a href="<TMPL_VAR NAME=pdrop>?type=<TMPL_VAR NAME=tname>">
            Drop
          </a>
        </td>
      </tr>
</TMPL_LOOP>
    </table>
});

# Variable list template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   records - an array where each record has "key" and "val" fields as
#   well as "pdrop" which is equal to _pathdrop
#
my $var_template = Yip::Admin->format_html('Template variables', q{
    <h1>Template variables</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    
    <div class="linkbar">
      <a href="<TMPL_VAR NAME=_pathedit>?class=vars" class="btn">
        Edit variables
      </a>
    </div>

    <table class="rtable">
      <tr>
        <th>Key</th>
        <th>Value</th>
        <th>*</th>
      </tr>
<TMPL_LOOP NAME=records>
      <tr>
        <td class="rcl"><TMPL_VAR NAME=key></td>
        <td class="rcll"><TMPL_VAR NAME=val ESCAPE=HTML></td>
        <td class="rcc">
          <a href="<TMPL_VAR NAME=pdrop>?var=<TMPL_VAR NAME=vkey>">
            Drop
          </a>
        </td>
      </tr>
</TMPL_LOOP>
    </table>
});

# Error template.
#
# This template uses the standard template variables defined by
# Yip::Admin, as well as the following custom template variables:
#
#   reason - an error message to show the user
#
my $err_template = Yip::Admin->format_html('Report', q{
    <h1>Report</h1>
    <div id="homelink">
      <a href="<TMPL_VAR NAME=_backlink>">&raquo; Back &laquo;</a>
    </div>
    <p class="msg">
      Reporting operation failed: <TMPL_VAR NAME=reason ESCAPE=HTML>!
    </p>
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

# Get normalized method and make sure it's GET
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

# Get query string
#
my $qs = '';
if (defined $ENV{'QUERY_STRING'}) {
  $qs = $ENV{'QUERY_STRING'};
}

# Parse query string
#
my $vars = Yip::Admin->parse_form($qs);

# Make sure required parameter was provided
#
(exists $vars->{'report'}) or
  send_error($yap, 'Query string missing report parameter');

# Handle the different reports
#
my $report = $vars->{'report'};
$report =~ tr/A-Z/a-z/;

if ($report eq 'types') { # ============================================
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Define record array
  my @recs;

  # Get all the records
  my $qr = $dbh->selectall_arrayref(
            'SELECT rtypename, rtypemime, rtypecache '
            . 'FROM rtype ORDER BY rtypename ASC');
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @recs, ({
        tname  => $r->[0],
        tmime  => $r->[1],
        tcache => $r->[2],
        pdrop  => $yap->getVar('pathdrop')
      });
    }
  }
  
  # Finish transaction
  $dbc->finishWork;
  
  # Define custom parameter
  $yap->customParam('records', \@recs);
  
  # Send report template
  $yap->sendTemplate($type_template);
  
} elsif ($report eq 'vars') { # ========================================
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Define record array
  my @recs;
  
  # Get all the records
  my $qr = $dbh->selectall_arrayref(
            'SELECT varskey, varsval '
            . 'FROM vars ORDER BY varskey ASC');
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @recs, ({
        key   => $r->[0],
        val   => decode('UTF-8', $r->[1],
                    Encode::FB_CROAK | Encode::LEAVE_SRC),
        pdrop => $yap->getVar('pathdrop')
      });
    }
  }
  
  # Finish transaction
  $dbc->finishWork;
  
  # Define custom parameter
  $yap->customParam('records', \@recs);
  
  # Send report template
  $yap->sendTemplate($var_template);
  
} elsif ($report eq 'templates') { # ===================================
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Define record array
  my @recs;
  
  # Get all the records
  my $qr = $dbh->selectall_arrayref(
            'SELECT tmplname, tmplcache '
            . 'FROM tmpl ORDER BY tmplname ASC');
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @recs, ({
        tname  => $r->[0],
        tcache => $r->[1],
        pdrop  => $yap->getVar('pathdrop'),
        pdown  => $yap->getVar('pathdownload'),
        pedit  => $yap->getVar('pathedit')
      });
    }
  }
  
  # Finish transaction
  $dbc->finishWork;
  
  # Define custom parameter
  $yap->customParam('records', \@recs);
  
  # Send report template
  $yap->sendTemplate($template_template);
  
} elsif ($report eq 'archives') { # ====================================
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Define record array
  my @recs;
  
  # Get all the records
  my $qr = $dbh->selectall_arrayref(
            'SELECT parcuid, parcname, parcuntil '
            . 'FROM parc ORDER BY parcuntil DESC');
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @recs, ({
        uid   => $r->[0],
        aname => decode('UTF-8', $r->[1],
                    Encode::FB_CROAK | Encode::LEAVE_SRC),
        adate => decode_time($r->[2], $yap->getVar('epoch')),
        pdrop => $yap->getVar('pathdrop')
      });
    }
  }
  
  # Finish transaction
  $dbc->finishWork;
  
  # Define custom parameter
  $yap->customParam('records', \@recs);
  
  # Send report template
  $yap->sendTemplate($archive_template);
  
} elsif ($report eq 'globals') { # =====================================
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Define record array
  my @recs;
  
  # Get all the records
  my $qr = $dbh->selectall_arrayref(
            'SELECT gresuid, rtypename '
            . 'FROM gres '
            . 'INNER JOIN rtype ON rtype.rtypeid=gres.rtypeid '
            . 'ORDER BY gresuid ASC');
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @recs, ({
        uid   => $r->[0],
        tname => $r->[1],
        pdrop => $yap->getVar('pathdrop'),
        pdown => $yap->getVar('pathdownload')
      });
    }
  }
  
  # Finish transaction
  $dbc->finishWork;
  
  # Define custom parameter
  $yap->customParam('records', \@recs);
  
  # Send report template
  $yap->sendTemplate($global_template);
  
} elsif ($report eq 'posts') { # =======================================
  # Begin transaction
  my $dbh = $dbc->beginWork('r');
  
  # Define record array
  my @recs;
  
  # Get all the records
  my $qr = $dbh->selectall_arrayref(
            'SELECT postuid, postdate '
            . 'FROM post ORDER BY postdate DESC');
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @recs, ({
        uid    => $r->[0],
        tstamp => decode_time($r->[1], $yap->getVar('epoch')),
        pdrop  => $yap->getVar('pathdrop'),
        pex    => $yap->getVar('pathexport')
      });
    }
  }
  
  # Finish transaction
  $dbc->finishWork;
  
  # Define custom parameter
  $yap->customParam('records', \@recs);
  
  # Send report template
  $yap->sendTemplate($post_template);
  
} else { # =============================================================
  send_error($yap, "Unrecognized report type '$report'");
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
