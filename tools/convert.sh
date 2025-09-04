#!/usr/bin/env sh
# shellcheck disable=SC3043
set -e
trap cleanup EXIT
cleanup() {
  if test -f "${DocsPath}/metadata.json"; then
    rm -f "${DocsPath}/metadata.json"
  fi
}
error() {
  local line="${1}"
  local message="${2}"
  local code=-1
  if [ $# -gt 2 ]; then
    code="${3}"
  fi
  local line_message=""
  if [ -n "${line}" ]; then
    line_message=" (line ${line})"
  fi
  if [ ${code} -ne -1 ] && [ -n "${message}" ]; then
    message="${message} (exit code ${code})"
  else
    message="Unspecified (exit code ${code})"
  fi
  command printf '\033[1;31mError%s\033[0m: %s\n' "${line_message}" "${message}" 1>&2
  exit "${code}"
}
warning() {
  command printf '\033[1;33mWarning\033[0m: %s\n' "$1" 1>&2
}
info() {
  currentTime=$(date "+%Y-%m-%d %T")
  if [ $# -gt 1 ]; then
    command printf '\033[36m%14s\033[0m %s\n' "${currentTime} ${1}" "${2}" 1>&2
  else
    command printf '\033[36m%s\033[0m\n' "${currentTime} ${1}" 1>&2
  fi
}
test_arg() {
  if [ $# -lt 4 ] || test -z "${4}" || echo "${4}" | grep -Eq '^-.*'; then
    if [ "${1}" = 'true' ]; then
      echo "${2}"
    else
      error '' "Value not set for argument ${3}" 1
    fi
  else
    echo "${4}"
  fi
}
test_true_false() {
  if [ $# -gt 1 ]; then
    local default="${2}"
  else
    local default='false'
  fi
  local value
  value="$(echo "${1}" | awk '{ print tolower($0) }')"
  if test -z "${value}"; then
    echo "${default}"
  elif [ "${value}" = 'true' ] || [ "${value}" = 'yes' ] || [ "${value}" = '1' ]; then
    echo 'true'
  elif [ "${value}" = 'false' ] || [ "${value}" = 'no' ] || [ "${value}" = '0' ]; then
    echo 'false'
  else
    echo "${default}"
  fi
}
get_file_path() {
  if test -z "${1}"; then
    echo ''
  elif test -e "${1}"; then
    readlink -f "${1}"
  elif test -e "${2}/${1}"; then
    readlink -f "${2}/${1}"
  else
    echo ''
  fi
}
get_version_history() {
  if test -n "${historyFilePath}"; then
    if ! test -f "${historyFilePath}"; then
      error '' "Unable to find history file ${historyFilePath}" 1
    fi
    mergeLogs=$(cat "${historyFilePath}")
  elif [ "${SkipGitCommitHistory}" = 'true' ]; then
    mergeLogs="tag: rel/repo/1.0.0|${currentDate}|${MainAuthor}|${FirstChangeDescription}"
  else
    mergeLogs=$(
      git --no-pager log "-${GitLogLimit}" --date-order --date=format:'%b %e, %Y' \
        --no-merges --oneline --pretty=format:'%D|%ad|%an|%s' "${DocsPath}"
    )
  fi
  if test -z "${mergeLogs}"; then
    mergeLogs="tag: rel/repo/1.0.0|${currentDate}|${MainAuthor}|${FirstChangeDescription}"
  fi
  lineCount=$(echo "${mergeLogs}" | wc -l)
  historyJson='[]'
  printf '%s\n' "${mergeLogs}" | while read -r line; do
    lineCount=$((lineCount-1))
    version="$(echo "$line" | cut -d'|' -f1 | rev | cut -d'/' -f1 | rev)"
    if test -z "${version}" || ! echo "${version}" | grep -Eq '^[0-9].*'; then
      version="1.0.${lineCount}"
    fi
    date="$(echo "${line}" | cut -d'|' -f2)"
    author="$(echo "${line}" | cut -d'|' -f3)"
    description="$(echo "${line}" | cut -d'|' -f4)"
    if test -f tmp_history_41231.json; then
      historyJson=$(jq '.' tmp_history_41231.json)
    fi
    printf '%s\n' "${historyJson}" | jq --arg version "${version}" \
      --arg date "${date}" \
      --arg author "${author}" \
      --arg description "${description}" \
      '. +=[{ version: $version, date: $date, author: $author, description: $description }]' > tmp_history_41231.json
  done
  if test -f tmp_history_41231.json; then
    jq '.' tmp_history_41231.json
  else
    printf '%s\n' '[]' | jq --arg version '1.0.0' \
        --arg date "${currentDate}" \
        --arg author "${MainAuthor}" \
        --arg description "${FirstChangeDescription}" \
        '. +=[{ version: $version, date: $date, author: $author, description: $description }]' > tmp_history_41231.json
    jq '.' tmp_history_41231.json
  fi
  rm -f tmp_history_41231.json
}
process_params() {
  while [ $# -gt 0 ]; do
    local arg="$1"
    case "$arg" in
      -a|--author)
        MainAuthor=$(test_arg true 'Innofactor' "$@")
        shift 2
        ;;
      -d|--description)
        FirstChangeDescription=$(test_arg true 'Initial draft' "$@")
        shift 2
        ;;
      -f|--folder)
        DocsPath=$(test_arg false '' "$@")
        shift 2
        ;;
      -force|--force-default)
        shift
        if [ $# -eq 0 ] || echo "${1}" | grep -Eq '^-.*'; then
          SkipGitCommitHistory='true'
        else
          SkipGitCommitHistory=$(test_true_false "${1}")
          shift
        fi
        ;;
      -h|--historyfile)
        HistoryFile=$(test_arg true '' "$@")
        shift 2
        ;;
      -l|--gitloglimit)
        GitLogLimit=$(test_arg true 15 "$@")
        shift 2
        ;;
      -o|--orderfile)
        OrderFile=$(test_arg false '' "$@")
        shift 2
        ;;
      -out|--outfile)
        OutFile=$(test_arg true 'document.order' "$@")
        shift 2
        ;;
      -p|--project)
        Project=$(test_arg true '' "$@")
        shift 2
        ;;
      -r|--replacefile)
        ReplaceFile=$(test_arg true '' "$@")
        shift 2
        ;;
      -s|--subtitle)
        Subtitle=$(test_arg true '' "$@")
        shift 2
        ;;
      -t|--title)
        Title=$(test_arg false '' "$@")
        shift 2
        ;;
      --template)
        Template=$(test_arg true 'designdoc' "$@")
        shift 2
        ;;
      *)
        warning "Unknown parameter: $1"
        exit 1
        ;;
    esac
  done
}
MainAuthor='Innofactor'
FirstChangeDescription='Initial draft'
DocsPath='docs'
SkipGitCommitHistory='false'
HistoryFile=''
GitLogLimit=15
OrderFile='document.order'
OutFile='document.pdf'
Project=''
ReplaceFile=''
Subtitle=''
Template='designdoc'
Title=''
process_params "$@"
if test -z "${Title}"; then
  error '' 'Missing Title: Value not set for argument --title' 1
fi
currentDate=$(date "+%B %d, %Y")
currentPath=$(pwd)
# Ensure OutFile has full path
if ! echo "${OutFile}" | grep -Eq '^[a-zA-Z]:\\.*' && ! echo "${OutFile}" | grep -Eq '^/.*'; then
  OutFile="${currentPath}/${OutFile}"
fi
if ! echo "${DocsPath}" | grep -Eq '^[a-zA-Z]:\\.*' && ! echo "${DocsPath}" | grep -Eq '^/.*'; then
  DocsPath="${currentPath}/${DocsPath}"
fi
if ! test -d "${DocsPath}"; then
  error '' "Unable to find folder ${DocsPath}" 1
fi
scriptPath="$(dirname "$(readlink -f "$0")")"
# Get path to docs files in the same folder as the docs
historyFilePath=$(get_file_path "${HistoryFile}" "${DocsPath}")
orderFilePath=$(get_file_path "${OrderFile}" "${DocsPath}")
if ! test -f "${orderFilePath}"; then
  error '' "Unable to find order file ${orderFilePath}" 1
fi
replaceFilePath=$(get_file_path "${ReplaceFile}" "${DocsPath}")
# Get path to template files in the same folder as the script
templateFilePath=$(get_file_path "${Template}.tex" "${scriptPath}")
if ! test -f "${templateFilePath}"; then
  error '' "Unable to find template file ${templateFilePath}" 1
fi
templateCoverFilePath=$(get_file_path "${Template}-cover.png" "${scriptPath}")
if ! test -f "${templateCoverFilePath}"; then
  error '' "Unable to find template cover file ${templateCoverFilePath}" 1
fi
templateLogoFilePath=$(get_file_path "${Template}-logo.png" "${scriptPath}")
if ! test -f "${templateLogoFilePath}"; then
  error '' "Unable to find template logo file ${templateLogoFilePath}" 1
fi
info 'Get version history'
versionHistory=$(get_version_history)
if [ "$(printf '%s' "${OutFile}" | tail -c 3)" = '.md' ]; then
  mdOutFile="${OutFile}"
else
  mdOutFile="${OutFile}.md"
fi
info "Merge markdown files in ${orderFilePath}"
printf '%s\n' "$(cat "${orderFilePath}")" | while read -r line; do
  if test -n "${line}" && ! [ "$(printf '%s' "$line" | cut -c 1)" = '#' ]; then
    if ! test -f "${DocsPath}/${line}"; then
      error '' "Unable to find markdown file ${DocsPath}/${line}" 1
    fi
    mdFile="$(readlink -f "${DocsPath}/${line}")"
    mdPath="$(dirname "$mdFile")"
    tmpContent=$(
      printf '%s' "$(sed -e "s|\(\[.*\](\)\(\../\)\(.*)\)|\1${mdPath}/\2\3|g" "${mdFile}" | sed -e "s|\(\[.*\](\)\(\./\)\(.*)\)|\1${mdPath}/\3|g" | sed -e "s|\(\[.*\](\)\(asset\)\(.*)\)|\1${mdPath}/\2\3|g" | sed -e "s|\(\[.*\](\)\(attach\)\(.*)\)|\1${mdPath}/\2\3|g" | sed -e "s|\(\[.*\](\)\(image\)\(.*)\)|\1${mdPath}/\2\3|g" | sed -e "s|\(\[.*\](\)\(\.\)\(.*)\)|\1${mdPath}/\2\3|g")"
    )
    if test -n "${tmpContent}"; then
      info "Found ${#tmpContent} characters in ${mdFile}"
      if ! test -f "${mdOutFile}"; then
        printf '%s\n' "${tmpContent}" > "${mdOutFile}"
      else
        printf '\n%s\n' "${tmpContent}" >> "${mdOutFile}"
      fi
    fi
  else
    info "Ignore ${line}"
  fi
done
info 'Done merging markdown files'
if ! test -f "${mdOutFile}"; then
  warning 'Unable to merge markdown files, no content found!'
  exit 1
fi

if test -n "${ReplaceFile}"; then
  if [ ! -f "$replaceFilePath" ]; then
    error '' "Unable to find replace file $replaceFilePath" 1
  else
    jq -r 'to_entries | map("\(.key)/\(.value|tostring)") | .[]' "$replaceFilePath" |
      xargs -I {} sed -i 's/{}/g' "$mdOutFile"
  fi
fi


# Pre-process: Convert Mermaid code blocks to images and replace with image links
mermaid_img_dir="${DocsPath}/mermaid-imgs"
mkdir -p "$mermaid_img_dir"

# Create puppeteer config file for mmdc
puppeteer_config_file="/tmp/puppeteer.config.json"
cat > "$puppeteer_config_file" << 'EOF'
{
  "args": [
    "--no-sandbox",
    "--disable-setuid-sandbox",
    "--disable-dev-shm-usage",
    "--disable-gpu",
    "--font-render-hinting=none",
    "--disable-web-security",
    "--disable-features=IsolateOrigins,site-per-process"
  ],
  "headless": true,
  "ignoreHTTPSErrors": true,
  "defaultViewport": {
    "width": 1200,
    "height": 800,
    "deviceScaleFactor": 1
  }
}
EOF

# Create Mermaid config file with enhanced settings for text visibility
mermaid_config_file="/tmp/mermaid.config.json"
cat > "$mermaid_config_file" << 'EOF'
{
  "theme": "default",
  "themeVariables": {
    "fontFamily": "DejaVu Sans, Liberation Sans, Arial, sans-serif",
    "fontSize": "16px",
    "primaryColor": "#000000",
    "primaryTextColor": "#000000",
    "primaryBorderColor": "#000000",
    "lineColor": "#000000",
    "secondaryColor": "#444444",
    "tertiaryColor": "#dddddd"
  },
  "maxTextSize": 5000,
  "htmlLabels": true,
  "securityLevel": "loose",
  "flowchart": {
    "htmlLabels": true,
    "curve": "linear"
  },
  "sequence": {
    "useMaxWidth": false,
    "boxMargin": 10
  }
}
EOF

# Use awk to extract and replace mermaid code blocks
awk_script='BEGIN{inblock=0;imgidx=0;}
{
  if ($0 ~ /^```mermaid[[:space:]]*$/) {
    inblock=1;
    imgidx++;
    imgfile=sprintf("MERMAID_PLACEHOLDER_%d", imgidx);
    print imgfile > "/tmp/mermaid_imglist.txt";
    # Clear any previous content and start fresh
    system("rm -f /tmp/mermaid_" imgfile ".mmd");
    next;
  }
  if (inblock && $0 ~ /^```[[:space:]]*$/) {
    inblock=0;
    print "![](mermaid-imgs/" imgfile ".svg)";
    next;
  }
  if (inblock) {
    # Write each line directly to the file
    print $0 >> "/tmp/mermaid_" imgfile ".mmd";
    next;
  }
  print;
}'

awk "$awk_script" "${mdOutFile}" > "${mdOutFile}.with_mermaid"

# Render all Mermaid diagrams
if [ -f /tmp/mermaid_imglist.txt ]; then
  # Ensure Puppeteer environment is set for mmdc
  export PUPPETEER_EXECUTABLE_PATH="${PUPPETEER_EXECUTABLE_PATH:-/usr/bin/chromium}"
  export PUPPETEER_ARGS="${PUPPETEER_ARGS:---no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu}"

  # For Alpine Linux specifically, add these additional settings
  export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
  export PUPPETEER_SKIP_DOWNLOAD=true

  # Debug: Check if mmdc and chromium are available
  info "Debug: PUPPETEER_EXECUTABLE_PATH=$PUPPETEER_EXECUTABLE_PATH"
  info "Debug: PUPPETEER_ARGS=$PUPPETEER_ARGS"
  if command -v mmdc >/dev/null 2>&1; then
    info "Debug: mmdc found at $(which mmdc)"
  else
    warning "Debug: mmdc not found in PATH"
  fi
  if [ -x "$PUPPETEER_EXECUTABLE_PATH" ]; then
    info "Debug: Chromium found at $PUPPETEER_EXECUTABLE_PATH"
  else
    warning "Debug: Chromium not found at $PUPPETEER_EXECUTABLE_PATH"
    # Try to find chromium with different names (Alpine may use different binary names)
    for chrome_bin in chromium-browser chrome google-chrome; do
      if command -v "$chrome_bin" >/dev/null 2>&1; then
        export PUPPETEER_EXECUTABLE_PATH=$(command -v "$chrome_bin")
        info "Debug: Found alternative browser at $PUPPETEER_EXECUTABLE_PATH"
        break
      fi
    done
  fi

  while read -r imgfile; do
    info "Debug: Rendering $imgfile with content:"
    if [ ! -f "/tmp/mermaid_${imgfile}.mmd" ]; then
      warning "Mermaid file /tmp/mermaid_${imgfile}.mmd not found, skipping"
      continue
    fi

    # Show the content for debugging
    cat "/tmp/mermaid_${imgfile}.mmd"

    # Validate that the file has content
    if [ ! -s "/tmp/mermaid_${imgfile}.mmd" ]; then
      warning "Mermaid file /tmp/mermaid_${imgfile}.mmd is empty, skipping"
      continue
    fi

    # Set a flag to track if we successfully generated an SVG
    svg_generation_success=false

    # Try to run mmdc with enhanced configuration for better text rendering
    info "Attempting mmdc with primary configuration..."
    mmdc_output=$(mmdc -i "/tmp/mermaid_${imgfile}.mmd" -o "$mermaid_img_dir/${imgfile}.svg" \
      --puppeteerConfigFile "$puppeteer_config_file" \
      --configFile "$mermaid_config_file" \
      --fontFamily "Arial, sans-serif" \
      --width 1200 \
      --scale 1.5 \
      --backgroundColor white 2>&1) || true

    # Check if SVG was generated successfully
    if [ -f "$mermaid_img_dir/${imgfile}.svg" ] && [ -s "$mermaid_img_dir/${imgfile}.svg" ]; then
      svg_generation_success=true
      info "Successfully rendered mermaid diagram with primary configuration"
    else
      warning "Primary mmdc configuration failed: $mmdc_output"

      # Try with minimal configuration
      info "Attempting mmdc with minimal configuration..."
      mmdc_output=$(mmdc -i "/tmp/mermaid_${imgfile}.mmd" -o "$mermaid_img_dir/${imgfile}.svg" \
        --fontFamily "Arial" \
        --width 1000 \
        --scale 1.2 \
        --backgroundColor white 2>&1) || true

      if [ -f "$mermaid_img_dir/${imgfile}.svg" ] && [ -s "$mermaid_img_dir/${imgfile}.svg" ]; then
        svg_generation_success=true
        info "Successfully rendered mermaid diagram with minimal configuration"
      else
        warning "Minimal mmdc configuration failed: $mmdc_output"

        # Last attempt with absolute minimal settings
        info "Attempting mmdc with failsafe configuration..."
        mmdc_output=$(mmdc -i "/tmp/mermaid_${imgfile}.mmd" -o "$mermaid_img_dir/${imgfile}.svg" \
          --backgroundColor white 2>&1) || true

        if [ -f "$mermaid_img_dir/${imgfile}.svg" ] && [ -s "$mermaid_img_dir/${imgfile}.svg" ]; then
          svg_generation_success=true
          info "Successfully rendered mermaid diagram with failsafe configuration"
        else
          warning "All mmdc configurations failed. Creating placeholder image."

          # Create a placeholder SVG with the diagram content as text
          mermaid_content=$(cat "/tmp/mermaid_${imgfile}.mmd" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
          cat > "$mermaid_img_dir/${imgfile}.svg" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">
  <rect width="100%" height="100%" fill="white"/>
  <text x="10" y="20" font-family="Arial, sans-serif" font-size="16" fill="black">Mermaid diagram could not be rendered.</text>
  <text x="10" y="45" font-family="Arial, sans-serif" font-size="12" fill="black">Diagram source code:</text>
  <foreignObject x="10" y="60" width="780" height="530">
    <div xmlns="http://www.w3.org/1999/xhtml" style="font-family: monospace; white-space: pre; font-size: 12px;">$mermaid_content</div>
  </foreignObject>
</svg>
EOF
          info "Created placeholder SVG with diagram source code"
          svg_generation_success=true
        fi
      fi
    fi

    # If we have an SVG file at this point, process it
    if [ "$svg_generation_success" = true ]; then
      info "Successfully rendered mermaid diagram: $imgfile"

      # Process the SVG to enhance text visibility
      info "Post-processing SVG to improve text rendering..."

      # Save original SVG as backup
      cp "$mermaid_img_dir/${imgfile}.svg" "$mermaid_img_dir/${imgfile}_original.svg"

      # Use available fonts on the system - Alpine typically has DejaVu and Liberation fonts
      sed -i 's/<text/<text font-family="DejaVu Sans, Liberation Sans, Arial, sans-serif" font-size="16px" /g' "$mermaid_img_dir/${imgfile}.svg" 2>/dev/null || true

      # Fix any empty text elements or make them more visible
      sed -i 's/<text[^>]*><\/text>/<text font-family="DejaVu Sans, Liberation Sans, Arial, sans-serif" font-size="16px" fill="black">Text<\/text>/g' "$mermaid_img_dir/${imgfile}.svg" 2>/dev/null || true

      # Ensure all text has proper fill color
      sed -i 's/fill="none"/fill="black"/g' "$mermaid_img_dir/${imgfile}.svg" 2>/dev/null || true

      # Add text stroke for better visibility
      sed -i 's/<text/<text stroke="none" /g' "$mermaid_img_dir/${imgfile}.svg" 2>/dev/null || true

      # Modify SVG viewBox if needed to avoid cropping
      viewbox=$(grep -o 'viewBox="[^"]*"' "$mermaid_img_dir/${imgfile}.svg")
      if [ -n "$viewbox" ]; then
        # Add 5% padding to viewBox values
        new_viewbox=$(echo "$viewbox" | awk -F'"' '{
          split($2, a, " ");
          x = a[1]; y = a[2]; w = a[3]; h = a[4];
          pad_w = w * 0.05; pad_h = h * 0.05;
          printf("viewBox=\"%s %s %s %s\"", x-pad_w, y-pad_h, w+pad_w*2, h+pad_h*2);
        }')
        if [ -n "$new_viewbox" ]; then
          sed -i "s/$viewbox/$new_viewbox/g" "$mermaid_img_dir/${imgfile}.svg" 2>/dev/null || true
        fi
      fi

      # Debug: Check if SVG contains text elements and show sample text
      text_count=$(grep -c "<text" "$mermaid_img_dir/${imgfile}.svg" 2>/dev/null || echo "0")
      # Ensure we have a valid integer
      text_count=${text_count:-0}
      info "Debug: SVG contains $text_count text elements"
      if [ "$text_count" -gt 0 ]; then
        sample_text=$(grep -o "<text[^>]*>[^<]*</text>" "$mermaid_img_dir/${imgfile}.svg" 2>/dev/null | head -3 | sed 's/<[^>]*>//g' | tr '\n' ' ')
        info "Debug: Sample text content: $sample_text"
      else
        warning "Warning: SVG file contains no text elements, text may not be visible"
        # Show a bit of the SVG structure for debugging
        info "Debug: SVG structure preview:"
        head -20 "$mermaid_img_dir/${imgfile}.svg" | grep -E "<(g|rect|path|circle|text)" 2>/dev/null || true
      fi

      # Convert SVG to PNG to ensure text is preserved in PDF
      info "Converting SVG to PNG for better PDF compatibility..."

      png_success=false

      # Method 1: Try Inkscape first (primary method - fix black box issue)
      if command -v inkscape >/dev/null 2>&1; then
        info "Attempting PNG conversion with Inkscape..."

        # Sanitize SVG to remove filters and other elements that can trigger black boxes in headless Inkscape
        source_svg="$mermaid_img_dir/${imgfile}.svg"
        sanitized_svg="/tmp/${imgfile}_sanitized.svg"
        plain_svg="/tmp/${imgfile}_plain.svg"

        # Copy the source SVG to sanitized version
        cp "$source_svg" "$sanitized_svg" 2>/dev/null || true

        if [ -f "$sanitized_svg" ]; then
          # First stage: Remove problematic elements that cause black box rendering
          pre_filter_count=$(grep -c "<filter" "$sanitized_svg" 2>/dev/null || echo "0")
          pre_clippath_count=$(grep -c "<clipPath" "$sanitized_svg" 2>/dev/null || echo "0")
          pre_mask_count=$(grep -c "<mask" "$sanitized_svg" 2>/dev/null || echo "0")

          # Ensure we have valid integers for arithmetic
          pre_filter_count=${pre_filter_count:-0}
          pre_clippath_count=${pre_clippath_count:-0}
          pre_mask_count=${pre_mask_count:-0}

          # Remove filter elements completely
          sed -i '/<filter[[:space:]]/,/<\/filter>/d' "$sanitized_svg" 2>/dev/null || true
          # Remove filter references
          sed -i -E 's/[[:space:]]filter="url\(#[-A-Za-z0-9_]+\)"//g' "$sanitized_svg" 2>/dev/null || true
          # Remove specific filter elements
          sed -i '/<feDropShadow[[:space:]]/d' "$sanitized_svg" 2>/dev/null || true
          sed -i '/<feGaussianBlur[[:space:]]/d' "$sanitized_svg" 2>/dev/null || true
          sed -i '/<feOffset[[:space:]]/d' "$sanitized_svg" 2>/dev/null || true
          sed -i '/<feComposite[[:space:]]/d' "$sanitized_svg" 2>/dev/null || true
          sed -i '/<feMerge[[:space:]]/d' "$sanitized_svg" 2>/dev/null || true
          sed -i '/<feMergeNode[[:space:]]/d' "$sanitized_svg" 2>/dev/null || true

          # Remove clipPath elements
          sed -i '/<clipPath[[:space:]]/,/<\/clipPath>/d' "$sanitized_svg" 2>/dev/null || true
          sed -i -E 's/[[:space:]]clip-path="url\(#[-A-Za-z0-9_]+\)"//g' "$sanitized_svg" 2>/dev/null || true

          # Remove mask elements
          sed -i '/<mask[[:space:]]/,/<\/mask>/d' "$sanitized_svg" 2>/dev/null || true
          sed -i -E 's/[[:space:]]mask="url\(#[-A-Za-z0-9_]+\)"//g' "$sanitized_svg" 2>/dev/null || true

          # Log counts
          post_filter_count=$(grep -c "<filter" "$sanitized_svg" 2>/dev/null || echo "0")
          post_clippath_count=$(grep -c "<clipPath" "$sanitized_svg" 2>/dev/null || echo "0")
          post_mask_count=$(grep -c "<mask" "$sanitized_svg" 2>/dev/null || echo "0")

          # Ensure we have valid integers for arithmetic
          post_filter_count=${post_filter_count:-0}
          post_clippath_count=${post_clippath_count:-0}
          post_mask_count=${post_mask_count:-0}

          # Safely perform arithmetic operations with error handling
          removed_filters=0
          removed_clippaths=0
          removed_masks=0

          if [ "$pre_filter_count" -ge "$post_filter_count" ]; then
            removed_filters=$((pre_filter_count - post_filter_count))
          fi

          if [ "$pre_clippath_count" -ge "$post_clippath_count" ]; then
            removed_clippaths=$((pre_clippath_count - post_clippath_count))
          fi

          if [ "$pre_mask_count" -ge "$post_mask_count" ]; then
            removed_masks=$((pre_mask_count - post_mask_count))
          fi

          total_removed=$((removed_filters + removed_clippaths + removed_masks))

          if [ "$total_removed" -gt 0 ]; then
            info "Sanitized SVG: removed $removed_filters filters, $removed_clippaths clip paths, $removed_masks masks for $imgfile"
          fi

          # Second stage: Use Inkscape to create a "plain SVG" format which is more compatible
          if [ -s "$sanitized_svg" ]; then
            info "Creating plain SVG format for better compatibility..."
            inkscape --export-plain-svg="$plain_svg" "$sanitized_svg" >/dev/null 2>&1 || cp "$sanitized_svg" "$plain_svg"
            if [ -s "$plain_svg" ]; then
              info "Successfully created plain SVG version"
              svg_for_inkscape="$plain_svg"
            else
              svg_for_inkscape="$sanitized_svg"
            fi
          else
            svg_for_inkscape="$source_svg"
          fi
        else
          svg_for_inkscape="$source_svg"
        fi

        # Ensure we have a valid SVG to work with
        [ -s "$svg_for_inkscape" ] || svg_for_inkscape="$source_svg"

        # Debug: Show Inkscape version and first lines
        inkscape_version=$(inkscape --version 2>&1 | head -1)
        info "Debug: Using $inkscape_version"
        head -n 4 "$svg_for_inkscape" 2>/dev/null | sed 's/^/      /'

        # Try a two-pass approach for better results
        # Approach 1: Use export-area-drawing with high DPI
        info "Inkscape approach 1: export-area-drawing with high DPI"
        png_output=$(inkscape \
          --export-type=png \
          --export-area-drawing \
          --export-dpi=300 \
          --export-background=white \
          --export-background-opacity=1 \
          --export-filename="$mermaid_img_dir/${imgfile}.png" \
          "$svg_for_inkscape" 2>&1) || true

        if [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
          png_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
          if [ "$png_size" -gt 1500 ]; then
            png_success=true
            info "Successfully converted to PNG with Inkscape (approach 1): ${imgfile}.png (${png_size} bytes)"
          else
            info "Inkscape approach 1 small (${png_size} bytes) trying approach 2..."
          fi
        else
          info "Inkscape approach 1 failed: $png_output"
        fi

        if [ "$png_success" = false ]; then
          # Approach 2: Try with different export options
            info "Inkscape approach 2: export-area-page with fixed width"
            png_output=$(inkscape \
              --export-type=png \
              --export-area-page \
              --export-background=white \
              --export-background-opacity=1.0 \
              --export-dpi=300 \
              --export-width=3000 \
              --export-filename="$mermaid_img_dir/${imgfile}.png" \
              "$svg_for_inkscape" 2>&1) || true

            if [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
              png_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
              if [ "$png_size" -gt 1500 ]; then
                png_success=true
                info "Successfully converted to PNG with Inkscape (approach 2): ${imgfile}.png (${png_size} bytes)"
              else
                info "Inkscape approach 2 also small (${png_size} bytes), trying approach 3..."

                # Approach 3: Last resort - render with forced bitmap conversion
                info "Inkscape approach 3: text-to-path conversion"
                png_output=$(inkscape \
                  --export-type=png \
                  --export-area-page \
                  --export-background=white \
                  --export-background-opacity=1.0 \
                  --export-dpi=300 \
                  --export-text-to-path \
                  --export-filename="$mermaid_img_dir/${imgfile}.png" \
                  "$source_svg" 2>&1) || true

                if [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
                  png_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
                  if [ "$png_size" -gt 1500 ]; then
                    png_success=true
                    info "Successfully converted to PNG with Inkscape (approach 3): ${imgfile}.png (${png_size} bytes)"
                  else
                    info "All Inkscape approaches failed to create a proper PNG."
                  fi
                else
                  info "Inkscape approach 3 failed: $png_output"
                fi
              fi
            else
              info "Inkscape approach 2 failed: $png_output"
            fi
        fi
      else
        info "Inkscape not available, trying other methods..."
      fi

      # Method 2: Chromium backup (improved to handle truncation)
      if [ "$png_success" = false ]; then
        if command -v chromium >/dev/null 2>&1; then
          info "Attempting PNG conversion with Chromium (enhanced method)..."

          # Create an improved HTML wrapper that handles text better
          html_file="/tmp/mermaid_${imgfile}.html"
          cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background: white;
      font-family: Arial, sans-serif;
    }
    body {
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 100px;
      min-height: 100vh;
    }
    svg {
      max-width: none !important;
      max-height: none !important;
      width: auto !important;
      height: auto !important;
      min-width: 800px !important;
      min-height: 600px !important;
    }
    text {
      font-family: Arial, sans-serif !important;
      font-size: 16px !important;
      fill: black !important;
    }
    .node rect, .node circle, .node polygon, .node path {
      fill: white !important;
      stroke: black !important;
      stroke-width: 2px !important;
    }
    .edgePath path {
      stroke: black !important;
      stroke-width: 2px !important;
    }
  </style>
</head>
<body>
EOF

          # Embed the SVG content
          cat "$mermaid_img_dir/${imgfile}.svg" >> "$html_file"

          cat >> "$html_file" << 'EOF'
</body>
</html>
EOF

          # Use larger window size to prevent truncation with Alpine compatibility flags
          info "Running Chromium with enhanced Alpine compatibility settings..."
          png_output=$(chromium --headless --disable-gpu --no-sandbox --disable-setuid-sandbox \
            --disable-dev-shm-usage \
            --window-size=3000,2000 --hide-scrollbars --disable-web-security \
            --disable-features=VizDisplayCompositor \
            --virtual-time-budget=10000 \
            --force-device-scale-factor=2 \
            --screenshot="$mermaid_img_dir/${imgfile}.png" \
            "file://$html_file" 2>&1) || true

          if [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
            png_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
            if [ "$png_size" -gt 1000 ]; then
              png_success=true
              info "Successfully converted to PNG with Chromium: ${imgfile}.png (${png_size} bytes)"
            else
              info "Chromium PNG too small (${png_size} bytes)"

              # Try a second approach with Chromium with simplified options
              info "Trying simplified Chromium approach..."
              png_output=$(chromium --headless --disable-gpu --no-sandbox --disable-dev-shm-usage \
                --window-size=1200,1200 \
                --screenshot="$mermaid_img_dir/${imgfile}.png" \
                "file://$html_file" 2>&1) || true

              if [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
                png_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
                if [ "$png_size" -gt 1000 ]; then
                  png_success=true
                  info "Successfully converted to PNG with simplified Chromium approach: ${imgfile}.png (${png_size} bytes)"
                else
                  info "All Chromium approaches failed to produce a proper PNG"
                fi
              fi
            fi
          else
            info "Chromium conversion failed: $png_output"
          fi

          # Clean up HTML file
          rm -f "$html_file"
        else
          info "Chromium not available"
        fi
      fi

      # Method 3: Direct SVG use with fallback
      if [ "$png_success" = false ]; then
        info "Both Inkscape and Chromium methods failed. Setting up for direct SVG inclusion..."

        # Create a simplified version of the SVG that's more compatible with PDF conversion
        simplified_svg="$mermaid_img_dir/${imgfile}_simplified.svg"

        # Copy original and simplify
        cp "$mermaid_img_dir/${imgfile}.svg" "$simplified_svg"

        # Set explicit dimensions if missing
        if ! grep -q "width=" "$simplified_svg"; then
          sed -i 's/<svg/<svg width="1200" height="800" /g' "$simplified_svg" 2>/dev/null || true
        fi

        # Fix any font issues using Alpine Linux system fonts
        sed -i 's/font-family="[^"]*"/font-family="DejaVu Sans, Liberation Sans, Arial, sans-serif"/g' "$simplified_svg" 2>/dev/null || true
        sed -i 's/font-size="[^"]*"/font-size="16px"/g' "$simplified_svg" 2>/dev/null || true

        # Ensure all text has proper fill color
        sed -i 's/fill="[^"]*"/fill="black"/g' "$simplified_svg" 2>/dev/null || true

        # Fix text positioning if needed
        sed -i 's/<text/<text dominant-baseline="central" /g' "$simplified_svg" 2>/dev/null || true

        # Use this simplified SVG instead of PNG (PDF generation will handle it)
        if [ -s "$simplified_svg" ] && [ "$(stat -c '%s' "$simplified_svg")" -gt 100 ]; then
          info "Created simplified SVG for direct inclusion in PDF"
          cp "$simplified_svg" "$mermaid_img_dir/${imgfile}.svg"

          # Create a basic PNG as a fallback using ImageMagick if available
          if command -v convert >/dev/null 2>&1; then
            # Try using system fonts that are likely available on Alpine
            for font in DejaVu-Sans Liberation-Sans Arial Helvetica; do
              convert -size 1200x800 xc:white -gravity center \
                -font "$font" -pointsize 20 \
                -annotate 0 "Mermaid Diagram" \
                -font "$font" -pointsize 16 \
                -annotate +0+40 "See PDF for complete visualization" \
                "$mermaid_img_dir/${imgfile}.png" 2>/dev/null && break
            done

            # If that fails, try without specifying a font
            if [ ! -f "$mermaid_img_dir/${imgfile}.png" ]; then
              convert -size 1200x800 xc:white -gravity center \
                -pointsize 20 -annotate 0 "Mermaid Diagram" \
                -pointsize 16 -annotate +0+40 "See PDF for complete visualization" \
                "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || true
            fi

            if [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
              png_success=true
              info "Created basic fallback PNG with ImageMagick"
            fi
          fi
        fi
      fi

      # Debug: Show final PNG status
      if [ "$png_success" = true ] && [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
        final_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
        info "Final PNG: ${imgfile}.png (${final_size} bytes)"

        # Verify PNG has meaningful content - not just black
        if command -v file >/dev/null 2>&1; then
          file_info=$(file "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "")
          if [ -n "$file_info" ]; then
            info "PNG file info: $file_info"
          fi
        fi

        # Update the markdown to use PNG instead of SVG for better PDF text rendering
        sed -i "s|${imgfile}\.svg|${imgfile}.png|g" "${mdOutFile}.with_mermaid"
      else
        warning "Could not create proper PNG for $imgfile"

        # Create a minimal valid PNG to avoid breaking the PDF generation
        if ! [ -f "$mermaid_img_dir/${imgfile}.png" ] || [ "$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")" -lt 100 ]; then
          info "Creating minimal emergency PNG file"
          # Echo a minimal valid PNG header (1x1 transparent pixel)
          echo -ne "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\x0A\x49\x44\x41\x54\x78\x9C\x63\x00\x01\x00\x00\x05\x00\x01\x0D\x0A\x2D\xB4\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82" > "$mermaid_img_dir/${imgfile}.png"
        fi

        # Just continue with the SVG
        info "Using SVG for this diagram, text may not render properly in final PDF"
      fi
    else
      warning "Failed to render mermaid diagram: $imgfile"
      info "mmdc output: $mmdc_output"

      # Create a placeholder SVG with the diagram source code
      info "Creating placeholder SVG with diagram source..."
      mermaid_content=$(cat "/tmp/mermaid_${imgfile}.mmd" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
      cat > "$mermaid_img_dir/${imgfile}.svg" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">
  <rect width="100%" height="100%" fill="white"/>
  <text x="10" y="20" font-family="DejaVu Sans, Liberation Sans, Arial, sans-serif" font-size="16" fill="black">Mermaid diagram could not be rendered.</text>
  <text x="10" y="45" font-family="DejaVu Sans, Liberation Sans, Arial, sans-serif" font-size="12" fill="black">Diagram source code:</text>
  <foreignObject x="10" y="60" width="780" height="530">
    <div xmlns="http://www.w3.org/1999/xhtml" style="font-family: monospace; white-space: pre; font-size: 12px;">$mermaid_content</div>
  </foreignObject>
</svg>
EOF
      info "Created placeholder SVG with diagram source code"

      # Create a minimal PNG as well
      echo -ne "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\x0A\x49\x44\x41\x54\x78\x9C\x63\x00\x01\x00\x00\x05\x00\x01\x0D\x0A\x2D\xB4\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82" > "$mermaid_img_dir/${imgfile}.png"

      # Update the markdown to use PNG instead of SVG
      sed -i "s|${imgfile}\.svg|${imgfile}.png|g" "${mdOutFile}.with_mermaid" 2>/dev/null || true
    fi
  done < /tmp/mermaid_imglist.txt
fi

mdContent=$(cat "${mdOutFile}.with_mermaid")

authors=$(echo "${versionHistory}" | jq '.[].author' | uniq | sed ':a; N; $!ba; s/\n/,/g')
set_metadataContent() {
  metadataContent="$(cat)"
}
backslash='\'
#  "footer-center": "Page (${backslash}${backslash}thepage ) of ${backslash}${backslash}pageref{LastPage}",
set_metadataContent <<META_DATA || true
{
  "author": [
    ${authors}
  ],
  "block-headings": true,
  "colorlinks": true,
  "date": "${currentDate}",
  "disable-header-and-footer": false,
  "disclaimer": "This document contains business and trade secrets (essential information about Innofactor's business) and is therefore totally confidential. Confidentiality does not apply to pricing information",
  "footer-center": "Page ${backslash}${backslash}thepage",
  "geometry":"a4paper,left=2.54cm,right=2.54cm,top=1.91cm,bottom=2.54cm",
  "links-as-notes": true,
  "listings-disable-line-numbers": false,
  "listings-no-page-break": false,
  "lof": false,
  "logo": "${templateLogoFilePath}",
  "lot": false,
  "mainfont": "Carlito",
  "project": "${Project}",
  "subtitle": "${Subtitle}",
  "table-use-row-colors": false,
  "tables": true,
  "title": "${Title}",
  "titlepage": true,
  "titlepage-color":"FFFFFF",
  "titlepage-text-color": "5F5F5F",
  "titlepage-top-cover-image": "${templateCoverFilePath}",
  "toc": true,
  "toc-own-page": true,
  "toc-title": "Table of Contents",
  "version-history": ${versionHistory}
}
META_DATA
if test -n "${mdContent}"; then
  info "The markdown contains ${#mdContent} characters"
  if ! [ "$(printf '%s' "${OutFile}" | tail -c 3)" = '.md' ]; then
    info "Create ${OutFile} using metadata:"
    printf '%s\n' "${metadataContent}"
    printf '%s\n' "${metadataContent}" | jq '.' > "${DocsPath}/metadata.json"
    # We need to be in the docs path so image paths can be relative
    cd "${DocsPath}"

    # Note: Temporarily disabling pandoc-latex-environment filter due to compatibility issues
    # Can be re-enabled when the LaTeX template compatibility is resolved
    filter_args=""
    warning "pandoc-latex-environment filter disabled due to LaTeX compatibility issues"

    # Debug: Check what's in the markdown content for any pandoc-specific syntax
    info "Debug: Checking for pandoc-latex-environment syntax in markdown"
    if echo "${mdContent}" | grep -q ":::"; then
      warning "Found ::: syntax in markdown, but pandoc-latex-environment filter is disabled"
    fi

    echo "${mdContent}" | pandoc \
      --standalone \
      --listings \
      --pdf-engine=xelatex \
      --metadata-file="${DocsPath}/metadata.json" \
      -f markdown+backtick_code_blocks+pipe_tables+auto_identifiers+yaml_metadata_block+table_captions+footnotes+smart \
      --template="${templateFilePath}" \
      ${filter_args} \
      --verbose \
      --output="${OutFile}"
    cd "${currentPath}"
  fi

  # Show summary of generated Mermaid images
  if [ -d "${DocsPath}/mermaid-imgs" ]; then
    svg_count=$(find "${DocsPath}/mermaid-imgs" -name "*.svg" 2>/dev/null | wc -l)
    png_count=$(find "${DocsPath}/mermaid-imgs" -name "*.png" 2>/dev/null | wc -l)
    if [ "$svg_count" -gt 0 ] || [ "$png_count" -gt 0 ]; then
      info "Generated Mermaid diagrams in ${DocsPath}/mermaid-imgs/:"
      info "  - $svg_count SVG files (original)"
      info "  - $png_count PNG files (for PDF compatibility)"
      find "${DocsPath}/mermaid-imgs" -name "*.svg" -o -name "*.png" 2>/dev/null | while read img_file; do
        size=$(($(stat -c '%s' "$img_file" 2>/dev/null || echo "0") / 1000))
        info "  - $(basename "$img_file") (${size} KB)"
      done
    fi
  fi

  # Clean up temp files
  rm -f /tmp/mermaid_imglist.txt /tmp/mermaid_*.mmd "$puppeteer_config_file" "$mermaid_config_file"
  if ! test -f "${OutFile}"; then
    warning "Unable to create ${OutFile}"
  else
    size=$(($(stat -c '%s' "${OutFile}") / 1000))
    info "Created ${OutFile} using ${size} KB"
  fi
fi
