#!/usr/bin/env sh
set -Eeuo pipefail
trap 'error_handler $LINENO "$SCRIPT_COMMAND" $?' ERR 1 2 3 6
trap cleanup EXIT
error_handler() {
  error $1 "${2}" $3
}
cleanup() {
  if [ -f "$DocsPath/metadata.json" ]; then
    rm -f -- "$DocsPath/metadata.json"
  fi
}
error() {
  local line="$1"
  local message="$2"
  if [ $# -gt 2 ]; then
    local code=$3
  else
    local code=-1
  fi
  local line_message=""
  if [ "$line" != "" ]; then
    line_message=" on or near line ${line}"
  fi
  if [[ -n "$message" ]]; then
    message="${message} (exit code ${code})"
  else
    message="Unspecified (exit code ${code})"
  fi
  command printf '\033[1;31mError%s\033[0m: %s\n' "${line_message}" "${message}" 1>&2
  exit ${code}
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
  if [ $# -lt 4 ] || [ -z "${4}" ] || echo "${4}" | grep -Eq '^-.*'; then
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
  local value=$(echo ${1} | awk '{ print tolower($0) }')
  if [ -z "${value}" ]; then
    echo "${default}"
  elif [ "${value}" = 'true' ] || [ "${value}" = 'yes' ] || [ "${value}" == '1' ]; then
    echo 'true'
  elif [ "${value}" = 'false' ] || [ "${value}" = 'no' ] || [ "${value}" == '0' ]; then
    echo 'false'
  else
    echo "${default}"
  fi
}
get_file_path() {
  if [ -z "${1}" ]; then
    echo ''
  elif [ -e ${1} ]; then
    echo $(readlink -f "${1}")
  elif [ -e ${2}/${1} ]; then
    echo $(readlink -f ${2}/${1})
  else
    echo ''
  fi
}
get_version_history() {
  if [ -n "${historyFilePath}" ]; then
    if ! [ -f "${historyFilePath}" ]; then
      error '' "Unable to find history file ${historyFilePath}" 1
    fi
    mergeLogs=$(cat -- ${historyFilePath})
  elif [ "${SkipGitCommitHistory}" = 'true' ]; then
    mergeLogs=$(echo "tag: rel/repo/1.0.0|$currentDate|$MainAuthor|$FirstChangeDescription")
  else
    mergeLogs=$(git --no-pager log -$GitLogLimit --date-order --date=format:'%b %e, %Y' --no-merges --oneline --pretty=format:'%D|%ad|%an|%s' -- $DocsPath)
  fi
  if [ -z "$mergeLogs" ]; then
    mergeLogs=$(echo "tag: rel/repo/1.0.0|$currentDate|$MainAuthor|$FirstChangeDescription")
  fi
  lineCount=$(echo "$mergeLogs" | wc -l)
  historyJson='[]'
  while IFS= read -r line; do
    lineCount=$((lineCount-1))
    version="$(echo "$line" | cut -d'|' -f1 | rev | cut -d'/' -f1 | rev)"
    if [ -z "$version" ] || ! echo $version | grep -Eq '^[0-9].*'; then
      version="1.0.$lineCount"
    fi
    date="$(echo "$line" | cut -d'|' -f2)"
    author="$(echo "$line" | cut -d'|' -f3)"
    description="$(echo "$line" | cut -d'|' -f4)"
    historyJson=$(echo "$historyJson" | jq --arg version "$version" \
      --arg date "$date" \
      --arg author "$author" \
      --arg description "$description" \
      '. +=[{ version: $version, date: $date, author: $author, description: $description }]')
  done < <(echo "$mergeLogs")
  echo "$historyJson"
}
process_params() {
  while [ $# -gt 0 ]
  do
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
SCRIPT_COMMAND="$@"
process_params "$@"
if [ -z "${Title}" ]; then
  error '' 'Missing Title: Value not set for argument --title' 1
fi
currentDate=$(date "+%B %d, %Y")
currentPath=$(pwd)
# Ensure OutFile has full path
if ! echo "$OutFile" | grep -Eq '^[a-zA-Z]:\\.*' && ! echo "$OutFile" | grep -Eq '^/.*'; then
  OutFile="${currentPath}/${OutFile}"
fi
if ! echo "$DocsPath" | grep -Eq '^[a-zA-Z]:\\.*' && ! echo "$DocsPath" | grep -Eq '^/.*'; then
  DocsPath="${currentPath}/${DocsPath}"
fi
if ! [ -d "${DocsPath}" ]; then
  error '' "Unable to find folder ${DocsPath}" 1
fi
scriptPath=$(dirname -- $(readlink -f "$0"))
# Get path to docs files in the same folder as the docs
historyFilePath=$(get_file_path "$HistoryFile" $DocsPath)
orderFilePath=$(get_file_path "$OrderFile" $DocsPath)
if ! [ -f "${orderFilePath}" ]; then
  error '' "Unable to find order file ${orderFilePath}" 1
fi
replaceFilePath=$(get_file_path "$ReplaceFile" $DocsPath)
# Get path to template files in the same folder as the script
templateFilePath=$(get_file_path "${Template}.tex" $scriptPath)
if ! [ -f "${templateFilePath}" ]; then
  error '' "Unable to find template file ${templateFilePath}" 1
fi
templateCoverFilePath=$(get_file_path "${Template}-cover.png" $scriptPath)
if ! [ -f "${templateCoverFilePath}" ]; then
  error '' "Unable to find template cover file ${templateCoverFilePath}" 1
fi
templateLogoFilePath=$(get_file_path "${Template}-logo.png" $scriptPath)
if ! [ -f "${templateLogoFilePath}" ]; then
  error '' "Unable to find template logo file ${templateLogoFilePath}" 1
fi
info 'Get version history'
versionHistory=$(get_version_history)
info 'Merge markdown files'
files=$(
  cat -- ${orderFilePath} | while read line; do
    if test -n "${line}"; then
      if ! [ -f "${DocsPath}/${line}" ]; then
        error '' "Unable to find markdown file ${DocsPath}/${line}" 1
      fi
      mdfile=$(readlink -f -- "${DocsPath}/${line}")
      mdpath=$(dirname -- $mdfile)
      sed -i -e "s|\(\[.*\](\)\(.*)\)|\1${mdpath}/\2|g" $mdfile
      echo "${mdfile}"
    fi
  done
)
markdownContent=$(awk 'FNR==1 && NR > 1{print ""}1' $files)
if [ -n "${ReplaceFile}" ]; then
  if ! [ -f "${replaceFilePath}" ]; then
    error '' "Unable to find replace file ${replaceFilePath}" 1
  fi
  info 'Perform replace in markdown'
  while IFS=$'\t' read -r key value; do
    markdownContent=$(echo "${markdownContent}" | sed -e "s/${key}/${value}/g")
  done < <(jq -r 'to_entries[] | [.key, .value] | @tsv' $replaceFilePath)
fi
authors=$(echo "${versionHistory}" | jq '.[].author' | uniq | sed ':a; N; $!ba; s/\n/,/g')
IFS= read -r -d '' metadataContent <<META_DATA || true
{
  "author": [
    $authors
  ],
  "block-headings": true,
  "colorlinks": true,
  "date": "${currentDate}",
  "disable-header-and-footer": false,
  "disclaimer": "This document contains business and trade secrets (essential information about Innofactor's business) and is therefore totally confidential. Confidentiality does not apply to pricing information",
  "footer-center": "Page (\\\thepage ) of \\\pageref{LastPage}",
  "geometry":"a4paper,left=2.54cm,right=2.54cm,top=1.91cm,bottom=2.54cm",
  "links-as-notes": true,
  "listings-disable-line-numbers": false,
  "listings-no-page-break": false,
  "lof": false,
  "logo": "${templateLogoFilePath}",
  "lot": false,
  "mainfont": "Carlito",
  "pandoc-latex-environment": {
    "warningblock": ["warning"],
    "importantblock": ["important"],
    "noteblock": ["note"],
    "cautionblock": ["caution"],
    "tipblock": ["tip"]
  },
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
  "version-history": $versionHistory
}
META_DATA
echo "${metadataContent}" | jq '.' > "${DocsPath}/metadata.json"
echo "${markdownContent}" > "${OutFile}.md"
info "Create ${OutFile} using metadata:"
echo "${metadataContent}" | jq '.'
if ! echo "${OutFile}" | grep -Eq '\.md$'; then
  # We need to be in the docs path so image paths can be relative
  cd $DocsPath
  echo "${markdownContent}" | pandoc \
    --standalone \
    --listings \
    --pdf-engine=xelatex \
    --metadata-file="${DocsPath}/metadata.json" \
    -f markdown+backtick_code_blocks+pipe_tables+auto_identifiers+yaml_metadata_block+table_captions+footnotes+smart+escaped_line_breaks \
    --template="${templateFilePath}" \
    --filter pandoc-latex-environment \
    --output="${OutFile}"
  cd $currentPath
else
  echo "${markdownContent}" > "${OutFile}"
fi
if [ ! -f $OutFile ]; then
  warning "Unable to create ${OutFile}"
else
  size=$(expr $(stat -c '%s' $OutFile) / 1000)
  info "Created ${OutFile} using ${size} KB"
fi
