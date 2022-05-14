#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Non-core dependencies
use Date::Calc qw(check_date);

# Import Yip module
use Yip::Post;

=head1 NAME

runyip.pl - Perform operations on a Yip MIME message.

=head1 SYNOPSIS

  # Print the UID of an existing message
  ./runyip.pl -read -print uid < input.msg
  
  # Print the timestamp of an existing message
  ./runyip.pl -read -print date < input.msg
  
  # Print the list of attachments of an existing message
  ./runyip.pl -read -print attlist < input.msg
  
  # Export the template code of an existing message
  ./runyip.pl -read -export body < input.msg > body.txt
  
  # Export an attachment of an existing message
  ./runyip.pl -read -export 1001 < input.msg > att.jpeg
  
  # Create a new message
  ./runyip.pl -date 2022-05-05T11:54:29 -uid 532909
              -body body.txt -att 9120 jpeg img.jpg
              -write > output.msg
  
  # Edit an existing message by dropping attachment 9120
  ./runyip.pl -read -drop 9120 -write < input.msg > output.msg

=head1 Description

Wrapper script around the C<Yip::Post> module.  This allows you to
perform various manipulations of Yip MIME posts.  If invoked with no
parameters, this script does nothing.  Otherwise, it reads and
interprets parameters in sequential order.  The parameter list is
organized as a sequence of zero or more commands.  Each command starts
with a I<verb> and the verb is followed by zero or more I<objects>.  The
types of objects are specific to particular verbs.

By using the C<-read> verb at the start, you can query information about
an existing Yip MIME message, extract its contents, and edit it.  You
can also start with a blank MIME message, define all its contents using
verbs and then use the C<-write> verb.  See the synopsis for various
usage examples.

The following subsections document the available verbs.

=head2 read verb

The C<-read> verb, if present, must be the first parameter.  It does not
take any objects.  This verb indicates that a Yip MIME message should be
read and parsed from standard input.  If not present, then the state
starts out in the default initialization state defined by C<Yip::Post>.

=head2 print verb

The C<-print> verb, if present, must be the second-to-last parameter.
The last parameter is then the object of this verb, which must be either
C<uid> C<date> or C<attlist>.  This verb will finish the script by
printing to standard output the current value of the specified field.
For the C<attlist>, a listing of attachment indices and their data types
will be printed.

=head2 export verb

The C<-export> verb, if present, must be the second-to-last parameter.
The last parameter is then the object of this verb, which must be either
C<body> or a four-digit attachment index.  The template code or the
specified raw attachment data is printed to standard output.

=head2 date verb

The C<-date> verb can be used anywhere and any number of times.  It
takes a single object, which is a timestamp in C<yyyy-mm-ddThh:mm:ss>
format.  The current post timestamp is changed to the given timestamp.
The year must be in range [1970, 4999].

=head2 uid verb

The C<-uid> verb can be used anywhere and any number of times.  It takes
a single object, which is a unique ID code in range [100000, 999999].
The current post UID is changed to the given unique identifier.

=head2 body verb

The C<-body> verb can be used anywhere and any number of times.  It
takes a single object, which is the path to a UTF-8 text file that
contains the template code that should be set as the template code
within the MIME message.

=head2 att verb

The C<-att> verb can be used anywhere and any number of times.  It takes
three objects:  (1) the attachment index, which must be in [1000, 9999];
(2) the data type, which must be one to 31 ASCII alphanumerics and
underscores; (3) the path to the file containing the binary data of the
attachment.  If the given attachment index does not currently exist, a
new attachment is created.  If the given attachment index already
exists, the attachment is overwritten.

=head2 drop verb

The C<-drop> verb can be used anywhere and any number of times.  It
takes a single object, which is an attachment index in [1000, 9999].  If
an attachment with that index exists, it is dropped.  Otherwise, this
verb has no effect.

=head2 write verb

The C<-write> verb, if present, must be the last parameter.  If present,
it means that whatever the state of the MIME message at the end of
interpretation, the resulting MIME message should be printed to standard
output.

=cut

# Start with an empty command list
#
my @cmd;

# Parse the passed arguments, building the command list
#
for(my $i = 0; $i <= $#ARGV; $i++) {
  # Get verb
  my $verb = $ARGV[$i];
  
  # Handle different verbs
  if ($verb eq '-read') { # ============================================
    # Must be first parameter
    ($i == 0) or die "-read must be first parameter, stopped";
    
    # Add command
    push @cmd, ['read'];
    
  } elsif ($verb eq '-print') { # ======================================
    # Must be second-to-last parameter
    ($i == $#ARGV - 1) or
      die "-print must be second-to-last parameter, stopped";
    
    # Get object parameter and check it
    $i++;
    my $op = $ARGV[$i];
    (($op eq 'uid') or ($op eq 'date') or ($op eq 'attlist')) or
      die "Invalid parameter for -print verb: '$op', stopped";
    
    # Add command
    push @cmd, ['print', $op];
    
  } elsif ($verb eq '-export') { # =====================================
    # Must be second-to-last parameter
    ($i == $#ARGV - 1) or
      die "-export must be second-to-last parameter, stopped";
    
    # Get object parameter and check it
    $i++;
    my $op = $ARGV[$i];
    (($op eq 'body') or ($op =~ /\A[1-9][0-9]{3}\z/)) or
      die "Invalid parameter for -export verb: '$op', stopped";
    
    # Add command
    push @cmd, ['export', $op];
    
  } elsif ($verb eq '-date') { # =======================================
    # Must have object
    ($i < $#ARGV) or
      die "-date must have object parameter, stopped";
    
    # Get object parameter and check it
    $i++;
    my $op = $ARGV[$i];
    $op =~ tr/a-z/A-Z/;
    ($op =~ /\A
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
      die "Invalid parameter for -date verb: '$op', stopped";
    
    my $year   = int($1);
    my $month  = int($2);
    my $day    = int($3);
    my $hour   = int($4);
    my $minute = int($5);
    my $second = int($6);
    
    (($year >= 1970) and ($year <= 4999)) or
      die "Year must be in range [1970, 4999], stopped";
    (($month >= 1) and ($month <= 12)) or
      die "Month out of range, stopped";
    (($day >= 1) and ($day <= 31)) or
      die "Day out of range, stopped";
    (($hour >= 0) and ($hour <= 23)) or
      die "Hour out of range, stopped";
    (($minute >= 0) and ($minute <= 59)) or
      die "Minute out of range, stopped";
    (($second >= 0) and ($second <= 59)) or
      die "Second out of range, stopped";
    
    (check_date($year, $month, $day)) or
      die "Invalid date, stopped";
    
    # Add command
    push @cmd, ['date', $op];
    
  } elsif ($verb eq '-uid') { # ========================================
    # Must have object
    ($i < $#ARGV) or
      die "-uid must have object parameter, stopped";
    
    # Get object parameter and check it
    $i++;
    my $op = $ARGV[$i];
    ($op =~ /\A[1-9][0-9]{5}\z/) or
      die "Invalid parameter for -uid verb: '$op', stopped";
    
    # Add command
    push @cmd, ['uid', $op];
    
  } elsif ($verb eq '-body') { # =======================================
    # Must have object
    ($i < $#ARGV) or
      die "-body must have object parameter, stopped";
    
    # Get object parameter and check it
    $i++;
    my $op = $ARGV[$i];
    (-f $op) or
      die "Can't find file '$op', stopped";
    
    # Add command
    push @cmd, ['body', $op];
    
  } elsif ($verb eq '-att') { # ========================================
    # Must have three objects
    ($i < $#ARGV - 2) or
      die "-att must have three object parameters, stopped";
    
    # Get parameters and check them
    $i++;
    my $opi = $ARGV[$i];
    ($opi =~ /\A[1-9][0-9]{3}\z/) or
      die "Invalid attachment index '$opi', stopped";
    
    $i++;
    my $opt = $ARGV[$i];
    ($opt =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      die "Invalid data type name '$opt', stopped";
    
    $i++;
    my $opp = $ARGV[$i];
    (-f $opp) or
      die "Can't find file '$opp', stopped";
    
    # Add command
    push @cmd, ['att', $opi, $opt, $opp];
    
  } elsif ($verb eq '-drop') { # =======================================
    # Must have object
    ($i < $#ARGV) or
      die "-drop must have object parameter, stopped";
    
    # Get object parameter and check it
    $i++;
    my $op = $ARGV[$i];
    ($op =~ /\A[1-9][0-9]{3}\z/) or
      die "Invalid parameter for -drop verb: '$op', stopped";
    
    # Add command
    push @cmd, ['drop', $op];
    
  } elsif ($verb eq '-write') { # ======================================
    # Must be last parameter
    ($i == $#ARGV) or die "-write must be last parameter, stopped";
    
    # Add command
    push @cmd, ['write'];
    
  } else { # ===========================================================
    die "Unrecognized verb '$verb', stopped";
  }
}

# Create a new Post object
#
my $yp = Yip::Post->create;

# Run all the commands
#
for my $cr (@cmd) {
  
  # Handle specific verb
  my $cv = $cr->[0];
  if ($cv eq 'read') { # ===============================================
    # Read everything from standard input in binary mode
    binmode(STDIN, ":raw") or die "Can't set binary input, stopped";
    my $raw;
    {
      local $/;
      $raw = <STDIN>;
    }
    
    # Load MIME message in object
    $yp->loadMIME($raw);
    
  } elsif ($cv eq 'print') { # =========================================
    # Print requested parameter
    my $rq = $cr->[1];
    if ($rq eq 'uid') {
      $rq = $yp->uid;
      print "$rq\n";
      
    } elsif ($rq eq 'date') {
      $rq = $yp->date;
      print "$rq\n";
      
    } elsif ($rq eq 'attlist') {
      my @attl = $yp->attlist;
      for my $ai (@attl) {
        my $at = $yp->atttype($ai);
        print "$ai $at\n";
      }
      
    } else {
      die "Unexpected";
    }
    
  } elsif ($cv eq 'export') { # ========================================
    # Set binary output
    binmode(STDOUT, ":raw") or die "Can't set binary output, stopped";
    
    # Get raw data
    my $raw;
    my $rq = $cr->[1];
    if ($rq eq 'body') {
      $raw = $yp->body;
      $raw = encode('UTF-8', $raw,
                Encode::FB_CROAK | Encode::LEAVE_SRC);
    } else {
      $raw = $yp->attdata(int($rq));
    }
    
    # Print raw data
    print "$raw";
    
  } elsif ($cv eq 'date') { # ==========================================
    # Set date
    $yp->date($cr->[1]);
    
  } elsif ($cv eq 'uid') { # ===========================================
    # Set UID
    $yp->uid(int($cr->[1]));
    
  } elsif ($cv eq 'body') { # ==========================================
    # Read all data from template code file in UTF-8
    my $raw;
    open(my $fh, "< :encoding(UTF-8)", $cr->[1]) or
      die "Failed to open '$cr->[1]', stopped";
    {
      local $/;
      $raw = readline($fh);
    }
    close($fh);
    
    # Set body data
    $yp->body($raw);
    
  } elsif ($cv eq 'att') { # ===========================================
    # Read all data from resource file
    my $raw;
    open(my $fh, "< :raw", $cr->[3]) or
      die "Failed to open '$cr->[3]', stopped";
    {
      local $/;
      $raw = readline($fh);
    }
    close($fh);
    
    # Define attachment
    $yp->attnew(int($cr->[1]), $cr->[2], $raw);
    
  } elsif ($cv eq 'drop') { # ==========================================
    # Drop attachment if defined
    $yp->attdrop(int($cr->[1]));
    
  } elsif ($cv eq 'write') { # =========================================
    # Set binary output
    binmode(STDOUT, ":raw") or die "Can't set binary output, stopped";
    
    # Serialize MIME message
    my $octets = $yp->encodeMIME;
    
    # Print message
    print "$octets";
    
  } else { # ===========================================================
    die "Unexpected";
  }
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
