#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  repo_name="${GITHUB_REPOSITORY#*/}"
else
  repo_name="$(basename "$(pwd)")"
fi
base_href="/${repo_name}/demo/"

rm -rf build/site
mkdir -p build/site

dart doc --output build/site/api

pushd example
flutter pub get
flutter build web --release --base-href "${base_href}"
popd

mkdir -p build/site/demo
cp -a example/build/web/. build/site/demo/

cat > build/site/index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>iwb_canvas_engine</title>
    <style>
      :root { color-scheme: light dark; }
      body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 40px; line-height: 1.45; }
      .card { max-width: 720px; padding: 20px 22px; border: 1px solid rgba(127,127,127,.25); border-radius: 12px; }
      a { font-weight: 600; }
      ul { margin: 10px 0 0; padding-left: 18px; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>iwb_canvas_engine</h1>
      <p>GitHub Pages site for API reference and a live demo built from <code>example/</code>.</p>
      <ul>
        <li><a href="./demo/">Web demo</a></li>
        <li><a href="./api/">API reference (Dartdoc)</a></li>
      </ul>
    </div>
  </body>
</html>
HTML
