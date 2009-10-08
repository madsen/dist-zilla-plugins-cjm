#---------------------------------------------------------------------
# Configure Pod::Loom for Dist-Zilla-PluginBundle-CJM
#---------------------------------------------------------------------

use strict;
use warnings;

{
  # This template will be filled in by TemplateCJM:
  version_desc => <<'END VERSION',
This document describes version {{$version}} of
{{$module}}, released {{$date}}
as part of {{$dist}} version {{$dist_version}}.
END VERSION
};
