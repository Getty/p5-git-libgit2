# Git::Libgit2

Low-level [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) bindings to
[libgit2](https://libgit2.org/), via [Alien::Libgit2](https://github.com/Getty/p5-alien-libgit2).

## Where this sits

Four layers, each with one job:

```
App::karr            the application that wanted all this
  Git::Native        idiomatic Perl: Moo objects, RAII, typed exceptions
    Git::Libgit2     >>> this distribution <<<  1:1 FFI surface, no policy
      Alien::Libgit2 finds or builds the libgit2 shared library
        libgit2      the C library
```

This distribution is deliberately the boring one. It exposes libgit2's C API as
Perl subs and stops there: opaque handles stay opaque, return codes stay return
codes, and nothing is freed on your behalf. Every design question that has more
than one defensible answer — object model, exception classes, when a handle
dies — is answered one layer up, in
[Git::Native](https://github.com/Getty/p5-git-native).

If you want to *use* git from Perl, you probably want that one. If you want to
reach a libgit2 function nobody wrapped yet, you want this one.

## Status

- **236 libgit2 functions bound**, each with POD carrying a call example and its
  ownership rules — see [the full list below](#bound-surface).
- **The binding is not complete, on purpose.** [`TODO.md`](TODO.md) catalogues
  what is left, split into Group B (high value, wanted for a complete-enough
  release: diff text output, index conflicts, config iteration, …) and Group C
  (whole subsystems: blame, describe, submodule, worktree, notes, apply,
  attr/ignore, pathspec, mailmap).
- Signatures were catalogued against **libgit2 1.5.1**; the test suite runs
  against 1.5.1 (CI, Debian bookworm, perl 5.36/5.38/5.40) and 1.9.0.
- **`Alien::Libgit2` is not on CPAN yet**, so neither is this. See
  [Installation](#installation).

## Synopsis

```perl
use Git::Libgit2 qw( init_lib shutdown_lib version check_rc );
use Git::Libgit2::FFI ();

init_lib();
printf "libgit2 %s\n", scalar version();   # list context would give (1, 9, 0)

check_rc Git::Libgit2::FFI::git_repository_open(\my $repo, '/path/to/repo/.git');
print Git::Libgit2::FFI::git_repository_workdir($repo), "\n";

Git::Libgit2::FFI::git_repository_free($repo);   # void — nothing to check
shutdown_lib();
```

## Description

`Git::Libgit2` provides Perl-level access to the libgit2 C library through
FFI — no XS, no compiler needed at install time. It is intentionally a thin
surface over the C API: opaque handles, return codes, and manual memory
management are all exposed as they would be in C.

Two namespaces:

- `Git::Libgit2` — the facade. `init_lib`, `shutdown_lib`, `version`,
  `check_rc`, `oid_from_hex`, `oid_to_hex`, `fetch_options_prune_offset`, and
  the libgit2 constants.
- `Git::Libgit2::FFI` — the singleton `FFI::Platypus` instance holding every
  attached libgit2 function. Nothing is exported; call the functions
  fully qualified. `init_lib` must have run first.

### Error handling

libgit2 signals failure with a negative return code and parks the detail in
thread-local state. `check_rc` passes non-negative codes straight through and
turns negative ones into a thrown `Git::Libgit2::Error`:

```perl
check_rc Git::Libgit2::FFI::git_repository_open(\my $repo, $path);
# throws Git::Libgit2::Error if rc < 0
```

The error object carries `->code` (the return code), `->klass` (libgit2's error
category) and `->message`, and overloads `""` so it stringifies to
`libgit2 error -3 (klass 2): failed to resolve path ...`.

Only wrap calls that actually return `int`. A binding declared `void` — every
`*_free`, for instance — returns `undef`, and handing that to `check_rc` earns
you an uninitialized-value warning and nothing else.

Two return codes are not failures despite being negative: `GIT_ITEROVER` (-31)
ends an iterator, `GIT_PASSTHROUGH` (-30) declines a callback. Both must be
recognised before `check_rc` sees them.

### Handle lifetime

Every `*_new` / `*_lookup` / `*_create` call must be matched with its
corresponding `*_free`. The bindings hand out raw pointers and do not track
them; there is no RAII here.
[Git::Native](https://github.com/Getty/p5-git-native) does this with Moo
`DESTROY`, which is the reason it exists.

### OID buffers

libgit2 passes object IDs as a pointer to 20 raw bytes. Perl code has to
allocate that buffer itself and keep it alive across the call:

```perl
use FFI::Platypus::Buffer qw( scalar_to_buffer );

my $oid    = "\0" x 20;                  # Git::Libgit2::GIT_OID_RAWSZ
my ($optr) = scalar_to_buffer($oid);
my $content     = "hello\n";
my ($cptr, $clen) = scalar_to_buffer($content);

check_rc Git::Libgit2::FFI::git_blob_create_from_buffer($optr, $repo, $cptr, $clen);
# --- $oid and $content must both still be alive at this point ---

print Git::Libgit2::oid_to_hex($optr), "\n";
```

`oid_from_hex` and `oid_to_hex` convert between the raw form and the
40-character hex string. Note the asymmetry: `oid_from_hex` returns a *scalar
holding the bytes* (pass `scalar_to_buffer` on it to get a pointer), while
`oid_to_hex` wants the *pointer*.

### Struct layout is not stable across libgit2 releases

Options structs get initialised by libgit2 itself
(`git_fetch_options_init` and friends), so allocate a generous zeroed buffer
and let libgit2 fill it. What you must not do is compile in a field offset:
`git_fetch_options` embeds `git_remote_callbacks`, and that struct grew from
120 bytes in libgit2 1.5 to 128 in 1.9, dragging everything behind it along.

This fails silently, which is the dangerous part. Writing `prune` at the 1.5
offset while linked against 1.9 lands on `update_refs` — a function pointer
libgit2 prefers over `update_tips` and will happily call.

`Git::Libgit2::fetch_options_prune_offset` therefore probes the offset from the
library this process is actually linked against, and caches it. Any new
binding that needs to poke a field inside a versioned struct should do the
same rather than hardcode a number.

## Installation

Once `Alien::Libgit2` reaches CPAN this becomes:

```bash
cpanm Git::Libgit2
```

Until then both have to come from source, in this order:

```bash
git clone https://github.com/Getty/p5-alien-libgit2 && cd p5-alien-libgit2
cpanm --installdeps . && cpanm .

git clone https://github.com/Getty/p5-git-libgit2 && cd p5-git-libgit2
cpanm --installdeps . && prove -lr t/
```

`Alien::Libgit2` uses a system libgit2 when it finds one (`libgit2-dev` on
Debian, `libgit2` on Homebrew) and builds its own otherwise. No compiler is
needed for *this* distribution either way — it is pure Perl plus FFI.

## Helpers

The only functions in this distribution that are not a plain libgit2 call.
All live in `Git::Libgit2`, all exportable, none exported by default:

| Function | Description |
|----------|-------------|
| `init_lib` | Initialise libgit2; returns the new reference count. Croaks below 1 |
| `shutdown_lib` | Decrement the count, return what is left. No-op if never initialised |
| `version` | `"1.9.0"` in scalar context, `(1, 9, 0)` in list context |
| `check_rc RC` | Pass `RC` through when `>= 0`, else throw `Git::Libgit2::Error` |
| `oid_from_hex STR` | 40 hex chars → scalar holding the raw 20 bytes. Croaks on anything else |
| `oid_to_hex OID_PTR` | `git_oid` **pointer** → 40 hex chars |
| `fetch_options_prune_offset` | Byte offset of `prune` in `git_fetch_options`, probed at runtime and cached |

Plus the libgit2 constants — object types, filemodes, status and sort flags,
config levels, and the complete `git_error_code` enum through `GIT_EREADONLY`
(-40). `use Git::Libgit2 qw( :all )` imports the lot; see the
[`Git::Libgit2`](lib/Git/Libgit2.pm) POD for the groups.

## Bound surface

236 functions, grouped as in the
[`Git::Libgit2::FFI`](lib/Git/Libgit2/FFI.pm) POD, which is where the
signatures, out-parameters and `*_free` pairings live. `*_options_init` is
always the non-deprecated spelling — libgit2 1.7 removed the `*_init_options`
variants.

**Library init / shutdown** — `git_libgit2_init`, `git_libgit2_shutdown`, `git_libgit2_version`, `git_libgit2_opts`

**Error** — `git_error_last`, `git_error_clear`

**Repository** — `git_repository_open`, `git_repository_open_ext`, `git_repository_init`, `git_repository_set_head`, `git_repository_head`, `git_repository_head_unborn`, `git_repository_head_detached`, `git_repository_workdir`, `git_repository_path`, `git_repository_is_bare`, `git_repository_free`, `git_repository_index`, `git_repository_config`, `git_repository_config_snapshot`, `git_repository_odb`

**Config** — `git_config_open_default`, `git_config_snapshot`, `git_config_get_string`, `git_config_get_bool`, `git_config_set_string`, `git_config_free`

**OID** — `git_oid_fromstr`, `git_oid_tostr`, `git_oid_cmp`

**Reference** — `git_reference_lookup`, `git_reference_name_to_id`, `git_reference_create`, `git_reference_create_matching`, `git_reference_delete`, `git_reference_remove`, `git_reference_target`, `git_reference_name`, `git_reference_type`, `git_reference_free`, `git_reference_iterator_new`, `git_reference_iterator_glob_new`, `git_reference_next`, `git_reference_next_name`, `git_reference_iterator_free`, `git_reference_name_is_valid`, `git_reference_peel`, `git_reference_symbolic_create`, `git_reference_symbolic_target`, `git_reference_symbolic_set_target`, `git_reference_set_target`, `git_reference_resolve`, `git_reference_shorthand`, `git_reference_is_branch`, `git_reference_is_remote`, `git_reference_is_tag`

**Object** — `git_object_lookup`, `git_object_lookup_prefix`, `git_object_id`, `git_object_type`, `git_object_free`

**Blob** — `git_blob_create_from_buffer`, `git_blob_lookup`, `git_blob_rawcontent`, `git_blob_rawsize`, `git_blob_is_binary`, `git_blob_free`

**Tree** — `git_tree_lookup`, `git_tree_entrycount`, `git_tree_entry_byindex`, `git_tree_entry_byname`, `git_tree_entry_name`, `git_tree_entry_id`, `git_tree_entry_filemode`, `git_tree_entry_type`, `git_tree_free`

**TreeBuilder** — `git_treebuilder_new`, `git_treebuilder_insert`, `git_treebuilder_remove`, `git_treebuilder_write`, `git_treebuilder_free`

**Commit** — `git_commit_lookup`, `git_commit_create`, `git_commit_message`, `git_commit_tree`, `git_commit_tree_id`, `git_commit_parentcount`, `git_commit_parent_id`, `git_commit_author`, `git_commit_committer`, `git_commit_id`, `git_commit_time`, `git_commit_time_offset`, `git_commit_summary`, `git_commit_free`

**Signature** — `git_signature_new`, `git_signature_now`, `git_signature_default`, `git_signature_free`

**Remote** — `git_remote_lookup`, `git_remote_create`, `git_remote_create_anonymous`, `git_remote_url`, `git_remote_name`, `git_remote_init_callbacks`, `git_remote_fetch`, `git_remote_push`, `git_fetch_options_init`, `git_push_options_init`, `git_remote_connect`, `git_remote_ls`, `git_remote_disconnect`, `git_remote_free`

**Credentials** — `git_credential_userpass_plaintext_new`, `git_credential_ssh_key_new`, `git_credential_ssh_key_from_agent`, `git_credential_default_new`, `git_credential_username_new`, `git_credential_free`

**Clone** — `git_clone_options_init`, `git_clone`

**Strarray** — `git_strarray_free`

**Revwalk** — `git_revwalk_new`, `git_revwalk_push`, `git_revwalk_push_head`, `git_revwalk_push_ref`, `git_revwalk_push_glob`, `git_revwalk_push_range`, `git_revwalk_hide`, `git_revwalk_hide_head`, `git_revwalk_hide_ref`, `git_revwalk_hide_glob`, `git_revwalk_next`, `git_revwalk_sorting`, `git_revwalk_reset`, `git_revwalk_simplify_first_parent`, `git_revwalk_free`

**Branch** — `git_branch_create`, `git_branch_lookup`, `git_branch_delete`, `git_branch_iterator_new`, `git_branch_next`, `git_branch_iterator_free`, `git_branch_name`, `git_branch_is_head`, `git_branch_move`

**Status** — `git_status_options_init`, `git_status_foreach`, `git_status_foreach_ext`, `git_status_file`

**Tag** — `git_tag_create`, `git_tag_create_from_buffer`, `git_tag_create_lightweight`, `git_tag_lookup`, `git_tag_delete`, `git_tag_list`, `git_tag_list_match`, `git_tag_target`, `git_tag_target_id`, `git_tag_message`, `git_tag_name`, `git_tag_tagger`, `git_tag_free`

**Diff** — `git_diff_options_init`, `git_diff_tree_to_tree`, `git_diff_tree_to_workdir`, `git_diff_tree_to_index`, `git_diff_index_to_workdir`, `git_diff_num_deltas`, `git_diff_get_delta`, `git_diff_free`

**Index** — `git_index_open`, `git_index_read`, `git_index_write`, `git_index_read_tree`, `git_index_write_tree`, `git_index_add_bypath`, `git_index_add_all`, `git_index_remove_bypath`, `git_index_clear`, `git_index_entrycount`, `git_index_get_byindex`, `git_index_find`, `git_index_find_prefix`, `git_index_free`

**Checkout** — `git_checkout_options_init`, `git_checkout_head`, `git_checkout_index`, `git_checkout_tree`

**Revparse** — `git_revparse_single`, `git_revparse_ext`

**Reset** — `git_reset`, `git_reset_default`

**Merge** — `git_annotated_commit_lookup`, `git_annotated_commit_from_ref`, `git_annotated_commit_id`, `git_annotated_commit_free`, `git_merge_base`, `git_merge_base_many`, `git_merge_analysis`, `git_merge_options_init`

**Graph** — `git_graph_ahead_behind`, `git_graph_descendant_of`

**Stash** — `git_stash_save`, `git_stash_apply`, `git_stash_drop`

**Reflog** — `git_reflog_read`, `git_reflog_entrycount`, `git_reflog_entry_byindex`, `git_reflog_entry_id_new`, `git_reflog_entry_message`, `git_reflog_free`

**Rebase** — `git_rebase_init`, `git_rebase_open`, `git_rebase_next`, `git_rebase_commit`, `git_rebase_abort`, `git_rebase_finish`, `git_rebase_free`, `git_rebase_operation_entrycount`, `git_rebase_operation_current`, `git_rebase_operation_byindex`, `git_rebase_options_init`, `git_rebase_orig_head_name`, `git_rebase_orig_head_id`, `git_rebase_onto_name`, `git_rebase_onto_id`

**Cherry-pick** — `git_cherrypick`, `git_cherrypick_commit`, `git_cherrypick_options_init`

**Revert** — `git_revert`, `git_revert_commit`, `git_revert_options_init`

**ODB** — `git_odb_new`, `git_odb_exists`, `git_odb_free`

## Tests

```bash
prove -lr t/
```

Note the `-r`: plain `prove -l t/` is not recursive and silently skips
subdirectory tests.

Every test isolates itself from the developer's own git configuration —

```perl
local $ENV{GIT_CONFIG_GLOBAL} = '/dev/null';
local $ENV{GIT_CONFIG_SYSTEM} = '/dev/null';
```

— because a binding layer that writes to `~/.gitconfig` while its tests run is
a bug users find the hard way. `t/torture-init.t` additionally hammers
init/shutdown in a loop to catch reference-count drift.

## See also

- [Git::Native](https://github.com/Getty/p5-git-native) — the layer you
  probably want: Moo objects, RAII, typed exceptions
- [Alien::Libgit2](https://github.com/Getty/p5-alien-libgit2) — finds or builds
  the shared library
- [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) — the FFI engine
- [libgit2 API reference](https://libgit2.org/docs/reference/main/) — the
  authority on every signature bound here
- [Git::Raw](https://metacpan.org/pod/Git::Raw) — the established XS
  alternative; needs a compiler at install time

## License

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.
