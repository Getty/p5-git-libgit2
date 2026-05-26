# Git::Libgit2

Low-level [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) bindings to
[libgit2](https://libgit2.org/), via [Alien::Libgit2](https://metacpan.org/pod/Alien::Libgit2).

## Synopsis

```perl
use Git::Libgit2 qw( init_lib shutdown_lib version check_rc );

init_lib();
printf "libgit2 %s\n", version();

# Work directly with the FFI layer
use Git::Libgit2::FFI;
check_rc Git::Libgit2::FFI::git_repository_open(\my $repo, '/path/to/repo/.git');
check_rc Git::Libgit2::FFI::git_repository_free($repo);
shutdown_lib();
```

## Description

`Git::Libgit2` provides Perl-level access to the libgit2 C library through
FFI — no XS, no compiler needed at install time. It is intentionally a thin
surface over the C API: opaque handles, return codes, and manual memory
management are all exposed as they would be in C.

For an idiomatic Perl wrapper with automatic resource cleanup, see
[Git::Native](https://metacpan.org/pod/Git::Native) — it wraps this module
with Moo objects.

This module is the **bindings layer**. The two main namespaces are:

- `Git::Libgit2` — top-level facade with `init_lib`, `shutdown_lib`, `version`,
  `check_rc`, `oid_from_hex`, `oid_to_hex`, and a handful of constants.
- `Git::Libgit2::FFI` — the internal singleton that holds all attached libgit2
  functions. Call it after `init_lib`.

### Error handling

`check_rc` (from `Git::Libgit2`) passes return codes through on success, and
throws a `Git::Libgit2::Error` on failure:

```perl
check_rc Git::Libgit2::FFI::git_repository_open(\my $repo, $path);
# throws Git::Libgit2::Error if rc < 0
```

`Git::Libgit2::Error` stringifies to a message from `git_error_last`, carries
`.code` and `.message` accessors, and overloads `""`.

### OID buffers

libgit2 represents object IDs as 20-byte raw binary. Perl code must pre-allocate
this buffer and keep it alive for the duration of any call that reads or writes
the OID:

```perl
my $buf = "\0" x 20;              # 20-byte OID buffer
my ($ptr) = scalar_to_buffer($buf);
check_rc Git::Libgit2::FFI::git_blob_create_from_buffer($ptr, $repo, $content_ptr, length($content));
# — $buf must stay alive here —
```

`oid_from_hex` and `oid_to_hex` (from `Git::Libgit2`) convert between the
binary form and the 40-character hex string representation.

### Handle lifetime

Every `*_new` / `*_lookup` call must be matched with its corresponding
`*_free` call. The bindings expose the raw handles; there is no RAII here.
See [Git::Native](https://metacpan.org/pod/Git::Native) for a wrapper that
handles this automatically.

## Installation

```bash
cpanm Git::Libgit2
```

Requires a libgit2 shared library. `Alien::Libgit2` will download and build one
automatically if one is not already installed on your system.

## Functions

### Top-level helpers (Git::Libgit2)

| Function | Description |
|----------|--------------|
| `init_lib` | Initialize libgit2 (reference-counted) |
| `shutdown_lib` | Decrement init count, returns remaining count |
| `version` | libgit2 version string or (`$maj`, `$min`, `$rev`) list |
| `check_rc RC` | Pass through if `RC >= 0`, else throw `Git::Libgit2::Error` |
| `oid_from_hex STR` | 40-hex-char string → 20-byte binary OID |
| `oid_to_hex OID_PTR` | OID pointer → 40-hex-char string |

### Repository

| Function | Description |
|----------|--------------|
| `git_repository_open` |
| `git_repository_open_ext` |
| `git_repository_init` |
| `git_repository_workdir` |
| `git_repository_path` |
| `git_repository_is_bare` |
| `git_repository_free` |
| `git_repository_index` |
| `git_repository_config` |
| `git_repository_config_snapshot` |
| `git_repository_odb` |

### Reference

| Function | Description |
|----------|--------------|
| `git_reference_lookup` |
| `git_reference_name_to_id` |
| `git_reference_create` |
| `git_reference_delete` |
| `git_reference_remove` |
| `git_reference_target` |
| `git_reference_name` |
| `git_reference_type` |
| `git_reference_free` |
| `git_reference_iterator_new` |
| `git_reference_iterator_glob_new` |
| `git_reference_next` |
| `git_reference_next_name` |
| `git_reference_iterator_free` |
| `git_reference_name_is_valid` |
| `git_reference_peel` |
| `git_branch_create` |
| `git_branch_lookup` |
| `git_branch_delete` |
| `git_branch_iterator_new` |
| `git_branch_next` |
| `git_branch_iterator_free` |
| `git_branch_name` |
| `git_branch_is_head` |
| `git_branch_move` |

### Commit / Tree / Blob

| Function | Description |
|----------|--------------|
| `git_commit_lookup` |
| `git_commit_create` |
| `git_commit_message` |
| `git_commit_tree` |
| `git_commit_tree_id` |
| `git_commit_parentcount` |
| `git_commit_parent_id` |
| `git_commit_author` |
| `git_commit_committer` |
| `git_commit_free` |
| `git_tree_lookup` |
| `git_tree_entrycount` |
| `git_tree_entry_byindex` |
| `git_tree_entry_byname` |
| `git_tree_entry_name` |
| `git_tree_entry_id` |
| `git_tree_entry_filemode` |
| `git_tree_entry_type` |
| `git_tree_free` |
| `git_blob_create_from_buffer` |
| `git_blob_lookup` |
| `git_blob_rawcontent` |
| `git_blob_rawsize` |
| `git_blob_is_binary` |
| `git_blob_free` |
| `git_treebuilder_new` |
| `git_treebuilder_insert` |
| `git_treebuilder_remove` |
| `git_treebuilder_write` |
| `git_treebuilder_free` |

### Tag

| Function | Description |
|----------|--------------|
| `git_tag_create` |
| `git_tag_create_from_buffer` |
| `git_tag_create_lightweight` |
| `git_tag_lookup` |
| `git_tag_delete` |
| `git_tag_list` |
| `git_tag_list_match` |
| `git_tag_target` |
| `git_tag_target_id` |
| `git_tag_message` |
| `git_tag_name` |
| `git_tag_tagger` |
| `git_tag_free` |

### Revision Walking

| Function | Description |
|----------|--------------|
| `git_revwalk_new` |
| `git_revwalk_push` |
| `git_revwalk_push_head` |
| `git_revwalk_push_ref` |
| `git_revwalk_push_glob` |
| `git_revwalk_push_range` |
| `git_revwalk_hide` |
| `git_revwalk_hide_head` |
| `git_revwalk_hide_ref` |
| `git_revwalk_hide_glob` |
| `git_revwalk_next` |
| `git_revwalk_sorting` |
| `git_revwalk_reset` |
| `git_revwalk_simplify_first_parent` |
| `git_revwalk_free` |

### Status

| Function | Description |
|----------|--------------|
| `git_status_options_init` |
| `git_status_foreach` |
| `git_status_foreach_ext` |
| `git_status_file` |

### Diff

| Function | Description |
|----------|--------------|
| `git_diff_options_init` |
| `git_diff_tree_to_tree` |
| `git_diff_tree_to_workdir` |
| `git_diff_tree_to_index` |
| `git_diff_index_to_workdir` |
| `git_diff_num_deltas` |
| `git_diff_get_delta` |
| `git_diff_free` |

### Index

| Function | Description |
|----------|--------------|
| `git_index_open` |
| `git_index_read` |
| `git_index_write` |
| `git_index_read_tree` |
| `git_index_write_tree` |
| `git_index_add_bypath` |
| `git_index_add_all` |
| `git_index_remove_bypath` |
| `git_index_clear` |
| `git_index_entrycount` |
| `git_index_get_byindex` |
| `git_index_find` |
| `git_index_free` |

### Checkout

| Function | Description |
|----------|--------------|
| `git_checkout_options_init` |
| `git_checkout_head` |
| `git_checkout_index` |
| `git_checkout_tree` |

### Remote

| Function | Description |
|----------|--------------|
| `git_remote_lookup` |
| `git_remote_create` |
| `git_remote_create_anonymous` |
| `git_remote_url` |
| `git_remote_name` |
| `git_remote_init_callbacks` |
| `git_remote_fetch` |
| `git_remote_push` |
| `git_remote_connect` |
| `git_remote_ls` |
| `git_remote_disconnect` |
| `git_remote_free` |

### Credentials

| Function | Description |
|----------|--------------|
| `git_credential_userpass_plaintext_new` |
| `git_credential_ssh_key_new` |
| `git_credential_ssh_key_from_agent` |
| `git_credential_default_new` |
| `git_credential_username_new` |
| `git_credential_free` |

### Merge

| Function | Description |
|----------|--------------|
| `git_annotated_commit_lookup` |
| `git_annotated_commit_from_ref` |
| `git_annotated_commit_id` |
| `git_annotated_commit_free` |
| `git_merge_base` |
| `git_merge_base_many` |
| `git_merge_analysis` |
| `git_merge_options_init` |

### Rebase

| Function | Description |
|----------|--------------|
| `git_rebase_init` |
| `git_rebase_open` |
| `git_conflicts_next` (placeholder for conflicts) |
| `git_rebase_next` |
| `git_rebase_commit` |
| `git_rebase_abort` |
| `git_rebase_finish` |
| `git_rebase_free` |
| `git_rebase_operation_entrycount` |
| `git_rebase_operation_current` |
| `git_rebase_operation_byindex` |
| `git_rebase_options_init` |
| `git_rebase_orig_head_name` |
| `git_rebase_orig_head_id` |
| `git_rebase_onto_name` |
| `git_rebase_onto_id` |

### Cherry-pick / Revert

| Function | Description |
|----------|--------------|
| `git_cherrypick` |
| `git_cherrypick_commit` |
| `git_cherrypick_options_init` |
| `git_revert` |
| `git_revert_commit` |
| `git_revert_options_init` |

### Graph

| Function | Description |
|----------|--------------|
| `git_graph_ahead_behind` |
| `git_graph_descendant_of` |

### Stash

| Function | Description |
|----------|--------------|
| `git_stash_save` |
| `git_stash_apply` |
| `git_stash_drop` |

### Reflog

| Function | Description |
|----------|--------------|
| `git_reflog_read` |
| `git_reflog_entrycount` |
| `git_reflog_entry_byindex` |
| `git_reflog_entry_id_new` |
| `git_reflog_entry_message` |
| `git_reflog_free` |

### Object Database

| Function | Description |
|----------|--------------|
| `git_odb_new` |
| `git_odb_exists` |
| `git_odb_free` |

### Revparse / Reset

| Function | Description |
|----------|--------------|
| `git_revparse_single` |
| `git_revparse_ext` |
| `git_reset` |
| `git_reset_default` |

### Clone

| Function | Description |
|----------|--------------|
| `git_clone_options_init` |
| `git_clone` |

### Config

| Function | Description |
|----------|--------------|
| `git_config_open_default` |
| `git_config_snapshot` |
| `git_config_get_string` |
| `git_config_set_string` |
| `git_config_free` |

### Signature

| Function | Description |
|----------|--------------|
| `git_signature_new` |
| `git_signature_now` |
| `git_signature_default` |
| `git_signature_free` |

## See also

- [Git::Native](https://metacpan.org/pod/Git::Native) — idiomatic Moo wrapper with RAII
- [Alien::Libgit2](https://metacpan.org/pod/Alien::Libgit2)
- [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus)
- [libgit2](https://libgit2.org/)

## License

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.
