# Markdown to PDF converter

This reusable workflow can be used to publish PDF from Markdown using a predefined latex template.

It use the following logic:

1. Get version history:
   1. If a **HistoryFile** exist; use the content of that file.
   1. Or, if **ForceDefault** is set to `true`; use the value of **DefaultAuthor** and **DefaultDescription**.
   1. Or, use git commit history. Limit the number of items to the value of **LimitVersionHistory**.
1. Merge the markdown files listed in the OrderFile to one markdown file.
1. If a **ReplaceFile** exist; replace in the markdown each string that match the key from **ReplaceFile**, with the matching value.
1. Build and display metadata for the pandoc converter.
1. Convert the markdown using pandoc and save it as an artifact to the job.

The markdown can include admonition blocks for text that need special attention.

The following blocks are supported: warning, important, note, caution, tip

Example:

```markdown
# A title

This is some regular text.

::: tip
This text is in a tip admonition block.
:::
```

## Issues

The following are known issues:

- Markdown table columns can overlap in the PDF if the table is to wide, making text unreadable. To work around this:
  - limit the text in the table. Typically it should be less than 80 characters wide.
  - split the table up.
  - use an ordered or unordered list.
- The template is designed for a standing A4 layout. It has no option to flip page orientation for one or several pages in a document.
- Titles are not automatically numbered. Titles can be manually numbered and maintained in the markdown document. To avoid having to manually update all titles, it is best to not use numbered titles if possible.
- Because the template is based on latex, backslash has a special meaning and can therefore cause an error from pandoc.

## Usage

```yaml
name: 🧳 Convert Markdown
on:
  workflow_dispatch:
  pull_request:
    types: [opened, synchronize]
    branches: [main]
    paths:
      - 'docs/design/*.md'
      - 'docs/design/*.order'

jobs:
  pdf:
    name: Build PDF
    uses: innofactororg/markdown2pdf/.github/workflows/convert-markdown.yml@v2
    secrets: inherit
    with:
      # The document title
      # Default: Innofactor
      Title: Design

      # The document subtitle
      # Default: DESIGN DOCUMENT
      Subtitle: Document

      # The project ID or name
      # Default: ''
      Project: 12345678

      # The repository folder where markdown files exist
      # Default: docs
      Folder: docs/design

      # The template name. Must be: designdoc
      # Default: designdoc
      Template: designdoc

      # The name of the .order file that specify what order the markdown files must be in the converted PDF
      # This is a text file with the name of each markdown file, one for each line, in the correct order
      #
      # Example content for a document.order file:
      # summary.md
      # details.md
      # faq.md
      #
      # Default: document.order
      OrderFile: document.order

      # The name of the change file that specify the version history content
      # The file must contain the following structure:
      # Version|Date|Author|Description
      #
      # Example content for a history.txt file:
      # 1|Oct 26, 2023|Jane Doe|Initial draft
      # 2|Oct 28, 2023|John Doe|Added detailed design
      #
      # Default:
      HistoryFile: history.txt

      # The name of the replace file that has a JSON structure with a object of
      # key and value strings that will be replaced in the markdown file before conversion
      #
      # Example content for a replace.json file:
      # {
      #   "{data center name}": "WE1",
      #   "{organization name}": "contoso"
      # }
      #
      # Default:
      ReplaceFile: replace.json

      # The name of the output file that will be uploaded to the job artifacts
      # Default: document.pdf
      OutFile: Design.pdf

      # The default value to use for author of the PDF content. When specified, this value will be used if authors can't be retrieved from the git commits
      # Default: Innofactor
      DefaultAuthor: Innofactor

      # The description of the first line of document change history. When specified, this value will be used when no git comment can be retrieved from the git commits
      # Default: Initial draft
      DefaultDescription: Initial draft

      # Limit the version history table to this number of entries
      # Default: 15
      LimitVersionHistory: 15

      # Force to use the DefaultAuthor and DefaultDescription instead of using information for git commits
      # Default: false
      ForceDefault: false

      # Number of days to retains the output PDF file in the job artifacts.
      # Default: 5 days
      RetentionDays: 5
```
