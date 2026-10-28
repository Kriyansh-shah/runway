#!/usr/bin/env bash
# Builds the website into _site/: the landing page, the privacy policy and
# support page (from docs/*.md), and the web app under app/. Used by
# .github/workflows/website.yml. To preview locally, build for the root:
#   BASE_HREF=/app/ scripts/build_site.sh && python3 -m http.server -d _site
set -euo pipefail
cd "$(dirname "$0")/.."

base="${BASE_HREF:-/runway/app/}"
rm -rf _site
mkdir -p _site/fonts

cp site/index.html site/try.html site/try.js site/site.css _site/
cp assets/icon/icon.png _site/icon.png
cp assets/fonts/BricolageGrotesque.ttf _site/fonts/

page() { # page <markdown> <out> <title>
  local body
  body="$(npx --yes marked@15.0.12 --gfm -i "$1")"
  TITLE="$3" BODY="$body" python3 - "$2" <<'PY'
import os, sys
html = open("site/page.html").read()
html = html.replace("{{title}}", os.environ["TITLE"]).replace("{{content}}", os.environ["BODY"])
open(sys.argv[1], "w").write(html)
PY
}
page docs/privacy.md _site/privacy.html "Privacy policy"
page docs/support.md _site/support.html "Support"

# The rendering engine is served from this site, not Google's CDN, so the
# Content-Security-Policy in web/index.html can stay "this site only".
flutter build web --release --no-web-resources-cdn --base-href "$base"
cp -r build/web _site/app
touch _site/.nojekyll
echo "Built _site/ (web app base href $base)"
