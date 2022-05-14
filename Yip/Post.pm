package Yip::Post;
use strict;

# Core dependencies
use Encode qw(decode encode);

# Non-core dependencies
use Date::Calc qw(check_date Add_Delta_Days Date_to_Days);
use MIME::Entity;
use MIME::Parser;

=head1 NAME

Yip::Post - Pack and unpack Yip posts encapsulated in MIME messages.

=head1 SYNOPSIS

  use Yip::Post;
  
  # New post objects start out empty
  my $yp = Yip::Post->create;
  
  # You can overwrite state by loading from a MIME message
  $yp->loadMIME($octets);
  
  # Get and set the UID of the post
  my $uid = $yp->uid;
  $yp->uid(532909);
  
  # Get and set date as yyyy-mm-ddThh:mm:ss string
  my $datestr = $yp->date;
  $yp->date('2022-05-05T11:54:29');
  
  # Get and set the post body (may contain Unicode codepoints)
  my $body = $yp->body;
  $yp->body($body . 'extra text');
  
  # Get a list of all attachment indices in ascending order
  my @attl = $yp->attlist;
  
  # Get and set the typename of any existing attachment
  my $tname = $yp->atttype(1001);
  $yp->atttype(1001, 'jpeg');
  
  # Get and set the binary data of any existing attachment
  my $octets = $yp->attdata(1001);
  $yp->attdata(1001, $octets);
  
  # Drop attachments
  $yp->attdrop(5007);
  $yp->attdrop(9120);
  
  # Create or overwrite attachment
  $yp->attnew(2073, 'png', $octets);
  
  # Encode current state into MIME message
  my $octets = $yp->encodeMIME;

=head1 DESCRIPTION

This class allows you create, edit, pack, and unpack Yip posts that are
encapsulated in MIME messages.  The class never accesses any Yip CMS
database, and it is independent of any particular Yip deployment.
Therefore, Yip MIME messages will work across all Yip deployments.

B<Caution:> This class assumes messages and all their attachments are
small enough to be stored entirely within memory.  Trouble will occur if
you try to use this class to access huge posts that won't easily fit in
memory.

The Yip MIME message includes a unique ID integer for the post, a
timestamp for the post, Unicode text storing the HTML template code for
the post, and zero or more attachments.  Attachments each have an index
that is unique for the attachment within this specific post, a textual
name identifying the kind of data stored within the attachment, and a
binary string storing the raw data of the attachment.

See the documentation for C<createdb.pl> for further information about
the structure of Yip posts and the format of the HTML template code.
Note that the textual data type name for attachments is I<not> a MIME
type, but rather is a key that should match a record in the C<rtype>
table of whichever Yip CMS database this message is intended for.

To use this class, first you construct a new instance.  The new instance
always starts out with empty template code, zero attachments, UID set to
100000, and timestamp set to 1970-01-01T00:00:00.  If you are creating a
new post from scratch, you now use the editing instance methods to get
the object into the proper state.  If you want to read an existing post
message, you can use the C<loadMIME> function to parse and set the
object state equal to what's contained within a given MIME message.

For unpacking existing messages, the various accessor functions allow
you to read all the needed information.  For packing new messages, the
C<encodeMIME> function will encode the current state of the object into
a MIME message.

=head2 MIME message format

This section describes the specific format of MIME messages that are
parsed by the C<loadMIME> function of this class and written by the
C<encodeMIME> function of this class.

C<MIME::Parser> is used internally to parse MIME format and
C<MIME::Entity> is used internally to generate MIME format.

When parsing, e-mail fields such as From, To, and Subject are ignored.
When generating, C<author@example.com> is used as the From field,
C<yip@example.com> is used as the To field, and the Subject is
C<Yip post 915400> with the UID of the post.  (Note that the subject
field is I<not> where the parser determines the UID of the post from!
The manifest is what determines the UID.)

The first entity attached to the MIME message must be a C<text/plain>
file.  Its name is ignored by the parser, but set to C<manifest> by the
generator.  The generator will use 7bit encoding and specify inline
disposition.  It has the following format:

  YIP 915400 2022-05-05T11:54:29
  1001 jpeg
  1002 jpeg
  1003 png
  4257 mp3
  1005 jpeg
  END

The first line is always required.  It has the format signature C<YIP>
followed by the UID of the post, followed by the timestamp of the post.
After the first line is a sequence of zero or more attachment
declarations.  Each attachment declaration is an attachment index and
then the data type name of the attachment.  Attachments must match the
order they appear in the MIME message and each must have a unique index
number, but the index numbers do not need to be in any sort of order.
Finally, the last line just has C<END>.

After the manifest file always comes another file that must be
C<text/plain; charset=utf-8>.  Its name is ignored by the parser, but
set to C<post> by the generator.  It contains the template code for the
post, and the part is encoded by the generator in base64 and set to
attachment disposition.

After the template code part comes the sequence of zero or more
attachments, which must match what is given in the manifest file.  The
type of each must be C<application/octet-stream>.  The attachment names
are ignored by the parser but set to C<att4257> by the generator where
the attachment index is used as the digits.  The generator will encode
in base64 and set to attachment disposition.

=head1 CONSTRUCTOR

=over 4

=item B<create()>

Construct a new, blank post object.  After construction, the template
code will be empty, there will be no attachments, the unique ID will be
set to 100000, and timestamp set to 1970-01-01T00:00:00.

=cut

sub create {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get invocant
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # Define the UID and date fields; the date field is stored as seconds
  # since the Unix epoch (in a floating timezone)
  $self->{'_uid'}  = 100000;
  $self->{'_date'} = 0;
  
  # Set the body equal to an empty string; the body when stored here
  # will be a binary string in UTF-8 encoding
  $self->{'_body'} = '';
  
  # The attachments are stored in a hash which maps decimal index
  # strings to array references; each array has two string elements, the
  # first being the data type name, and the second being a binary string
  # holding the raw data
  $self->{'_att'} = { };
  
  # Return the new object
  return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item B<loadMIME(octets)>

Given a binary string holding a complete Yip MIME post message,
overwrite the contents of this Yip object with the encoded post message.
Fatal errors occur if there are any errors parsing the Yip MIME message.
This object state will only be changed if the load operation is
successful.

=cut

sub loadMIME {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self and parameter
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $octets = shift;
  (not ref($octets)) or die "Wrong parameter type, stopped";
  $octets = "$octets";
  
  # Create a MIME parser and set it to keep everything in-memory
  my $parser = new MIME::Parser;
  $parser->output_to_core(1);
  $parser->tmp_to_core(1);
  
  # Parse the given message into a MIME::Entity
  my $msg = $parser->parse_data($octets);
  (ref($msg) and $msg->isa('MIME::Entity')) or
    die "Failed to parse MIME message, stopped";
  
  # This must be a multipart message to be valid
  ($msg->is_multipart) or die "MIME message must be multipart, stopped";
  
  # Make sure that we have at least two parts (the manifest and the
  # template code)
  my $part_count = scalar($msg->parts);
  ($part_count >= 2) or
    die "MIME message must have at least two parts, stopped";
  
  # Read the manifest
  my $mani = $msg->parts(0)->bodyhandle->as_string;
  
  # Convert CR+LF into LF in manifest
  $mani =~ s/\r\n/\n/g;
  
  # Drop trailing line breaks
  $mani =~ s/[\n]+\z//;
  
  # Split into lines
  my @mali = split /\n/, $mani;
  
  # Check that at least two lines and last line is END
  (($#mali >= 1) and ($mali[$#mali] =~ /\AEND[ \t]*\z/)) or
    die "Invalid manifest part, stopped";
  
  # Parse the first line of the manifest
  ($mali[0] =~ /\A
                  YIP
                    [\x{20}\t]+
                  ([1-9][0-9]{5})
                    [\x{20}\t]+
                  ([1-9][0-9]{3})
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
                    [\x{20}\t]*
                \z/x) or
    die "Failed to parse manifest signature line, stopped";
  
  my $post_uid    = int($1);
  my $post_year   = int($2);
  my $post_month  = int($3);
  my $post_day    = int($4);
  my $post_hour   = int($5);
  my $post_minute = int($6);
  my $post_second = int($7);
  
  # Range-check timestamp fields
  (($post_year >= 1970) and ($post_year <= 4999)) or
    die "Timestamp year out of range, stopped";
  (($post_month >= 1) and ($post_month <= 12)) or
    die "Timestamp month out of range, stopped";
  (($post_day >= 1) and ($post_day <= 31)) or
    die "Timestamp day out of range, stopped";
  (($post_hour >= 0) and ($post_hour <= 23)) or
    die "Timestamp hour out of range, stopped";
  (($post_minute >= 0) and ($post_minute <= 59)) or
    die "Timestamp minute out of range, stopped";
  (($post_second >= 0) and ($post_second <= 59)) or
    die "Timestamp second out of range, stopped";
  
  (check_date($post_year, $post_month, $post_day)) or
    die "Timestamp date not valid, stopped";
  
  # Compute the timestamp value (double-precision can be used by Perl
  # for large integers, so shouldn't be subject to year 2038 problem)
  my $post_ts = Date_to_Days($post_year, $post_month, $post_day)
                  - Date_to_Days(1970, 1, 1);
  $post_ts = ($post_ts * 86400)
              + ($post_hour * 3600)
              + ($post_minute * 60)
              + $post_second;
  
  # Parse all attachment declarations into an array of subarrays, each
  # subarray storing the attachment index and the data type
  my @post_ati;
  for(my $i = 1; $i < $#mali; $i++) {
    # Parse attachment declaration
    ($mali[$i] =~ /\A
                    ([1-9][0-9]{3})
                      [\x{20}\t]+
                    ([A-Za-z0-9_]{1,31})
                      [\x{20}\t]*
                  \z/x)
      or die "Failed to parse attachment in manifest, stopped";
    
    my $a_i = int($1);
    my $a_t = $2;
    
    # Add to array
    push @post_ati, [$a_i, $a_t];
  }
  
  # Make sure number of parts in MIME message is exactly two greater
  # than number of elements in attachment declarations array
  ($part_count == scalar(@post_ati) + 2) or
    die "Manifest declarations don't match attachments, stopped";
  
  # Read the template body into a Unicode string and then encode it into
  # UTF-8
  $msg->parts(1)->bodyhandle->binmode(1);
  my $bh = $msg->parts(1)->bodyhandle->open('r') or
    die "Failed to open template code, stopped";
  
  my $post_code;
  {
    local $/;
    $post_code = $bh->getline or
      die "Failed to read template code, stopped";
  }
  
  $bh->close;
  
  $post_code = decode('UTF-8', $post_code,
                  Encode::FB_CROAK | Encode::LEAVE_SRC);
  $post_code = encode('UTF-8', $post_code,
                  Encode::FB_CROAK | Encode::LEAVE_SRC);
  
  # Now read all attachments into an attachment hash
  my %post_att;
  for(my $i = 0; $i <= $#post_ati; $i++) {
    
    # Read the attachment into a binary string
    $msg->parts($i + 2)->bodyhandle->binmode(1);
    my $ah = $msg->parts($i + 2)->bodyhandle->open('r') or
      die "Failed to open attachment data, stopped";
    
    my $att_data;
    {
      local $/;
      $att_data = $ah->getline or
        die "Failed to read attachment data, stopped";
    }
    
    $ah->close;
    
    # Check that attachment index not already defined
    (not (exists $post_att{"$post_ati[$i]->[0]"})) or
      die "Duplicate attachment index, stopped";
    
    # Add attachment
    $post_att{"$post_ati[$i]->[0]"} = [
      $post_ati[$i]->[1],
      $att_data
    ];
  }
  
  # If we got all the way here successfully, overwrite object state with
  # what we just read
  $self->{'_uid'}  = $post_uid;
  $self->{'_date'} = $post_ts;
  $self->{'_body'} = $post_code;
  $self->{'_att'}  = \%post_att;
}

=item B<uid([uid])>

If invoked without a parameter, returns the UID of the object, which is
an integer in range [100000, 999999].  If invoked with a parameter,
takes a new UID to set, which must be an integer in that same range.

=cut

sub uid {
  
  # Check parameter count
  (($#_ == 0) or ($#_ == 1)) or
    die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";

  # Handle operation
  if ($#_ >= 0) {
    # SET property
    my $param = shift;
    ((not ref($param)) and (int($param) == $param)) or
      die "Wrong parameter type, stopped";
    $param = int($param);
    
    (($param >= 100000) and ($param <= 999999)) or
      die "UID out of range, stopped";
    
    $self->{'_uid'} = $param;
  
  } else {
    # GET property
    return $self->{'_uid'};
  }
}

=item B<date([datestring])>

If invoked without a parameter, returns the timestamp of the object,
which is a string in C<yyyy-mm-ddThh:mm:ss> format.  If invoked with a
parameter, takes a new timestamp to set, which must be a string with
that same format.

=cut

sub date {
  
  # Check parameter count
  (($#_ == 0) or ($#_ == 1)) or
    die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Handle operation
  if ($#_ >= 0) {
    # SET property
    my $param = shift;
    (not ref($param)) or die "Wrong parameter type, stopped";
    $param = "$param";
    
    ($param =~ /\A
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
      die "Invalid timestamp value, stopped";
    
    my $year   = int($1);
    my $month  = int($2);
    my $day    = int($3);
    my $hour   = int($4);
    my $minute = int($5);
    my $second = int($6);
    
    (($year >= 1970) and ($year <= 4999)) or
      die "Year out of range, stopped";
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
    
    my $ts = Date_to_Days($year, $month, $day) 
              - Date_to_Days(1970, 1, 1);
    $ts = ($ts * 86400)
              + ($hour * 3600)
              + ($minute * 60)
              + $second;
    
    $self->{'_date'} = $ts;
  
  } else {
    # GET property
    my $dv = int($self->{'_date'} / 86400);
    my $tv = $self->{'_date'} - ($dv * 86400);
    
    my ($year, $month, $day) = Add_Delta_Days(1970, 1, 1, $dv);
    my $hour = int($tv / 3600);
    $tv = $tv % 3600;
    my $minute = int($tv / 60);
    $tv = $tv % 60;
    my $second = $tv;
    
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
                    $year, $month, $day,
                    $hour, $minute, $second);
  }
}

=item B<body([string])>

If invoked without a parameter, returns the template code within the
body as a Unicode string.  If invoked with a parameter, takes a new
Unicode string to set as the body.  The Unicode string may contain any
Unicode codepoints except for surrogates.

=cut

sub body {
  
  # Check parameter count
  (($#_ == 0) or ($#_ == 1)) or
    die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Handle operation
  if ($#_ >= 0) {
    # SET property
    my $param = shift;
    (not ref($param)) or die "Wrong parameter type, stopped";
    $param = "$param";
    
    ($param =~ /\A[\x{0}-\x{d7ff}\x{e000}-\x{10ffff}]*\z/) or
      die "String contains invalid codepoints, stopped";
    
    $self->{'_body'} = encode('UTF-8', $param,
                        Encode::FB_CROAK | Encode::LEAVE_SRC);
  
  } else {
    # GET property
    return decode('UTF-8', $self->{'_body'},
              Encode::FB_CROAK | Encode::LEAVE_SRC);
  }
}

=item B<attlist()>

Returns a list (in list context) containing all the attachment indices
in ascending order.  May be an empty list if no attachments defined.

=cut

sub attlist {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Since attachment indices are four digits and begin with non-zero
  # digit, we can just use a string sort
  my @result = sort keys %{$self->{'_att'}};
  
  # Replace each element in the result array with its integer equivalent
  @result = map(int, @result);
  
  # Return result
  return @result;
}

=item B<atttype(att_index[, typename])>

If invoked with one parameter, returns the data type of the attachment
that has the given attachment index.  If invoked with two parameters,
sets the data type of the attachment with the given attachment index.
An attachment with the given index must already exist or a fatal error
occurs.  The typename must be a string of one to 31 ASCII alphanumerics
and underscores.

=cut

sub atttype {
  
  # Check parameter count
  (($#_ == 1) or ($#_ == 2)) or
    die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Get attachment index
  my $ai = shift;
  ((not ref($ai)) and (int($ai) == $ai)) or
    die "Wrong parameter type, stopped";
  $ai = int($ai);
  
  # Check that attachment index defined
  (exists $self->{'_att'}->{"$ai"}) or
    die "Can't find attachment index, stopped";
  
  # Handle operation
  if ($#_ >= 0) {
    # SET property
    my $param = shift;
    (not ref($param)) or die "Wrong parameter type, stopped";
    $param = "$param";
    
    ($param =~ /\A[A-Za-z0-9_]{1,31}\z/) or
      die "Invalid data type name, stopped";
    
    $self->{'_att'}->{"$ai"}->[0] = $param;
  
  } else {
    # GET property
    return $self->{'_att'}->{"$ai"}->[0];
  }
}

=item B<attdata(att_index[, octets])>

If invoked with one parameter, returns the raw binary string data of the
attachment that has the given attachment index.  If invoked with two
parameters, sets the raw binary data of the attachment with the given
attachment index.

=cut

sub attdata {
  
  # Check parameter count
  (($#_ == 1) or ($#_ == 2)) or
    die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Get attachment index
  my $ai = shift;
  ((not ref($ai)) and (int($ai) == $ai)) or
    die "Wrong parameter type, stopped";
  $ai = int($ai);
  
  # Check that attachment index defined
  (exists $self->{'_att'}->{"$ai"}) or
    die "Can't find attachment index, stopped";
  
  # Handle operation
  if ($#_ >= 0) {
    # SET property
    my $param = shift;
    (not ref($param)) or die "Wrong parameter type, stopped";
    $param = "$param";
    
    ($param =~ /\A[\x{0}-\x{ff}]*\z/) or
      die "Invalid binary data, stopped";
    
    $self->{'_att'}->{"$ai"}->[1] = $param;
  
  } else {
    # GET property
    return $self->{'_att'}->{"$ai"}->[1];
  }
}

=item B<attdrop(att_index)>

Drop the attachment with the given index, if it exists.  Does nothing if
the given attachment index does not exist.  The index however must be an
integer in range [1000, 9999] or a fatal error occurs.

=cut

sub attdrop {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Get attachment index
  my $ai = shift;
  ((not ref($ai)) and (int($ai) == $ai)) or
    die "Wrong parameter type, stopped";
  $ai = int($ai);
  
  # Check attachment index range
  (($ai >= 1000) and ($ai <= 9999)) or
    die "Attachment index out of range, stopped";
  
  # If attachment exists, delete it
  if (exists($self->{'_att'}->{"$ai"})) {
    delete $self->{'_att'}->{"$ai"};
  }
}

=item B<attnew(att_index, data_type, octets)>

Add or overwrite an attachment.  att_index is the index of the
attachment, which must be an integer in range [1000, 9999].  If this
index is not already used, a new attachment will be added.  If this
index is already in use, the new attachment will replace the old one.
data_type is the name of data type, which must be a string of 1 to 31
ASCII alphanumerics and underscores.  octets is the raw binary data.

=cut

sub attnew {
  
  # Check parameter count
  ($#_ == 3) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Get attachment index
  my $ai = shift;
  ((not ref($ai)) and (int($ai) == $ai)) or
    die "Wrong parameter type, stopped";
  $ai = int($ai);
  
  # Check attachment index range
  (($ai >= 1000) and ($ai <= 9999)) or
    die "Attachment index out of range, stopped";
  
  # Get and check data type
  my $data_type = shift;
  (not ref($data_type)) or die "Wrong parameter type, stopped";
  $data_type = "$data_type";
  
  ($data_type =~ /\A[A-Za-z0-9_]{1,31}\z/) or
    die "Invalid data type name, stopped";
  
  # Get and check raw binary data
  my $raw_data = shift;
  (not ref($raw_data)) or die "Wrong parameter type, stopped";
  $raw_data = "$raw_data";
  
  ($raw_data =~ /\A[\x{0}-\x{ff}]*\z/) or
    die "Invalid binary data, stopped";
  
  # Add/overwrite attachment
  $self->{'_att'}->{"$ai"} = [$data_type, $raw_data];
}

=item B<encodeMIME()>

Encode the current state of the post object into a MIME message.
Returns a binary string containing the whole MIME message.  This binary
string is 7-bit safe.

=cut

sub encodeMIME {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # First we need to build the manifest file, start with the signature
  # line
  my $mani = 'YIP';
  $mani = $mani . " $self->{'_uid'}";
  $mani = $mani . ' ' . $self->date;
  $mani = $mani . "\r\n";
  
  # Now get the sorted list of attachment indices
  my @atl = $self->attlist;
  
  # Add the attachment records to the manifest
  for(my $i = 0; $i <= $#atl; $i++) {
    my $dt = $self->atttype($atl[$i]);
    $mani = $mani . "$atl[$i] $dt\r\n";
  }
  
  # Finish the manifest
  $mani = $mani . "END\r\n";
  
  # Create the MIME entity
  my $msg = MIME::Entity->build(
                    Type     => 'multipart/mixed',
                    Encoding => '7bit',
                    From     => 'author@example.com',
                    To       => 'yip@example.com',
                    Subject  => "Yip post " . $self->{'_uid'},
  );
  
  # Attach the manifest
  $msg->attach(
          Data        => $mani,
          Type        => 'text/plain',
          Encoding    => '7bit',
          Filename    => 'manifest',
          Disposition => 'inline'
  );
  
  # Attach the template code
  $msg->attach(
          Data        => $self->{'_body'},
          Type        => 'text/plain',
          Charset     => 'utf-8',
          Encoding    => 'base64',
          Filename    => 'post',
          Disposition => 'attachment'
  );
  
  # Attach each of the attachments in sorted order of index
  for(my $i = 0; $i <= $#atl; $i++) {
    $msg->attach(
            Data        => $self->attdata($atl[$i]),
            Type        => 'application/octet-stream',
            Encoding    => 'base64',
            Filename    => 'att' . $atl[$i],
            Disposition => 'attachment'
    );
  }
  
  # Return the whole MIME message converted into a string
  return $msg->stringify;
}

=back

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
