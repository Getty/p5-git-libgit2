# Git::Libgit2

Low-level [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) bindings to
the [libgit2](https://libgit2.org/) C library, via
[Alien::Libgit2](https://metacpan.org/pod/Alien::Libgit2).

No fork/exec, no XS — Git operations run in-process against `libgit2` through a
thin FFI layer that stays intentionally close to the C surface.

## Why it exists

`Git::Libgit2` is the bindings layer. It exposes `git_*` functions and the
constants needed to drive `libgit2` directly. It does not try to be ergonomic —
for an idiomatic Perl object wrapper with RAII handle management, use
[Git::Native](https://metacpan.org/pod/Git::Native), which is built on top of
this module.

- direct `git_*` FFI calls live in `Git::Libgit2::FFI`
- return codes are checked with `check_rc`
- errors throw `Git::Libgit2::Error` (carrying the libgit2 code + class)

## Synopsis

```perl
use Git::Libgit2 qw( init_lib version check_rc );

init_lib();
printf "libgit2 %s\n", version();

use Git::Libgit2::FFI;
my $rc = Git::Libgit2::FFI::git_repository_open(\my $repo, '/path/to/.git');
check_rc $rc;
```

## Installation

```bash
cpanm Git::Libgit2
```

Requires a working `libgit2`, provided automatically through `Alien::Libgit2`.

## See also

- [Git::Native](https://metacpan.org/pod/Git::Native) — idiomatic Moo wrapper
- [Alien::Libgit2](https://metacpan.org/pod/Alien::Libgit2)
- [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus)
- [libgit2](https://libgit2.org/)

## License

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.
