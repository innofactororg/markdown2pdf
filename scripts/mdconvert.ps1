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
  ./mdconvert.ps1 -Title 'Azure Network Review' -Subtitle 'Assessment Report' -Folder 'docs/networkreport'
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [string]
  $Title,
  [Parameter(Mandatory = $true)]
  [AllowEmptyString()]
  [string]
  $Subtitle,
  [Parameter(Mandatory = $false)]
  [AllowEmptyString()]
  [string]
  $Project = '',
  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]
  $Folder = 'docs',
  [Parameter(Mandatory = $false)]
  [string]
  $Template = 'designdoc',
  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]
  $OrderFile = 'document.order',
  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]
  $OutFile = 'document.pdf',
  [Parameter(Mandatory = $false)]
  [AllowEmptyString()]
  [string]
  $DefaultAuthor = 'Innofactor',
  [Parameter(Mandatory = $false)]
  [AllowEmptyString()]
  [string]
  $DefaultDescription = 'Initial draft',
  [Parameter(Mandatory = $false)]
  [switch]
  $ForceDefault
)
try {
  $culture = New-Object System.Globalization.CultureInfo('en-US');
  $currentDate = (Get-Date).ToString('MMMM d, yyyy', $culture);
  $currentPath = Get-Item -Path .;
  $docsPath = Join-Path -Path $currentPath.FullName -ChildPath $Folder;
  $orderFilePath = $(
    if (-not(Test-Path -Path $OrderFile -PathType Leaf)) {
      Get-Item -Path $(Join-Path -Path $docsPath -ChildPath $OrderFile) -ErrorAction Stop
    } else {
      Get-Item -Path $OrderFile -ErrorAction Stop
    }
  );
  # Tex templates should be in the same folder as this script
  $templateFilePath = Get-Item -Path $(Join-Path -Path $PSScriptRoot -ChildPath "$($Template).tex") -ErrorAction Stop;
  $templateCoverFilePath = Get-Item -Path $(Join-Path -Path $PSScriptRoot -ChildPath "$($Template)-cover.png") -ErrorAction Stop;
  $templateLogoFilePath = Get-Item -Path $(Join-Path -Path $PSScriptRoot -ChildPath "$($Template)-logo.png") -ErrorAction Stop;
  # We need to get information from git log and we need to run this from root folder
  $mergeLogs = @(
    if ($ForceDefault) {
      "$DefaultAuthor|$currentDate|tag: rel/repo/1.0.0|$DefaultDescription"
    } else {
      & git --no-pager log --date-order --date=format:'%b %e, %Y' --no-merges --oneline --pretty=format:'%an|%ad|%D|%s' -- $orderFilePath.DirectoryName | Select-Object -Unique
    }
  );
  $authors = @(
    if ($ForceDefault) {
      $DefaultAuthor
    } else {
      & git --no-pager log --no-merges --oneline --pretty=format:"%an" -- $orderFilePath.DirectoryName | Select-Object -Unique
    }
  );
  # Get the markdown files in OrderFile
  $files = @(
    Get-Content -Path $orderFilePath.FullName | ForEach-Object {
      Get-Item -Path (Join-Path -Path $orderFilePath.DirectoryName -ChildPath $_) -ErrorAction Stop
    }
  );
  # Merge content of all markdown files
  $i = 0;
  $markdowncontent = $(
    foreach ($file in $files) {
      $content = Get-Content -Path $file.FullName -Raw -Encoding utf8;
      # Ensure file ends with a line feed
      if ($content -notmatch '\n$') {
        $content += "`r`n"
      };
      if ($i -eq 0) {
        $i = 1;
        $content
      } else {
        if ($content -notmatch '\r\n$') {
          "`r`n$content"
        } else {
          "`n$content"
        }
      }
    }
  );
  # Build version history
  if ($mergeLogs.Count -eq 0 -and $authors.Count -ge 1) {
    $mergeLogs = @("$($authors[0])|$currentDate|tag: rel/repo/1.0.0|$DefaultDescription")
  } elseif ($mergeLogs.Count -eq 0) {
    $mergeLogs = @("$DefaultAuthor|$currentDate|tag: rel/repo/1.0.0|$DefaultDescription")
  };
  $i = $mergeLogs.Count;
  $versionHistory = @(
    foreach ($mergeLog in $mergeLogs) {
      $items = @($mergeLog.Split('|'));
      if ($items.Count -ge 4) {
        $i--;
        $refNamesTag = @($items[2] -split 'tag:');
        $version = $(
          if ($refNamesTag.Count -eq 2 -and $refNamesTag[1] -match 'rel/') {
            @(@($refNamesTag[1] -split ',')[0] -split '/')[-1]
          } else {
            "1.0.$i"
          }
        );
        @{
          "version"     = $version;
          "date"        = $items[1].Replace('  ', ' ');
          "author"      = $items[0];
          "description" = $items[3]
        };
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
  # Build metadata content
  $metadataContent = @{
    title                           = $Title;
    subtitle                        = $Subtitle;
    project                         = $Project;
    geometry                        = 'a4paper,left=2.54cm,right=2.54cm,top=1.91cm,bottom=2.54cm';
    titlepage                       = $true;
    'titlepage-color'               = 'FFFFFF';
    'titlepage-text-color'          = '5F5F5F';
    'titlepage-top-cover-image'     = $templateCoverFilePath.FullName;
    logo                            = $templateLogoFilePath.FullName;
    colorlinks                      = $true;
    'block-headings'                = $true;
    'links-as-notes'                = $true;
    lot                             = $false;
    lof                             = $false;
    toc                             = $true;
    'toc-own-page'                  = $true;
    'toc-title'                     = 'Table of Contents';
    tables                          = $true;
    'table-use-row-colors'          = $false;
    'listings-disable-line-numbers' = $false;
    'listings-no-page-break'        = $false;
    'disable-header-and-footer'     = $false;
    'footer-center'                 = 'Page (\thepage ) of \pageref{LastPage}';
    disclaimer                      = "This document contains business and trade secrets (essential information about Innofactor's business) and is therefore totally confidential. Confidentiality does not apply to pricing information";
    'pandoc-latex-environment'      = @{
      noteblock      = '[note]';
      tipblock       = '[tip]';
      warningblock   = '[warning]';
      cautionblock   = "[caution]";
      importantblock = "[important]";
    };
    date                            = $currentDate;
    author                          = $authors;
    'version-history'               = $versionHistory;
    mainfont                        = $font
  } | ConvertTo-Json;
  $metadataFile = Join-Path -Path $docsPath -ChildPath 'metadata.json';
  Set-Content -Path $metadataFile -Value $metadataContent -Force -Encoding utf8;
  # Ensure outfile has full path
  if (-not($OutFile -match '^.?:\\.*' -or $OutFile -match '^/')) {
    $OutFile = Join-Path -Path $currentPath.FullName -ChildPath $OutFile
  };
  Write-Host -Object "Creating $OutFile";
  # We only want to use pandoc if the output file is not a markdown file
  if ($OutFile -notmatch '\.md$') {
    $markdowncontent | & pandoc `
      --standalone `
      --listings `
      --pdf-engine=xelatex `
      --metadata-file="$metadataFile" `
      -f markdown+backtick_code_blocks+pipe_tables+auto_identifiers+yaml_metadata_block+table_captions+footnotes+smart+escaped_line_breaks `
      --template="$($templateFilePath.FullName)" `
      --filter pandoc-latex-environment `
      --output="$OutFile";
    if (-not(Test-Path -Path $OutFile -PathType Leaf)) {
      Write-Warning -Message "Unable to create $OutFile"
    } else {
      $file = Get-Item -Path $OutFile;
      Write-Host -Object "Done creating $($file.FullName) at $($file.CreationTime), size is $([math]::Ceiling($file.Length / 1kb)) kb using metadata:";
      Write-Host -Object $metadataContent
    };
  } else {
    Set-Content -Path $OutFile -Value $markdowncontent -Force -NoNewline -Encoding utf8
  }
} catch {
  throw
}
