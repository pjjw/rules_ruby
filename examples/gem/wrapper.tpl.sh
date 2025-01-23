#!/usr/bin/env bash

@@rlocation_lib@@

set -euo pipefail

rake="$(rlocation @@rake_binary@@)"

echo "calling rake --version from a shell wrapper"
"$rake" --version
