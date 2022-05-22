#!/usr/bin/env perl
use strict;
use warnings;

# @@TODO:
use CGI::Carp qw(fatalsToBrowser);

# Non-core modules
use Date::Calc qw(Add_Delta_Days);
use HTML::Template;

# Yip modules
use Yip::DB;
use YipConfig qw($config_dbpath config_preprocessor);

=head1 NAME

yip.pl - Yip microblog rendering script.

=head1 SYNOPSIS

  /cgi-bin/yip.pl
  /cgi-bin/yip.pl?global=917530
  /cgi-bin/yip.pl?local=3905121002
  /cgi-bin/yip.pl?post=309685
  /cgi-bin/yip.pl?archive=820035

=head1 DESCRIPTION

This CGI script handles all of the rendering of the Yip CMS database to
the public.  This script does not alter or handle administration of the
CMS database; use the separate administrator CGI scripts for that.

This script only works with the GET method.  If invoked without any
parameters, the script generates the main catalog page.  Otherwise, the
parameter name indicates the type of entity to render and the parameter
value is a unique ID identifying the entity, as shown in the synopsis.
However, for the C<local> invocation, the parameter value is ten digits,
the first six being the unique ID of a post and the last four being the
attachment ID of that post to render.

=cut

# ===============
# Local functions
# ===============

# send_method_err()
#
# Function invoked if this script is invoked with something other than
# the GET method.
#
# Prints a simple error page and exits the script.  Does not return.
#
sub send_method_err {
  ($#_ < 0) or die "Wrong number of parameters, stopped";
  
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Status: 405 Method Not Allowed\r\n";
  print "Cache-Control: no-cache\r\n";
  print "\r\n";
  print q{<!DOCTYPE html>
<html lang="en">
  <head>
    <title>405 Method Not Allowed</title>
  </head>
  <body>
    <h1>HTTP 405</h1>
    <p>Method Not Allowed</p>
  </body>
</html>
};

  exit;
}

# send_query_err()
#
# Function invoked if this script is invoked with an invalid query
# string.
#
# Prints a simple error page and exits the script.  Does not return.
#
sub send_query_err {
  ($#_ < 0) or die "Wrong number of parameters, stopped";
  
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Status: 400 Bad Request\r\n";
  print "Cache-Control: no-cache\r\n";
  print "\r\n";
  print q{<!DOCTYPE html>
<html lang="en">
  <head>
    <title>400 Bad Request</title>
  </head>
  <body>
    <h1>HTTP 400</h1>
    <p>Bad Request</p>
  </body>
</html>
};

  exit;
}

# send_find_err()
#
# Function invoked if this script can't find the entity that was
# requested.
#
# Prints a simple error page and exits the script.  Does not return.
#
sub send_find_err {
  ($#_ < 0) or die "Wrong number of parameters, stopped";
  
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Status: 404 Not Found\r\n";
  print "Cache-Control: no-cache\r\n";
  print "\r\n";
  print q{<!DOCTYPE html>
<html lang="en">
  <head>
    <title>404 Not Found</title>
  </head>
  <body>
    <h1>HTTP 404</h1>
    <p>Not Found</p>
  </body>
</html>
};

  exit;
}

# tmpl_engine(code)
#
# Generate and return a new instance of HTML::Template with the
# appropriate settings configured.
#
# Pass a reference to a binary string containing the code that this
# template will run.
#
sub tmpl_engine {
  # Check and get parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $tcode = shift;
  
  (ref($tcode) eq 'SCALAR') or die "Wrong parameter type, stopped";
  ($$tcode =~ /\A[\x{1}-\x{ff}]*\z/) or
    die "Wrong parameter type, stopped";
  
  # Construct a template engine
  my $engine = HTML::Template->new(
                  scalarref         => $tcode,
                  die_on_bad_params => 0,
                  no_includes       => 1,
                  global_vars       => 1);
  
  # Return the new engine
  return $engine;
}

# query_cvars(dbc)
#
# Given a database connection, return a list of two elements, the first
# being the epoch value for the database and the second being the
# lastmod string.
#
sub query_cvars {
  
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Yip::DB')) or
    die "Wrong parameter type, stopped";
  
  # Start a read block
  my $dbh = $dbc->beginWork('r');
  
  # Get the desired variables
  my $qr = $dbh->selectall_arrayref(
              'SELECT cvarskey, cvarsval '
              . 'FROM cvars '
              . 'WHERE cvarskey=? OR cvarskey=?',
              undef,
              'epoch', 'lastmod');
  (ref($qr) eq 'ARRAY') or
    die "Failed to query core cvars, stopped";
  
  my $epoch_found   = 0;
  my $lastmod_found = 0;
  
  my $epoch;
  my $lastmod;
  
  for my $qe (@$qr) {
    if ($qe->[0] eq 'epoch') {
      (not $epoch_found) or die "Multiple cvar values, stopped";
      $epoch_found = 1;
      $epoch = $qe->[1];
      
    } elsif ($qe->[0] eq 'lastmod') {
      (not $lastmod_found) or die "Multiple cvar values, stopped";
      $lastmod_found = 1;
      $lastmod = $qe->[1];
    }
  }
  
  ($epoch_found and $lastmod_found) or
    die "Missing core cvars, stopped";
  
  # Finish the read block
  $dbc->finishWork;
  
  # Check epoch and convert to integer
  ($epoch =~ /\A[0-9a-fA-f]+\z/) or die "Invalid cvar value, stopped";
  $epoch = hex($epoch);
  
  # Check lastmod and make sure it's a string
  ($lastmod =~ /\A[0-9a-f]+\z/) or die "Invalid cvar value, stopped";
  $lastmod = "$lastmod";
  
  # Return the core values
  return ($epoch, $lastmod);
}

# query_vars(dbc)
#
# Given a database connection, return a list of three elements, the
# first being a hash of all template variables in the vars table, the
# second being an array reference to twelve strings defining the long
# month names and the third being an array reference to twelve strings
# defining the short month names.
#
# Template variables are those whose key does not begin with an
# underscore and whose key contains 1-31 ASCII alpanumerics in lowercase
# only.
#
# All string values are binary encoded.
#
sub query_vars {
  
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Yip::DB')) or
    die "Wrong parameter type, stopped";
  
  # Start a read block
  my $dbh = $dbc->beginWork('r');
  
  # Get all the variables
  my $qr = $dbh->selectall_arrayref(
              'SELECT varskey, varsval FROM vars');
  (ref($qr) eq 'ARRAY') or
    die "Failed to query vars, stopped";
  
  my $monthl_found   = 0;
  my $months_found = 0;
  
  my $vars = { };
  my $monthl;
  my $months;
  
  for my $qe (@$qr) {
    if ($qe->[0] eq '_longm') {
      (not $monthl_found) or die "Multiple var values, stopped";
      $monthl_found = 1;
      (not ref($qe->[1])) or die "Nonscalar var value, stopped";
      $monthl = $qe->[1];
      
    } elsif ($qe->[0] eq '_shortm') {
      (not $months_found) or die "Multiple var values, stopped";
      $months_found = 1;
      (not ref($qe->[1])) or die "Nonscalar var value, stopped";
      $months = $qe->[1];
    
    } elsif ($qe->[0] =~ /\A[a-z0-9][a-z0-9_]{0,30}\z/) {
      (not defined $vars->{$qe->[0]}) or
        die "Multiple var values, stopped";
      (not ref($qe->[1])) or die "Nonscalar var value, stopped";
      $vars->{$qe->[0]} = $qe->[1];
    }
  }
  
  ($monthl_found and $months_found) or
    die "Missing core vars, stopped";
  
  # Finish the read block
  $dbc->finishWork;
  
  # For both monthl and months, split them into arrays
  my $longm;
  my $shortm;
  for(my $i = 0; $i < 2; $i++) {
    # Get current encoded string
    my $str;
    if ($i == 0) {
      $str = $monthl;
    } elsif ($i == 1) {
      $str = $months;
    } else {
      die "Unexpected";
    }
    
    # Split by vertical bar and make sure we got twelve
    my @ml = split /\|/, $str;
    ($#ml == 11) or die "Invalid month localization, stopped";
    
    # Store a reference to this array in the appropriate variable
    if ($i == 0) {
      $longm = \@ml;
    } elsif ($i == 1) {
      $shortm = \@ml;
    } else {
      die "Unexpected";
    }
  }
  
  # Return the template variables
  return ($vars, $longm, $shortm);
}

# fill_dates(vars, tcode, epoch, monl, mons)
#
# Fill in all the post-related datetime fields in the given vars hash
# reference, using the integer timecode tcode that counts the number of
# seconds from the given epoch.
#
# You must also provide a reference to an array of twelve strings
# storing the long month names (monl) and a reference to an array of
# twelve strings storing the short month names (mons).
#
# The post-related datetime fields are:
#
#   _year _mon _monz _mons _monl _day _dayz _hr24 _hr24z _hr12 _hr12z
#   _apml _apmu _min _minz _sec _secz
#
# See the documentation of the post table in createdb.pl for the details
# of each of these fields.
#
sub fill_dates {
  # Check parameter count
  ($#_ == 4) or die "Wrong number of parameters, stopped";
  
  # Get the parameters
  my $vars  = shift;
  my $tcode = shift;
  my $epoch = shift;
  my $monl  = shift;
  my $mons  = shift;
  
  # Check parameter types
  (ref($vars) eq 'HASH') or die "Wrong parameter type, stopped";
  ((not ref($tcode)) and (not ref($epoch))) or
    die "Wrong parameter type, stopped";
  (ref($monl) eq 'ARRAY') or die "Wrong parameter type, stopped";
  (ref($mons) eq 'ARRAY') or die "Wrong parameter type, stopped";
  
  (int($tcode) == $tcode) or die "Wrong parameter type, stopped";
  (int($epoch) == $epoch) or die "Wrong parameter type, stopped";
  
  $tcode = int($tcode);
  $epoch = int($epoch);
  ($epoch >= 0) or die "Wrong parameter type, stopped";
  
  ((scalar(@$monl) == 12) and (scalar(@$mons) == 12)) or
    die "Wrong parameter type, stopped";
  for my $msv (@$monl) {
    (not ref($msv)) or die "Wrong parameter type, stopped";
    ($msv =~ /\A[\x{1}-\x{ff}]*\z/) or
      die "Wrong parameter type, stopped";
  }
  for my $msv (@$mons) {
    (not ref($msv)) or die "Wrong parameter type, stopped";
    ($msv =~ /\A[\x{1}-\x{ff}]*\z/) or
      die "Wrong parameter type, stopped";
  }
  
  # Compute total number of seconds since Unix epoch and make sure this
  # is zero or greater
  my $tv = $tcode + $epoch;
  ($tv >= 0) or die "Date out of range, stopped";
  
  # Split this timecode into number of days and seconds within the day
  my $dcount = int($tv / 86400);
  $tv = $tv % 86400;
  
  # Figure out the date
  my ($year, $month, $day) = Add_Delta_Days(1970, 1, 1, $dcount);
  
  # Figure out hours minutes seconds
  my $hrs = int($tv / 3600);
  $tv = $tv % 3600;
  
  my $min = int($tv / 60);
  my $sec = $tv % 60;
  
  # Figure out 12-hour hour and AM/PM
  my $apmu;
  my $apml;
  my $hr12;
  
  if ($hrs == 0) {
    $apmu = 'A';
    $apml = 'a';
    $hr12 = 12;
    
  } elsif ($hrs < 12) {
    $apmu = 'A';
    $apml = 'a';
    $hr12 = $hrs;
    
  } elsif ($hrs == 12) {
    $apmu = 'P';
    $apml = 'p';
    $hr12 = $hrs;
    
  } else {
    $apmu = 'P';
    $apml = 'p';
    $hr12 = $hrs - 12;
  }
  
  # Write all the parsed datetime values
  $vars->{'_year' } = "$year";
  $vars->{'_mon'  } = "$month";
  $vars->{'_monz' } = sprintf '%02u', $month;
  $vars->{'_mons' } = $mons->[$month];
  $vars->{'_monl' } = $monl->[$month];
  $vars->{'_day'  } = "$day";
  $vars->{'_dayz' } = sprintf '%02u', $day;
  $vars->{'_hr24' } = "$hrs";
  $vars->{'_hr24z'} = sprintf '%02u', $hrs;
  $vars->{'_hr12' } = "$hr12";
  $vars->{'_hr12z'} = sprintf '%02u', $hr12;
  $vars->{'_apml' } = $apml;
  $vars->{'_apmu' } = $apmu;
  $vars->{'_min'  } = "$min";
  $vars->{'_minz' } = sprintf '%02u', $min;
  $vars->{'_sec'  } = "$sec";
  $vars->{'_secz' } = sprintf '%02u', $sec;
}

# compile_post(full, uid, date, code, tvars, epoch, monl, mons)
#
# Compile the template code of a post into the finished post content
# code.
#
# full should be 1 if the full version of the post is being generated,
# or 0 if the partial version of the post is being generated.
#
# uid is the unique ID of the post, as an integer in [100000, 999999].
#
# date is an integer giving the timestamp of this post in the database
# integer timecode format.
#
# code is a reference to a binary string containing the template code
# for the post.  The code will not be altered by this function.
#
# tvars is a hash reference that should be filled in with all the
# template vars, as is returned from the first element of query_vars().
# This function will not modify tvars, instead making its own private
# copy.  This only needs to contain template variables from the vars
# table; this function will handle the rest of the definitions.
#
# epoch is an integer giving the epoch for timestamps in the database,
# which can be received from query_cvars().
#
# monl is an array reference to twelve binary strings storing the long
# month names.
#
# mons is an array reference to twelve binary strings storing the short
# month names.
#
# The return value of this function is a binary string containing the
# generated body code for the post.
#
sub compile_post {
  # Check parameter count
  ($#_ == 7) or die "Wrong number of parameters, stopped";
  
  # Get parameters and check types
  my $full  = shift;
  my $uid   = shift;
  my $date  = shift;
  my $code  = shift;
  my $tvars = shift;
  my $epoch = shift;
  my $monl  = shift;
  my $mons  = shift;
  
  ((not ref($full)) and
    (not ref($uid)) and
    (not ref($date)) and
    (ref($code) eq 'SCALAR') and
    (ref($tvars) eq 'HASH') and
    (not ref($epoch)) and
    (ref($monl) eq 'ARRAY') and
    (ref($mons) eq 'ARRAY')) or
    die "Wrong parameter types, stopped";
  
  # Begin by making a local copy of the template variables
  my %ctx;
  for my $tkey (keys %$tvars) {
    $ctx{$tkey} = $tvars->{$tkey};
  }
  
  # Define the _full and _partial template variables
  if ($full) {
    $ctx{'_full'   } = 1;
    $ctx{'_partial'} = 0;
    
  } else {
    $ctx{'_full'   } = 0;
    $ctx{'_partial'} = 1;
  }
  
  # Check the UID and add it to the template context as _uid
  ($uid =~ /\A[1-9][0-9]{5}\z/) or die "Invalid UID, stopped";
  $ctx{'_uid'} = "$uid";
  
  # Unpack the date into all the datetime variables
  fill_dates(\%ctx, $date, $epoch, $monl, $mons);
  
  # Construct a template engine on the post code
  my $engine = tmpl_engine($code);
  
  # Establish the template context variables
  $engine->param(\%ctx);
  
  # Compile the post code
  return $engine->output();
}

# page_catalog()
#
# Generate the main catalog page.
#
sub page_catalog {
  # Check parameter count
  ($#_ < 0) or die "Wrong number of parameters, stopped";
  
  # Connect to database and start reading
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $dbh = $dbc->beginWork('r');
  
  # If there are any archives, set the archive_present flag and also set
  # archive_limit to the greatest "until" field across all defined
  # archives
  my $archive_present = 0;
  my $archive_limit;
  
  my $qr = $dbh->selectrow_arrayref(
              'SELECT parcuntil FROM parc ORDER BY parcuntil DESC');
  if (ref($qr) eq 'ARRAY') {
    $archive_present = 1;
    $archive_limit = $qr->[0];
  }
  
  # Get a list of all post UIDs in reverse chronological order; if
  # archives are present, only get UIDs of posts that have dates more
  # recent than the archive limit
  my @pul;
  if ($archive_present) {
    $qr = $dbh->selectall_arrayref(
            'SELECT postuid FROM post WHERE postdate > ? '
            . 'ORDER BY postdate DESC',
            undef,
            $archive_limit);
  } else {
    $qr = $dbh->selectall_arrayref(
            'SELECT postuid FROM post ORDER BY postdate DESC');
  }
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @pul, ($r->[0]);
    }
  }
  
  # Get a template array of all archives in reverse chronological order,
  # including their UIDs as _uid element parameters and their names as
  # _name element parameters
  my @archives;
  if ($archive_present) {
    $qr = $dbh->selectall_arrayref(
          'SELECT parcuid, parcname FROM parc ORDER BY parcuntil DESC');
    (ref($qr) eq 'ARRAY') or die "Unexpected";
    
    for my $r (@$qr) {
      push @archives, ({
        '_uid'  => $r->[0],
        '_name' => $r->[1]
      });
    }
  }
  
  # Get basic variables from database
  my ($epoch, $lastmod    ) = query_cvars($dbc);
  my ($tvars, $monl, $mons) = query_vars($dbc);
  
  # Get a template array of all posts in reverse chronological order,
  # including the _uid in each array element as well as the parsed
  # datetime properties in each element, and also a _code property in
  # each element that has the post content compiled in partial mode
  my @posts;
  for my $uid (@pul) {
  
    # Look up the date and the template code for the current post
    $qr = $dbh->selectrow_arrayref(
                'SELECT postdate, postcode FROM post WHERE postuid=?',
                undef,
                $uid);
    (ref($qr) eq 'ARRAY') or die "Unexpected";
    
    my $date = $qr->[0];
    my $code = $qr->[1];  
    
    # Start a hash for this post element and insert the _uid as well as
    # the parsed datetime properties
    my %pe = (
      '_uid' => $uid
    );
    fill_dates(\%pe, $date, $epoch, $monl, $mons);
    
    # Compile the post body in a partial rendering and store in the
    # _code variable in post element
    $pe{'_code'} = compile_post(
                        0, $uid, $date, \$code,
                        $tvars, $epoch, $monl, $mons);
    
    # Add this element to the posts array
    push @posts, (\%pe);
  }
  
  # Get the cache and template code for the "catalog" template
  $qr = $dbh->selectrow_arrayref(
                'SELECT tmplcache, tmplcode FROM tmpl WHERE tmplname=?',
                undef,
                'catalog');
  (ref($qr) eq 'ARRAY') or die "Catalog template not defined, stopped";
  my $tmpl_cache = $qr->[0];
  my $tmpl_code  = $qr->[1];
  
  # Finish transaction
  $dbc->finishWork;
  
  # Put the _posts and _archives array into the context
  $tvars->{'_posts'   } = \@posts;
  $tvars->{'_archives'} = \@archives;
  
  # We have now set up the standard template context, so our next step
  # is to invoke the preprocessor plug-in (if any) to make any needed
  # alterations to this context
  config_preprocessor('catalog', $tvars);
  
  # Construct a template engine on the post template
  my $engine = tmpl_engine(\$tmpl_code);
  
  # Establish the template context variables
  $engine->param($tvars);
  
  # Compile the full post page
  my $result_code = $engine->output();
  
  # Translate the numeric cache value into a Cache-Control header value
  if ($tmpl_cache == -1) {
    $tmpl_cache = 'no-store';
    
  } elsif ($tmpl_cache == 0) {
    $tmpl_cache = 'no-cache';
    
  } elsif ($tmpl_cache > 0) {
    $tmpl_cache = "max-age=$tmpl_cache";
    
  } else {
    die "Invalid cache value, stopped";
  }
  
  # Now write the full response
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Cache-Control: $tmpl_cache\r\n";
  print "ETag: W/\"$lastmod\"\r\n";
  print "\r\n";
  print "$result_code";
}

# page_global(uid)
#
# Generate a requested global resource for the client.
#
sub page_global {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get parameter
  my $uid = shift;
  (not ref($uid)) or die "Wrong parameter type, stopped";
  (int($uid) == $uid) or die "Wrong parameter type, stopped";
  $uid = int($uid);
  (($uid >= 100000) and ($uid <= 999999)) or
    die "Parameter out of range, stopped";
  
  # Connect to database and start reading
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $dbh = $dbc->beginWork('r');
  
  # Look up global resource
  my $qr = $dbh->selectrow_arrayref(
              'SELECT gresdig, rtypemime, rtypecache, gresraw '
              . 'FROM gres '
              . 'INNER JOIN rtype ON rtype.rtypeid=gres.rtypeid '
              . 'WHERE gresuid=?',
              undef,
              $uid);
  (ref($qr) eq 'ARRAY') or send_find_err();
  
  my $dig   = $qr->[0];
  my $mime  = $qr->[1];
  my $cache = $qr->[2];
  my $raw   = $qr->[3];
  
  # Finish transaction
  $dbc->finishWork;
  
  # Translate the numeric cache value into a Cache-Control header value
  if ($cache == -1) {
    $cache = 'no-store';
    
  } elsif ($cache == 0) {
    $cache = 'no-cache';
    
  } elsif ($cache > 0) {
    $cache = "max-age=$cache";
    
  } else {
    die "Invalid cache value, stopped";
  }
  
  # Now write the full response
  print "Content-Type: $mime\r\n";
  print "Cache-Control: $cache\r\n";
  print "ETag: \"$dig\"\r\n";
  print "\r\n";
  print "$raw";
}

# page_local(uid, ati)
#
# Generate a requested attachment resource for the client.  The uid
# identifies the post and the ati identifies the attachment index for
# that post.
#
sub page_local {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get parameters
  my $uid = shift;
  (not ref($uid)) or die "Wrong parameter type, stopped";
  (int($uid) == $uid) or die "Wrong parameter type, stopped";
  $uid = int($uid);
  (($uid >= 100000) and ($uid <= 999999)) or
    die "Parameter out of range, stopped";
  
  my $ati = shift;
  (not ref($ati)) or die "Wrong parameter type, stopped";
  (int($ati) == $ati) or die "Wrong parameter type, stopped";
  $ati = int($ati);
  (($ati >= 1000) and ($ati <= 9999)) or
    die "Parameter out of range, stopped";
  
  # Connect to database and start reading
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $dbh = $dbc->beginWork('r');
  
  # Look up attachment resource
  my $qr = $dbh->selectrow_arrayref(
              'SELECT attdig, rtypemime, rtypecache, attraw '
              . 'FROM att '
              . 'INNER JOIN rtype ON rtype.rtypeid=att.rtypeid '
              . 'INNER JOIN post ON post.postid=att.postid '
              . 'WHERE postuid=? AND attidx=?',
              undef,
              $uid, $ati);
  (ref($qr) eq 'ARRAY') or send_find_err();
  
  my $dig   = $qr->[0];
  my $mime  = $qr->[1];
  my $cache = $qr->[2];
  my $raw   = $qr->[3];
  
  # Finish transaction
  $dbc->finishWork;
  
  # Translate the numeric cache value into a Cache-Control header value
  if ($cache == -1) {
    $cache = 'no-store';
    
  } elsif ($cache == 0) {
    $cache = 'no-cache';
    
  } elsif ($cache > 0) {
    $cache = "max-age=$cache";
    
  } else {
    die "Invalid cache value, stopped";
  }
  
  # Now write the full response
  print "Content-Type: $mime\r\n";
  print "Cache-Control: $cache\r\n";
  print "ETag: \"$dig\"\r\n";
  print "\r\n";
  print "$raw";
}

# page_post(uid)
#
# Generate a requested post page.  uid is the unique ID of the post
# being requested.
#
sub page_post {
  # Get parameter and check it
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $uid = shift;
  
  (not ref($uid)) or die "Wrong parameter type, stopped";
  (int($uid) == $uid) or die "Wrong parameter type, stopped";
  $uid = int($uid);
  (($uid >= 100000) and ($uid <= 999999)) or
    die "Parameter out of range, stopped";
  
  # Connect to database and start reading
  my $dbc = Yip::DB->connect($config_dbpath, 0);
  my $dbh = $dbc->beginWork('r');
  
  # Look up the date and the template code for this post
  my $qr = $dbh->selectrow_arrayref(
              'SELECT postdate, postcode FROM post WHERE postuid=?',
              undef,
              $uid);
  (ref($qr) eq 'ARRAY') or send_find_err();
  
  my $date = $qr->[0];
  my $code = $qr->[1];
  
  # Figure out the unique ID of the archive this post belongs to, or set
  # to zero if this post isn't in any archive
  my $archive = 0;
  $qr = $dbh->selectrow_arrayref(
                'SELECT parcuid FROM parc '
                . 'WHERE parcuntil >= ? ORDER BY parcuntil ASC',
                undef,
                $date);
  if (ref($qr) eq 'ARRAY') {
    $archive = $qr->[0];
  }
  
  # Get the cache and template code for the "post" template
  $qr = $dbh->selectrow_arrayref(
                'SELECT tmplcache, tmplcode FROM tmpl WHERE tmplname=?',
                undef,
                'post');
  (ref($qr) eq 'ARRAY') or die "Post template not defined, stopped";
  my $tmpl_cache = $qr->[0];
  my $tmpl_code  = $qr->[1];
  
  # Get basic variables from database
  my ($epoch, $lastmod    ) = query_cvars($dbc);
  my ($tvars, $monl, $mons) = query_vars($dbc);
  
  # Finish transaction
  $dbc->finishWork;
  
  # Compile the post body in a full rendering and store in the _code
  # variable in tvars
  $tvars->{'_code'} = compile_post(
                        1, $uid, $date, \$code,
                        $tvars, $epoch, $monl, $mons);
  
  # Set the _archive variable in tvars
  $tvars->{'_archive'} = $archive;
  
  # Set the _uid variable in tvars
  $tvars->{'_uid'} = $uid;
  
  # Unpack all the datetime fields into tvars
  fill_dates($tvars, $date, $epoch, $monl, $mons);
  
  # We have now set up the standard template context, so our next step
  # is to invoke the preprocessor plug-in (if any) to make any needed
  # alterations to this context
  config_preprocessor('post', $tvars);
  
  # Construct a template engine on the post template
  my $engine = tmpl_engine(\$tmpl_code);
  
  # Establish the template context variables
  $engine->param($tvars);
  
  # Compile the full post page
  my $result_code = $engine->output();
  
  # Translate the numeric cache value into a Cache-Control header value
  if ($tmpl_cache == -1) {
    $tmpl_cache = 'no-store';
    
  } elsif ($tmpl_cache == 0) {
    $tmpl_cache = 'no-cache';
    
  } elsif ($tmpl_cache > 0) {
    $tmpl_cache = "max-age=$tmpl_cache";
    
  } else {
    die "Invalid cache value, stopped";
  }
  
  # Now write the full response
  print "Content-Type: text/html; charset=utf-8\r\n";
  print "Cache-Control: $tmpl_cache\r\n";
  print "ETag: W/\"$lastmod\"\r\n";
  print "\r\n";
  print "$result_code";
}

# page_archive(uid)
# @@TODO:
#
sub page_archive {
  # @@TODO:
}

# ==============
# CGI entrypoint
# ==============

# Make sure we were invoked as a CGI script in GET method
#
(defined $ENV{'REQUEST_METHOD'}) or
  die "Script must be invoked as a CGI script, stopped";
  
(($ENV{'REQUEST_METHOD'} =~ /\AGET\z/i)
      or ($ENV{'REQUEST_METHOD'} =~ /\AHEAD\z/i)) or send_method_err();

# Set binary output
#
binmode(STDOUT, ":raw") or die "Failed to set binary output, stopped";

# Get the query string and trim trailing whitespace
#
my $qs = '';
if (defined $ENV{'QUERY_STRING'}) {
  $qs = $ENV{'QUERY_STRING'};
}
$qs =~ s/[ \t\r\n]+\z//;

# Parse the query string and branch to specific handler
#
if (length($qs) < 1) {
  page_catalog();
  
} elsif ($qs =~ /\Aglobal=([1-9][0-9]{5})\z/) {
  page_global(int($1));
  
} elsif ($qs =~ /\Alocal=([1-9][0-9]{5})([1-9][0-9]{3})\z/) {
  page_local(int($1), int($2));
  
} elsif ($qs =~ /\Apost=([1-9][0-9]{5})\z/) {
  page_post(int($1));
  
} elsif ($qs =~ /\Aarchive=([1-9][0-9]{5})\z/) {
  page_archive(int($1));
  
} else {
  send_query_err();
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
