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
  if [ $# -gt 2 ]; then
    local code="${3}"
  else
    local code=-1
  fi
  local line_message=""
  if [ "$line" != '' ]; then
    line_message=" on or near line ${line}"
  fi
  if test -n "${message}"; then
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
    "--disable-setuid-sandbox"
  ],
  "executablePath": "/usr/bin/chromium"
}
EOF

# Create Mermaid config file with enhanced settings for text visibility
mermaid_config_file="/tmp/mermaid.config.json"
cat > "$mermaid_config_file" << 'EOF'
{
  "theme": "default",
  "themeVariables": {
    "fontFamily": "Arial, sans-serif",
    "fontSize": "16px",
    "primaryColor": "#0078d4",
    "primaryTextColor": "#333333",
    "primaryBorderColor": "#444444",
    "lineColor": "#666666",
    "secondaryColor": "#006100",
    "tertiaryColor": "#fff",
    "clusterBkg": "#f4f4f4",
    "defaultLinkColor": "#333333",
    "titleColor": "#333333",
    "edgeLabelBackground": "#ffffff"
  },
  "flowchart": {
    "htmlLabels": true,
    "curve": "basis"
  },
  "er": {
    "useMaxWidth": false
  },
  "sequence": {
    "useMaxWidth": false,
    "boxMargin": 10,
    "noteMargin": 10,
    "messageMargin": 35
  },
  "gantt": {
    "useMaxWidth": false
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

    # Try to run mmdc with better configuration for readability
    mmdc_output=$(mmdc -i "/tmp/mermaid_${imgfile}.mmd" -o "$mermaid_img_dir/${imgfile}.svg" \
      --puppeteerConfigFile "$puppeteer_config_file" \
      --configFile "$mermaid_config_file" \
      --scale 2 \
      --width 1600 \
      --height 1200 \
      --backgroundColor white 2>&1)
    mmdc_exit_code=$?

    # If that fails, try with simpler configuration
    if [ $mmdc_exit_code -ne 0 ] || [ ! -f "$mermaid_img_dir/${imgfile}.svg" ]; then
      info "Retrying mmdc with simpler configuration..."
      mmdc_output=$(mmdc -i "/tmp/mermaid_${imgfile}.mmd" -o "$mermaid_img_dir/${imgfile}.svg" \
        --scale 1.5 \
        --backgroundColor white 2>&1)
      mmdc_exit_code=$?

      # If that still fails, try basic configuration as last resort
      if [ $mmdc_exit_code -ne 0 ] || [ ! -f "$mermaid_img_dir/${imgfile}.svg" ]; then
        info "Final attempt with basic mmdc configuration..."
        mmdc_output=$(mmdc -i "/tmp/mermaid_${imgfile}.mmd" -o "$mermaid_img_dir/${imgfile}.svg" 2>&1)
        mmdc_exit_code=$?
      fi
    }

    if [ $mmdc_exit_code -eq 0 ] && [ -f "$mermaid_img_dir/${imgfile}.svg" ]; then
      info "Successfully rendered mermaid diagram: $imgfile"
      # Debug: Check if SVG contains text elements and show sample text
      text_count=$(grep -c "<text" "$mermaid_img_dir/${imgfile}.svg" || echo "0")
      info "Debug: SVG contains $text_count text elements"

      # Enhance SVG for better visibility in PDF
      sed -i 's/<text /<text font-family="Arial, sans-serif" font-weight="bold" /g' "$mermaid_img_dir/${imgfile}.svg"

      # Increase text size for better readability
      sed -i 's/font-size="[0-9.]*"/font-size="16"/g' "$mermaid_img_dir/${imgfile}.svg"

      # Fix text color for better contrast
      sed -i 's/fill="#[0-9a-fA-F]*"/fill="#333333"/g' "$mermaid_img_dir/${imgfile}.svg"

      if [ "$text_count" -gt 0 ]; then
        sample_text=$(grep -o "<text[^>]*>[^<]*</text>" "$mermaid_img_dir/${imgfile}.svg" | head -3 | sed 's/<[^>]*>//g' | tr '\n' ' ')
        info "Debug: Sample text content: $sample_text"
      else
        warning "Warning: SVG file contains no text elements, text may not be visible"
        # Show a bit of the SVG structure for debugging
        info "Debug: SVG structure preview:"
        head -20 "$mermaid_img_dir/${imgfile}.svg" | grep -E "<(g|rect|path|circle|text)"

        # Try to fix SVG with no visible text (may be hidden in nested elements)
        info "Attempting to fix SVG with no visible text"
        sed -i 's/<g /<g font-family="Arial, sans-serif" font-size="16" fill="#333333" /g' "$mermaid_img_dir/${imgfile}.svg"
      fi

      # Convert SVG to PNG to ensure text is preserved in PDF
      info "Converting SVG to PNG for better PDF compatibility..."

      # Try Chromium-based conversion first (most reliable for text)
      png_success=false

      # Method 1: Use Chromium to render SVG directly to PNG
      info "Attempting PNG conversion with Chromium..."

      # Create a minimal HTML wrapper for the SVG
      html_file="/tmp/mermaid_${imgfile}.html"
      cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: white;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .container {
      padding: 0;
      margin: 0;
      display: inline-block;
    }
    svg {
      display: block;
      width: 100%;
      height: auto;
      min-width: 800px;
      font-family: Arial, sans-serif;
      font-size: 14px;
    }
    /* Improve text visibility */
    svg text {
      font-family: Arial, sans-serif !important;
      font-size: 14px !important;
      fill: #333 !important;
    }
  </style>
</head>
<body>
<div class="container">'
EOF

      # Embed the SVG content
      cat "$mermaid_img_dir/${imgfile}.svg" >> "$html_file"

      cat >> "$html_file" << 'EOF'
</div>
</body>
</html>
EOF

      # Extract SVG viewBox dimensions to set appropriate screenshot size
      viewbox=$(grep -o 'viewBox="[^"]*"' "$mermaid_img_dir/${imgfile}.svg" | sed 's/viewBox="//g' | sed 's/"//g' | head -1)
      if [ -n "$viewbox" ]; then
        # Extract width and height from viewBox - using awk to handle floating point values safely
        # The viewBox format is "x y width height", we need the width and height (3rd and 4th values)
        svg_x=$(echo "$viewbox" | awk '{print int($1)}')
        svg_y=$(echo "$viewbox" | awk '{print int($2)}')
        svg_width=$(echo "$viewbox" | awk '{print int($3)}')
        svg_height=$(echo "$viewbox" | awk '{print int($4)}')

        # Make sure we got numeric values
        if echo "$svg_width" | grep -qE '^[0-9]+$' && echo "$svg_height" | grep -qE '^[0-9]+$'; then
          # Verify dimensions are reasonable
          if [ "$svg_width" -gt 0 ] && [ "$svg_height" -gt 0 ]; then
            # Scale up the diagram for better readability - use a higher multiplier (2.5x) for more visibility
            chrome_width=$((svg_width * 5 / 2))
            chrome_height=$((svg_height * 5 / 2))

            # Ensure minimum size (prevents tiny diagrams)
            if [ "$chrome_width" -lt 1200 ]; then
              chrome_width=1200
            fi
            if [ "$chrome_height" -lt 800 ]; then
              chrome_height=800
            fi

            # Update the SVG directly to ensure it scales properly
            sed -i "s/width=\"[^\"]*\"/width=\"${chrome_width}\"/" "$mermaid_img_dir/${imgfile}.svg"
            sed -i "s/height=\"[^\"]*\"/height=\"${chrome_height}\"/" "$mermaid_img_dir/${imgfile}.svg"

            # Ensure viewBox is correctly set
            sed -i "s/viewBox=\"[^\"]*\"/viewBox=\"0 0 ${chrome_width} ${chrome_height}\"/" "$mermaid_img_dir/${imgfile}.svg"

            info "Setting Chromium window size to ${chrome_width}x${chrome_height} based on SVG viewBox"
          else
            # Default values if dimensions are too small
            chrome_width=1600
            chrome_height=1200
            info "SVG dimensions too small (width=${svg_width}, height=${svg_height}), using default window size ${chrome_width}x${chrome_height}"
          fi
        else
          # Default values if dimensions are not numeric
          chrome_width=1600
          chrome_height=1200
          info "Non-numeric SVG dimensions (width=${svg_width}, height=${svg_height}), using default window size ${chrome_width}x${chrome_height}"
        fi
      else
        # Default values if viewBox extraction fails
        chrome_width=1600
        chrome_height=1200
        info "Could not extract SVG viewBox, using default window size ${chrome_width}x${chrome_height}"
      fi

      # Fix the SVG to ensure better text rendering
      # 1. Increase font size for better readability
      sed -i 's/font-size="[^"]*"/font-size="14px"/g' "$mermaid_img_dir/${imgfile}.svg"
      # 2. Ensure text has good contrast
      sed -i 's/fill="[^"]*"/fill="#333333"/g' "$mermaid_img_dir/${imgfile}.svg"

      # Use Chromium to take a screenshot with dimensions based on the SVG content
      # Adding a timeout to prevent indefinite hanging
      info "Running Chromium screenshot with timeout (30 seconds)"
      png_output=$(timeout 30 chromium --headless --disable-gpu --no-sandbox --disable-setuid-sandbox \
        --window-size=${chrome_width},${chrome_height} --hide-scrollbars \
        --screenshot="$mermaid_img_dir/${imgfile}.png" \
        --force-device-scale-factor=1 \
        "file://$html_file" 2>&1)
      png_exit_code=$?

      # Check for timeout
      if [ $png_exit_code -eq 124 ]; then
        info "Chromium screenshot timed out after 30 seconds"
        png_exit_code=1
      fi

      if [ $png_exit_code -eq 0 ] && [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
        png_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
        if [ "$png_size" -gt 5000 ]; then  # Reasonable size check
          png_success=true
          info "Successfully converted to PNG with Chromium: ${imgfile}.png (${png_size} bytes)"
        else
          info "Chromium PNG too small (${png_size} bytes), trying rsvg-convert..."
        fi
      else
        info "Chromium conversion failed: $png_output"
      fi

      # Clean up HTML file
      rm -f "$html_file"

      # Method 2: Fallback to rsvg-convert only if Chromium failed
      if [ "$png_success" = false ]; then
        info "Trying rsvg-convert as fallback..."

        # Use the same dimensions we calculated for Chromium if available
        if [ -n "$viewbox" ] && [ -n "$svg_width" ] && [ -n "$svg_height" ] &&
           echo "$svg_width" | grep -qE '^[0-9]+$' && echo "$svg_height" | grep -qE '^[0-9]+$' &&
           [ "$svg_width" -gt 0 ] && [ "$svg_height" -gt 0 ]; then
          # For rsvg-convert, use scaled dimensions (3x) with higher DPI for better quality
          rsvg_width=$((svg_width * 3))
          rsvg_height=$((svg_height * 3))
          # Ensure minimum size
          if [ "$rsvg_width" -lt 1200 ]; then
            rsvg_width=1200
          fi
          if [ "$rsvg_height" -lt 800 ]; then
            rsvg_height=800
          fi

          info "Using scaled SVG dimensions for rsvg-convert: ${rsvg_width}x${rsvg_height}"
          # Use higher DPI (600) for much better text clarity
          png_output=$(rsvg-convert --format=png --keep-aspect-ratio \
            --width="$rsvg_width" --height="$rsvg_height" \
            --dpi-x=600 --dpi-y=600 \
            --background-color=white \
            "$mermaid_img_dir/${imgfile}.svg" -o "$mermaid_img_dir/${imgfile}.png" 2>&1)
        else
          # Default values if dimensions aren't available or invalid
          info "Using default dimensions for rsvg-convert"
          png_output=$(rsvg-convert --format=png --keep-aspect-ratio \
            --width=1600 --height=1200 \
            --dpi-x=600 --dpi-y=600 \
            --background-color=white \
            "$mermaid_img_dir/${imgfile}.svg" -o "$mermaid_img_dir/${imgfile}.png" 2>&1)
        fi
        png_exit_code=$?

        # If rsvg-convert fails or produces a small file, try inkscape as a last resort if available
        if [ $png_exit_code -ne 0 ] || [ ! -f "$mermaid_img_dir/${imgfile}.png" ] || [ "$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")" -lt 5000 ]; then
          if command -v inkscape >/dev/null 2>&1; then
            info "Trying Inkscape as a last resort..."
            png_output=$(inkscape --export-filename="$mermaid_img_dir/${imgfile}.png" \
              --export-dpi=300 --export-background=white \
              "$mermaid_img_dir/${imgfile}.svg" 2>&1)
            png_exit_code=$?
          fi
        fi

        if [ $png_exit_code -eq 0 ] && [ -f "$mermaid_img_dir/${imgfile}.png" ]; then
          png_size=$(stat -c '%s' "$mermaid_img_dir/${imgfile}.png" 2>/dev/null || echo "0")
          if [ "$png_size" -gt 1000 ]; then
            png_success=true
            info "Successfully converted to PNG with rsvg-convert: ${imgfile}.png (${png_size} bytes)"
          fi
        fi
      fi

      if [ "$png_success" = true ]; then
        # Update the markdown to use PNG instead of SVG for better PDF text rendering
        sed -i "s|${imgfile}\.svg|${imgfile}.png|g" "${mdOutFile}.with_mermaid"
      else
        warning "PNG conversion failed with both methods, keeping SVG: $png_output"
        info "Note: SVG text may not render properly in final PDF"
      fi
    else
      warning "Failed to render mermaid diagram: $imgfile (exit code: $mmdc_exit_code)"
      info "mmdc output: $mmdc_output"
      # Create a placeholder text file so the image link doesn't break completely
      echo "Mermaid diagram could not be rendered" > "$mermaid_img_dir/${imgfile}.txt"
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
