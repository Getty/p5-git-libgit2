# ABSTRACT: Wraps git_error_last() into a Perl structure

package Git::Libgit2::Error;
use strict;
use warnings;
use FFI::Platypus 2.00;
use Git::Libgit2::FFI ();

# struct git_error { char *message; int klass; }
# We read the two fields by hand using cast() — keeps us free of
# FFI::Platypus::Record's compile-time layout requirements.
my $_decode_ffi;
sub _decode {
  my ($err_ptr) = @_;
  return ( '<no error>', 0 ) unless $err_ptr;
  $_decode_ffi ||= do {
    my $f = FFI::Platypus->new( api => 2 );
    $f->attach_cast( '_msg_ptr',   'opaque', 'opaque' );  # *(void**)p
    $f->attach_cast( '_msg_to_str','opaque', 'string' );  # null-terminated C string
    $f;
  };
  # The struct starts with `char *message`. Cast the struct-pointer to
  # opaque*: FFI::Platypus reads the pointer at offset 0 for us.
  my $msg_ref  = $_decode_ffi->cast( 'opaque', 'opaque*', $err_ptr );
  my $msg_ptr  = ref $msg_ref ? $$msg_ref : $msg_ref;
  my $msg      = $msg_ptr ? $_decode_ffi->cast( 'opaque', 'string', $msg_ptr ) : '';
  # klass field follows at sizeof(ptr); skipping for MVP — message is all we use.
  return ( $msg, 0 );
}

sub last {
  my ( $class, $rc ) = @_;
  $rc //= -1;
  Git::Libgit2::FFI::ffi();   # ensure FFI is initialised
  my $err_ptr = Git::Libgit2::FFI::git_error_last();
  my ( $msg, $klass ) = _decode($err_ptr);
  return bless {
    code    => $rc,
    klass   => $klass,
    message => $msg || '<no error>',
  }, $class;
}

=method last

    die Git::Libgit2::Error->last($rc);

Construct an error object from libgit2's current thread-local error state
(C<git_error_last>). C<$rc> is the return code that triggered the lookup and
defaults to C<-1>. Always returns a blessed object, even when libgit2 reports
no error — C<message> is then C<< <no error> >>.

=cut

sub code    { $_[0]->{code} }

=method code

    my $rc = $error->code;

The libgit2 return code that triggered this error.

=cut

sub klass   { $_[0]->{klass} }

=method klass

    my $klass = $error->klass;

The libgit2 error class (C<git_error_t> category). Currently always C<0> — the
C<klass> field is not yet decoded from the C<git_error> struct.

=cut

sub message { $_[0]->{message} }

=method message

    my $msg = $error->message;

The human-readable libgit2 error message, or C<< <no error> >> when libgit2
reported none.

=cut

sub stringify {
  my $self = shift;
  sprintf 'libgit2 error %d (klass %d): %s',
    $self->{code}, $self->{klass}, $self->{message};
}

=method stringify

    my $str = $error->stringify;
    print "$error";   # same, via overloaded stringification

Format the error as C<"libgit2 error CODE (klass KLASS): MESSAGE">. Also wired
up as the C<""> overload, so the object stringifies to this in interpolation
and when thrown.

=cut

use overload
  '""'     => \&stringify,
  fallback => 1;

1;

=synopsis

  my $rc = git_repository_open(\my $repo, $path);
  if ($rc < 0) {
    die Git::Libgit2::Error->last($rc);   # stringifies
  }

=description

Plain object with C<code>, C<klass>, C<message>. Stringifies via overload.
Used by L<Git::Native> to construct typed exceptions.

=cut
