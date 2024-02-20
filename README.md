# Markdown to PDF converter

This repository includes a GitHub action and a Azure DevOps [pipeline](./.azuredevops/README.md) to publish a PDF artifact by converting Markdown files using a predefined template.

## Get started

To set up a markdown2pdf workflow, several prerequisite steps are required:

1. If needed, [create a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository).

1. If needed, add [markdown](https://www.markdownguide.org/) documentation to the repository. It is recommended to keep the markdown files in a subfolder of a **"docs"** folder, for example **"docs/hld"**.

1. Add a **"document.order"** file in the markdown folder. It is recommended to only keep one order in each markdown folder.

1. Add markdown file names to **"document.order"**, one file name for each line.

   Ensure that the file names are in the correct order. This is how they will appear in the PDF file.

   Note that lines that start with the comment sign `#` will be ignored.

1. Add a workflow file for each order file in the **".github/workflows"** folder of the repository. For example **".github/workflows/docs.hld.dns.yml"**.

1. Copy the sample workflow from [Usage](#usage) into each workflow file, customize it and commit the changes.

1. The workflows can be started manually or automatically when creating or updating a pull request.

## Workflow

The workflow converts markdown to PDF using a [script](./tools/convert.sh) and a [LaTeX template](./tools/designdoc.tex).

### Template sections

The template has the following sections:

1. A **Title page** with a [logo](./tools/designdoc-cover.png) and the document title and subtitle.

1. A **Version history page**. The content of this page is generated based on the following:

   1. If a **HistoryFile** exist; use the content of that file.
   1. Or, if **SkipGitCommitHistory** is set to `true` or a commit history don't exist; use the value of **MainAuthor** and **FirstChangeDescription**.
   1. Or, use git commit history. Limit the number of items to the value of **GitLogLimit**.

1. A **Table of Content page**.

1. **Content pages** with the converted markdown files. This content is generated based on the following:

   1. Merge the markdown files listed in the **"OrderFile"** to one markdown file.
   1. Replace markdown links that have a relative path with a absolute path.
   1. If a **ReplaceFile** exist; update the markdown file and replace each string that match the key from **ReplaceFile**, with the matching value.
   1. Build metadata for the **"pandoc"** converter.
   1. Convert the markdown using **"pandoc"** and save it as an artifact to the job.

1. **Page header** on all pages, except for the **Title page**:

   - Left side: [logo](./tools/designdoc-logo.png)
   - Center: **Project** and **Author(s)**
   - Right side: Current date.

1. **Page footer** on all pages, except for the **Title page**.

   - Center: page number and total number of pages.

### Markdown tips

The markdown can include admonition blocks for text that need special attention.

The following blocks are supported: **warning**, **important**, **note**, **caution**, **tip**.

For example:

```markdown
# A title

This is some regular text.

::: tip
This text is in a tip admonition block.
:::
```

### Issues

The following are known issues:

- Relative paths should start with `./` to ensure it can be replaced with absolute path before converting it to PDF.
- Markdown table columns can overlap in the PDF if the table is to wide, making text unreadable. To work around this:
  - limit the text in the table. Typically it should be less than 80 characters wide.
  - split the table up.
  - use an ordered or unordered list.
- The template is designed for a standing A4 layout. It has no option to flip page orientation for one or several pages in a document.
- Titles are not automatically numbered. Titles can be manually numbered and maintained in the markdown document. To avoid having to manually update all titles, it is best to not use numbered titles if possible.

### Action Inputs

#### Required

- **Title**: (Required) The document title.

#### Optional

- **FirstChangeDescription**: The first change description.

  This value will be used if a HistoryFile is not specified and a git commit comment is not available.

  Default: **"Initial draft"**

- **Folder**: The repository folder where the order file exist.

  Default: **"docs"**

- **GitLogLimit**: Maximum entries to get from Git Log for version history.

  Default: **"15"**

- **HistoryFile**: The name of a history file.

  This is a file with version history content. The file must contain the following structure:

  `Version|Date|Author|Description`

  Example content for a history.txt file:

  ```text
  1|Oct 26, 2023|Jane Doe|Initial draft
  2|Oct 28, 2023|John Doe|Added detailed design
  ```

  Default: **""**

- **MainAuthor**:

  The main author of the PDF content.

  This value will be used if a HistoryFile is not specified and author can't be retrieved from git commits.

  Default: **"Innofactor"**

- **OrderFile**: The name of the .order file.

  This is a text file with the name of each markdown file, one for each line, in the correct order.

  Example content for a document.order file:

  ```text
  summary.md
  details.md
  faq.md
  ```

  Default: **"document.order"**

- **OutFile**: The name of the output file.

  This file will be uploaded to the job artifacts.

  Default: **"document.pdf"**

- **Project**: The project ID or name. This value will be in the document header.

  Default: **""**

- **ReplaceFile**: The name of the replace file.

  This is a JSON file with key and value strings. Each key will be searched for in the markdown files and replaced with the value before conversion to PDF.

  Example content for a replace.json file:

  ```json
  {
    "{data center name}": "WE1",
    "{organization name}": "contoso"
  }
  ```

  Default: **""**

- **RetentionDays**: Number of days to retain job artifacts.

  Default: **"5"**

- **SkipGitCommitHistory**: Skip using git commit history.

  When set to **true**, the change history will not be retrieved from the git commit log.

  Default: **"false"**

- **Subtitle**: The document subtitle.

  Default: **""**

- **Template**: The template name. Must be: designdoc.

  Default: **"designdoc"**

### Usage

```yaml
name: 📝 Convert Markdown
on:
  workflow_dispatch:
  pull_request:
    types: [opened, synchronize]
    branches: [main]
    paths:
      - "docs/design/*.md"
      - "docs/design/*.order"

permissions: {}

jobs:
  pdf:
    name: Build PDF
    permissions:
      contents: read # for checkout
    runs-on: ubuntu-22.04
    container:
      image: pandoc/extra:edge-alpine
    steps:
      - name: Clone repository
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 #v4.1.1
        with:
          fetch-depth: 0

      - name: Build PDF
        uses: innofactororg/markdown2pdf@v3.0.2beta1
        with:
          FirstChangeDescription: Initial draft
          Folder: docs/design
          GitLogLimit: 15
          HistoryFile: history.txt
          MainAuthor: Innofactor
          OrderFile: document.order
          OutFile: Design.pdf
          Project: 12345678
          ReplaceFile: replace.json
          RetentionDays: 5
          SkipGitCommitHistory: false
          Subtitle: DESIGN DOCUMENT
          Title: DNS
```

## License

The code and documentation in this project are released under the [BSD 3-Clause License](./LICENSE).
