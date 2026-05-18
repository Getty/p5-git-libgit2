# ABSTRACT: Internal FFI::Platypus instance for Git::Libgit2

package Git::Libgit2::FFI;
our $VERSION = '0.001';
use strict;
use warnings;
use FFI::Platypus 2.00;
use Alien::Libgit2;

my $ffi;

sub ffi {
  return $ffi if $ffi;
  $ffi = FFI::Platypus->new( api => 2, lib => [ Alien::Libgit2->dynamic_libs ] );

  $ffi->type( 'opaque' => 'git_repository'   );
  $ffi->type( 'opaque' => 'git_reference'    );
  $ffi->type( 'opaque' => 'git_reference_iterator' );
  $ffi->type( 'opaque' => 'git_config'       );
  $ffi->type( 'opaque' => 'git_object'       );
  $ffi->type( 'opaque' => 'git_blob'         );
  $ffi->type( 'opaque' => 'git_tree'         );
  $ffi->type( 'opaque' => 'git_treebuilder'  );
  $ffi->type( 'opaque' => 'git_commit'       );
  $ffi->type( 'opaque' => 'git_remote'       );
  $ffi->type( 'opaque' => 'git_signature'    );
  $ffi->type( 'opaque' => 'git_odb'          );

  # git_oid is a 20-byte struct, but for our MVP we pass it as opaque
  # buffer (string of 20 bytes) or as hex via _fromstr/_tostr.
  $ffi->type( 'opaque' => 'git_oid_ptr' );

  _attach_all();
  return $ffi;
}

sub _attach {
  my ( $name, $args, $ret ) = @_;
  $ffi->attach( $name => $args => $ret );
}

sub _attach_all {
  # Library init / shutdown
  _attach git_libgit2_init     => []                          => 'int';
  _attach git_libgit2_shutdown => []                          => 'int';
  _attach git_libgit2_version  => [ 'int*', 'int*', 'int*' ]  => 'int';

  # Error
  _attach git_error_last       => []                          => 'opaque';
  _attach git_error_clear      => []                          => 'void';

  # Repository
  _attach git_repository_open      => [ 'opaque*', 'string' ]                       => 'int';
  _attach git_repository_open_ext  => [ 'opaque*', 'string', 'uint32', 'string' ]   => 'int';
  _attach git_repository_init      => [ 'opaque*', 'string', 'uint32' ]             => 'int';
  _attach git_repository_workdir   => [ 'git_repository' ]                          => 'string';
  _attach git_repository_path      => [ 'git_repository' ]                          => 'string';
  _attach git_repository_is_bare   => [ 'git_repository' ]                          => 'int';
  _attach git_repository_free      => [ 'git_repository' ]                          => 'void';

  # Config
  _attach git_config_open_default  => [ 'opaque*' ]                                 => 'int';
  _attach git_repository_config    => [ 'opaque*', 'git_repository' ]               => 'int';
  _attach git_config_get_string    => [ 'opaque*', 'git_config', 'string' ]         => 'int';
  _attach git_config_set_string    => [ 'git_config', 'string', 'string' ]          => 'int';
  _attach git_config_free          => [ 'git_config' ]                              => 'void';

  # OID
  _attach git_oid_fromstr          => [ 'opaque', 'string' ]                        => 'int';
  _attach git_oid_tostr            => [ 'opaque', 'size_t', 'opaque' ]              => 'string';
  _attach git_oid_cmp              => [ 'opaque', 'opaque' ]                        => 'int';

  # Reference
  _attach git_reference_lookup     => [ 'opaque*', 'git_repository', 'string' ]                                  => 'int';
  _attach git_reference_name_to_id => [ 'opaque',  'git_repository', 'string' ]                                  => 'int';
  _attach git_reference_create     => [ 'opaque*', 'git_repository', 'string', 'opaque', 'int', 'string' ]       => 'int';
  _attach git_reference_delete     => [ 'git_reference' ]                                                        => 'int';
  _attach git_reference_remove     => [ 'git_repository', 'string' ]                                             => 'int';
  _attach git_reference_target     => [ 'git_reference' ]                                                        => 'opaque';
  _attach git_reference_name       => [ 'git_reference' ]                                                        => 'string';
  _attach git_reference_type       => [ 'git_reference' ]                                                        => 'int';
  _attach git_reference_free       => [ 'git_reference' ]                                                        => 'void';
  _attach git_reference_iterator_new       => [ 'opaque*', 'git_repository' ]                                    => 'int';
  _attach git_reference_iterator_glob_new  => [ 'opaque*', 'git_repository', 'string' ]                          => 'int';
  _attach git_reference_next               => [ 'opaque*', 'git_reference_iterator' ]                            => 'int';
  _attach git_reference_next_name          => [ 'string*', 'git_reference_iterator' ]                            => 'int';
  _attach git_reference_iterator_free      => [ 'git_reference_iterator' ]                                       => 'void';
  _attach git_reference_name_is_valid      => [ 'int*', 'string' ]                                               => 'int';

  # Object
  _attach git_object_lookup        => [ 'opaque*', 'git_repository', 'opaque', 'int' ]                           => 'int';
  _attach git_object_id            => [ 'git_object' ]                                                           => 'opaque';
  _attach git_object_type          => [ 'git_object' ]                                                           => 'int';
  _attach git_object_free          => [ 'git_object' ]                                                           => 'void';

  # Blob
  _attach git_blob_create_from_buffer => [ 'opaque', 'git_repository', 'opaque', 'size_t' ]                      => 'int';
  _attach git_blob_lookup             => [ 'opaque*', 'git_repository', 'opaque' ]                               => 'int';
  _attach git_blob_rawcontent         => [ 'git_blob' ]                                                          => 'opaque';
  _attach git_blob_rawsize            => [ 'git_blob' ]                                                          => 'sint64';
  _attach git_blob_free               => [ 'git_blob' ]                                                          => 'void';

  # Tree
  _attach git_tree_lookup          => [ 'opaque*', 'git_repository', 'opaque' ]                                  => 'int';
  _attach git_tree_entrycount      => [ 'git_tree' ]                                                             => 'size_t';
  _attach git_tree_entry_byindex   => [ 'git_tree', 'size_t' ]                                                   => 'opaque';
  _attach git_tree_entry_byname    => [ 'git_tree', 'string' ]                                                   => 'opaque';
  _attach git_tree_entry_name      => [ 'opaque' ]                                                               => 'string';
  _attach git_tree_entry_id        => [ 'opaque' ]                                                               => 'opaque';
  _attach git_tree_entry_filemode  => [ 'opaque' ]                                                               => 'int';
  _attach git_tree_entry_type      => [ 'opaque' ]                                                               => 'int';
  _attach git_tree_free            => [ 'git_tree' ]                                                             => 'void';

  # TreeBuilder
  _attach git_treebuilder_new      => [ 'opaque*', 'git_repository', 'opaque' ]                                  => 'int';
  _attach git_treebuilder_insert   => [ 'opaque*', 'git_treebuilder', 'string', 'opaque', 'int' ]                => 'int';
  _attach git_treebuilder_remove   => [ 'git_treebuilder', 'string' ]                                            => 'int';
  _attach git_treebuilder_write    => [ 'opaque', 'git_treebuilder' ]                                            => 'int';
  _attach git_treebuilder_free     => [ 'git_treebuilder' ]                                                      => 'void';

  # Commit
  _attach git_commit_lookup        => [ 'opaque*', 'git_repository', 'opaque' ]                                  => 'int';
  _attach git_commit_create        => [ 'opaque', 'git_repository', 'string', 'git_signature', 'git_signature',
                                        'string', 'string', 'git_tree', 'size_t', 'opaque' ]                     => 'int';
  _attach git_commit_message       => [ 'git_commit' ]                                                           => 'string';
  _attach git_commit_tree          => [ 'opaque*', 'git_commit' ]                                                => 'int';
  _attach git_commit_tree_id       => [ 'git_commit' ]                                                           => 'opaque';
  _attach git_commit_parentcount   => [ 'git_commit' ]                                                           => 'uint';
  _attach git_commit_parent_id     => [ 'git_commit', 'uint' ]                                                   => 'opaque';
  _attach git_commit_author        => [ 'git_commit' ]                                                           => 'opaque';
  _attach git_commit_committer     => [ 'git_commit' ]                                                           => 'opaque';
  _attach git_commit_free          => [ 'git_commit' ]                                                           => 'void';

  # Signature
  _attach git_signature_new        => [ 'opaque*', 'string', 'string', 'sint64', 'int' ]                         => 'int';
  _attach git_signature_now        => [ 'opaque*', 'string', 'string' ]                                          => 'int';
  _attach git_signature_default    => [ 'opaque*', 'git_repository' ]                                            => 'int';
  _attach git_signature_free       => [ 'git_signature' ]                                                        => 'void';

  # Remote
  _attach git_remote_lookup        => [ 'opaque*', 'git_repository', 'string' ]                                  => 'int';
  _attach git_remote_create        => [ 'opaque*', 'git_repository', 'string', 'string' ]                        => 'int';
  _attach git_remote_url           => [ 'git_remote' ]                                                           => 'string';
  _attach git_remote_name          => [ 'git_remote' ]                                                           => 'string';
  _attach git_remote_free          => [ 'git_remote' ]                                                           => 'void';
}

1;

=head1 NAME

Git::Libgit2::FFI - Internal FFI::Platypus instance for Git::Libgit2

=head1 SYNOPSIS

  use Git::Libgit2::FFI;
  my $ffi = Git::Libgit2::FFI::ffi();

=head1 DESCRIPTION

Internal use only. Holds the singleton C<FFI::Platypus> instance with all
attached libgit2 functions. Consumers should use L<Git::Libgit2> instead.

=cut
