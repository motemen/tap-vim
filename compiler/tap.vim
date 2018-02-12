if exists("current_compiler")
  finish
endif
let current_compiler = "tap"

if exists(":CompilerSet") != 2
  command! -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=node\ %
CompilerSet errorformat=
  \%-GTAP%.%#,
  \%-Gok%.%#,
  \%Enot%.%#-\ %m,
  \%-C\ \ ---,
  \%+C\ \ found:%m,
  \%+C\ \ wanted:%m,
  \%-C\ \ compare%.%#,
  \%-C\ \ at:,
  \%C\ \ \ \ line:\ %l,
  \%C\ \ \ \ column:\ %c,
  \%C\ \ \ \ file:\ %f,%Z,
  \%-G\ \ stack%.%#,
  \%-G\ \ \ \ O%.%#,
  \%-G\ \ source%.%#,
  \%-G\ \ \ \ t%.%#,
  \%-G\ \ ...

CompilerSet errorformat +=
  \%-GTAP%.%#,
  \%-Gok%.%#,
  \%Enot%.%#-\ %m,
  \%-C\ \ ---,
  \%+C\ \ found:,
  \%+C\ %.%#,
  \%+C\ \ wanted%.%#,
  \%+C\ %.%#,
  \%-C\ \ compare%.%#,
  \%-C\ %.%#,
  \%-C\ \ at:,
  \%C\ \ \ \ line:\ %l,
  \%C\ \ \ \ column:\ %c,
  \%C\ \ \ \ file:\ %f,%Z,
  \%-G\ \ stack%.%#,
  \%-G\ \ \ \ O%.%#,
  \%-G\ \ source%.%#,
  \%-G\ \ \ \ t%.%#,
  \%-G\ \ ...

CompilerSet errorformat +=
  \%-G%[0-9]%.%#,
  \%-G#%.%#
