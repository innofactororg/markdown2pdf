<#
.SYNOPSIS
  Build PDF document from markdown files based on order file.
.NOTES
  To use this script on windows, install the following (to update with winget replace install with upgrade):
  - winget install --id JohnMacFarlane.Pandoc
  - winget install --id MiKTeX.MiKTeX
    - Select Always for the option Install missing packages on the fly
    - After install, open MiKTeX Console and Check for updates.
      If MiKTeX was installed for all users you must
      start MiKTeX Console with run as administrator
  - winget install --id Python.Python.3.11
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
  $DocsRootFolder = 'docs',
  [Parameter(Mandatory = $false)]
  [string]
  $DefaultAuthor = 'Innofactor',
  [Parameter(Mandatory = $false)]
  [string]
  $DefaultDescription = 'Initial draft',
  [Parameter(Mandatory = $false)]
  [switch]
  $ForceDefault
)
$currentPath = Get-Item -Path .;
$docsRootPath = Join-Path -Path $currentPath.FullName -ChildPath $DocsRootFolder;
$orderFilePath = $(
  if (-not(Test-Path -Path $OrderFile -PathType Leaf)) {
    Get-Item -Path $(Join-Path -Path $docsRootPath -ChildPath $OrderFile)
  } else {
    Get-Item -Path $OrderFile
  }
);
$metadataFilePath = $(
  if (-not(Test-Path -Path $MetadataFile -PathType Leaf)) {
    Get-Item -Path $(Join-Path -Path $docsRootPath -ChildPath $MetadataFile)
  } else {
    Get-Item -Path $MetadataFile
  }
);
$templateFilePath = $(
  if (-not(Test-Path -Path $Template -PathType Leaf)) {
    Get-Item -Path $(Join-Path -Path $docsRootPath -ChildPath $Template)
  } else {
    Get-Item -Path $Template
  }
);
# We need to get information from git log and we need to run this from root folder
$mergeLogs = @(
  if (-not($ForceDefault)) {
    & git --no-pager log --date-order --date=format:'%B %e, %Y' --first-parent --no-merges --pretty=format:'%an|%ad|%D|%s' -- $orderFilePath.DirectoryName
  }
);
$authors = @(
  if (-not($ForceDefault)) {
    & git --no-pager log --pretty=format:"%an" -- $orderFilePath.DirectoryName | Select-Object -Unique
  }
);
# This script is copied to the folder where the documentation exist, typically the docs folder in the root of the repository
# We set location to the docs folder and work from there
Push-Location;
Set-Location -Path $PSScriptRoot;
# Get the markdown files in OrderFile
$files = @(
  Get-Content -Path $orderFilePath.FullName | ForEach-Object {
    Get-Item -Path (Join-Path -Path $orderFilePath.DirectoryName -ChildPath $_) -ErrorAction Stop
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
$metadataExtraFile = Join-Path -Path $metadataFilePath.DirectoryName -ChildPath 'latest-release-info.json';
if (-not($OutFile -match '\\' -or $OutFile -match '/')) {
  $OutFile = Join-Path -Path $currentPath.FullName -ChildPath $OutFile
};
Write-Host -Object "Creating $OutFile";
# Set location path to a specific folder in the docs folder, e.g. docs/detaileddesign
Set-Location -Path $orderFilePath.DirectoryName;
$culture = New-Object System.Globalization.CultureInfo('en-US');
$currentDate = (Get-Date).ToString('MMMM d, yyyy', $culture);
if ($mergeLogs.Count -eq 0 -and $authors.Count -ge 1) {
  $mergeLogs = @("$($authors[0])|$currentDate|tag: rel/repo/1.0.0|$DefaultDescription")
} elseif ($mergeLogs.Count -eq 0) {
  $mergeLogs = @("$DefaultAuthor|$currentDate|tag: rel/repo/1.0.0|$DefaultDescription")
};
$i = 0;
$versionHistory = @(
  foreach ($mergeLog in $mergeLogs) {
    $items = @($mergeLog.Split('|'));
    $refNamesTag = @($items[2] -split 'tag:');
    $version = $(
      if ($refNamesTag.Count -eq 2 -and $refNamesTag[1] -match 'rel/') {
        @(@($refNamesTag[1] -split ',')[0] -split '/')[-1]
      } else {
        "1.0.$i"
      }
    );
    if ($items.Count -ge 4) {
      @{
        "version"     = $version;
        "date"        = $items[1].Replace('  ', ' ');
        "author"      = $items[0];
        "description" = $items[3]
      };
      $i++;
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
    --metadata-file="$($metadataFilePath.FullName)" `
    --metadata-file="$metadataExtraFile" `
    -f markdown+backtick_code_blocks+pipe_tables+auto_identifiers+yaml_metadata_block+table_captions+footnotes+smart+escaped_line_breaks `
    --template="$($templateFilePath.FullName)" `
    --filter pandoc-latex-environment `
    --output="$OutFile";
  if (-not(Test-Path -Path $OutFile -PathType Leaf)) {
    Write-Warning -Message "Unable to create $OutFile"
  } else {
    $file = Get-Item -Path $OutFile;
    Write-Host -Object "Done creating $($file.FullName) at $($file.CreationTime), size is $([math]::Ceiling($file.Length / 1kb)) kb. Version metadata:";
    Write-Host -Object $metadataContent
  };
  Pop-Location
} else {
  Set-Content -Path $OutFile -Value $markdowncontent -Force -NoNewline -Encoding utf8
}