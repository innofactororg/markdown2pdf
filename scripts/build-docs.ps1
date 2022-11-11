<#
.SYNOPSIS
  Build PDF document from markdown files based on order file.
.NOTES
  To use this script on windows, install the following:
  - https://miktex.org/download
    - Select Always for the option Install missing packages on the fly
    - After install, open MiKTex Console and Check for updates.
      If MiKTex was installed for all users you must
      start MiKTex Console with run as administrator
  - https://www.python.org/downloads/windows/
  - python -m pip install --upgrade pip
  - pip install pandoc-latex-environment

  Using modified latex template from https://github.com/Wandmalfarbe/pandoc-latex-template
.EXAMPLE
  ./docs/build.ps1 -OrderFile markdown/design-document.order -MetadataFile markdown/design-document.yaml -Template templates/design-document.tex -OutFile design-document.pdf
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]
  $OrderFile,
  [Parameter(Mandatory = $true)]
  [string]
  $MetadataFile,
  [Parameter(Mandatory = $true)]
  [string]
  $Template,
  [Parameter(Mandatory = $true)]
  [string]
  $OutFile,
  [Parameter(Mandatory = $false)]
  [string]
  $DocsRootFolder = 'docs'
)
$currentPath = Get-Item -Path .;
$docsFullPath = Join-Path -Path $currentPath.FullName -ChildPath $DocsRootFolder;
# We need to get information from git log and we need to run this from root folder
$mergeLogs = @(& git --no-pager log --date-order --date=format:'%B %e, %Y' --first-parent --pretty=format:'%an|%ad|%D|%s' -- $docsFullPath);
$authors = @(& git --no-pager log --pretty=format:"%an" -- $docsFullPath | Select-Object -Unique);
# This script is copied to the folder where the documentation exist, typically the docs folder in the root of the repository
# We set location to the docs folder and work from there
Push-Location;
Set-Location -Path $PSScriptRoot;
if (-not(Test-Path -Path $OrderFile -PathType Leaf)) {
  throw "Unable to find $OrderFile"
};
$docPath = Get-Item -Path $OrderFile | Select-Object -ExpandProperty DirectoryName;
# Get the markdown files in OrderFile
$files = @(
  Get-Content -Path $OrderFile | ForEach-Object {
    Get-Item -Path (Join-Path -Path $docPath -ChildPath $_) -ErrorAction Stop
  }
);
$i = 0;
$markdowncontent = $(
  foreach ($file in $files) {
    $i++;
    $content = Get-Content -Path $file.FullName -Raw -Encoding utf8;
    # Require that the file begins with a first level title
    # Turning this off for now, want to use sub pages
    # if ($content -notmatch '^#\s\w') {
    #   throw "The file $($file.Name) is not valid, it must begin with a first level title"
    # };
    # Require that the file ends with a line feed
    if ($content -notmatch '\n$') {
      throw "The file $($file.Name) is not valid, it must end with a line feed (empty line)"
    };
    if ($i -ne 1) {
      if ($content -notmatch '\r\n$') {
        "`r`n$content"
      } else {
        "`n$content"
      }
    } else {
      $content
    }
  }
);
$MetadataFileItem = Get-Item -Path $MetadataFile;
$MetadataFile = $MetadataFileItem | Select-Object -ExpandProperty FullName;
$metadataExtraFile = Join-Path -Path $($MetadataFileItem | Select-Object -ExpandProperty DirectoryName) -ChildPath 'latest-release-info.json';
$Template = Get-Item -Path $Template | Select-Object -ExpandProperty FullName;
if (-not($OutFile -match '\\' -or $OutFile -match '/')) {
  $OutFile = Join-Path -Path $currentPath.FullName -ChildPath $OutFile
};
Write-Host -Object "Creating $OutFile";
Set-Location -Path $docPath;
$culture = New-Object System.Globalization.CultureInfo('en-US');
$currentDate = (Get-Date).ToString('MMMM d, yyyy', $culture);
if ($mergeLogs.Count -eq 0 -and $authors.Count -ge 1) {
  $mergeLogs = @("$($authors[0])|$currentDate|tag: rel/repo/1.0.0|Initial draft")
} elseif ($mergeLogs.Count -eq 0) {
  # $mergeLogs = @("Innofactor|$currentDate|tag: rel/repo/1.0.0|Initial draft")
  $mergeLogs = @("Aidan Finn|$currentDate|tag: rel/repo/1.0.0|Low Level Design")
};
$versionHistory = @(
  foreach ($mergeLog in $mergeLogs) {
    $items = @($mergeLog.Split('|'));
    $refNamesTag = @($items[2] -split 'tag:');
    $version = $(
      if ($refNamesTag.Count -eq 2 -and $refNamesTag[1] -match 'rel/') {
        @(@($refNamesTag[1] -split ',')[0] -split '/')[-1]
      } else {
        '1.0.0'
      }
    );
    if ($items.Count -ge 4) {
      @{
        "version"     = $version;
        "date"        = $items[1].Replace('  ', ' ');
        "author"      = $items[0];
        "description" = $items[3]
      }
    }
  }
);
$font = $(
  if ($IsLinux) {
    'Carlito'
  } else {
    'Calibri'
  }
);
$metadataContent = @{
  "date"            = $currentDate;
  "author"          = $authors;
  "version-history" = $versionHistory;
  "mainfont"        = $font
} | ConvertTo-Json;
Set-Content -Path $metadataExtraFile -Value $metadataContent -Force -Encoding utf8;
# We only want to use pandoc if the output file is not a markdown file
if ($OutFile -notmatch '\.md$') {
  $markdowncontent | & pandoc `
    --standalone `
    --listings `
    --pdf-engine=xelatex `
    --metadata-file="$MetadataFile" `
    --metadata-file="$metadataExtraFile" `
    -f markdown+backtick_code_blocks+pipe_tables+auto_identifiers+yaml_metadata_block+table_captions+footnotes+smart+escaped_line_breaks `
    --template="$Template" `
    --filter pandoc-latex-environment `
    --output="$OutFile";
  if (-not(Test-Path -Path $OutFile -PathType Leaf)) {
    Write-Warning -Message "Unable to create $OutFile"
  } else {
    $file = Get-Item -Path $OutFile;
    Write-Host -Object "Done creating $($file.FullName) at $($file.CreationTime), size is $([math]::Ceiling($file.Length / 1kb)) kb"
  };
  Pop-Location
} else {
  Set-Content -Path $OutFile -Value $markdowncontent -Force -NoNewline -Encoding utf8
}