# Git::Libgit2

Low-level FFI::Platypus bindings to libgit2, via L<Alien::Libgit2>.

## What It Does

1:1 surface of libgit2's C API exposed as Perl subs. No Moo, no objects,
no error-to-exception translation — that lives one layer up in
`Git::Native`.

Opaque libgit2 handles are exposed as `opaque` pointers (FFI::Platypus
type). Callers are responsible for matching every `*_new`/`*_lookup`
with the corresponding `*_free`. The high-level `Git::Native` wrapper
does this via Moo `DESTROY`.

## Architecture

- `Git::Libgit2` — top-level facade. `init_lib()`, `version()`, type
  registry, exports a few helpers.
- `Git::Libgit2::FFI` — internal `FFI::Platypus` instance with all the
  `attach` calls. Singleton — one FFI per process.
- `Git::Libgit2::Error` — wraps `git_error_last()`. Used by consumers
  to turn libgit2 error codes into structured info; not thrown here.

## Phase 1 MVP Cut (what App::karr needs)

`git_libgit2_init`/`_shutdown`, `git_repository_open_ext`/`_workdir`/`_free`,
`git_config_open_default`, `git_reference_lookup`/`_create`/`_delete`/
`_iterator_new`/`_next`/`_name`/`_target`,
`git_oid_fromstr`/`_tostr`,
`git_blob_create_from_buffer`/`_lookup`/`_rawcontent`/`_rawsize`/`_free`,
`git_treebuilder_new`/`_insert`/`_write`/`_free`,
`git_commit_create`/`_lookup`/`_tree`/`_message`/`_free`,
`git_object_lookup`/`_free`,
`git_reference_name_is_valid`,
`git_remote_lookup`/`_url`,
`git_error_last`.

Network ops (`git_remote_fetch`/`_push`, credential callbacks) come in
Phase 4.

## Build

- `[@Author::GETTY]` Dist::Zilla bundle.
- Dep: `Alien::Libgit2` (must be released first).
- No XS, no compiler needed at install — pure Perl + FFI.

## Tests

Each FFI function gets a smoke test in `t/`. Plus `t/torture-init.t`
hammers init/shutdown in a loop. All tests run with
`GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null` to avoid
the Git::Raw bug of polluting the user's `~/.gitconfig`.
