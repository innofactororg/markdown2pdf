# Markdown to PDF converter

This reusable workflow can be used to publish PDF from Markdown using a predefined latex template.

It use the following logic:

1. Get version history:
   1. If a **HistoryFile** exist; use the content of that file.
   1. Or, if **SkipGitCommitHistory** is set to `true` or a commit history don't exist; use the value of **MainAuthor** and **FirstChangeDescription**.
   1. Or, use git commit history. Limit the number of items to the value of **GitLogLimit**.
1. Merge the markdown files listed in the OrderFile to one markdown file.
1. Replace markdown links that have relative path with absolute path.
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

- Relative paths should start with `./` to ensure it can be replaced with absolute path before converting it to PDF.
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
      - "docs/design/*.md"
      - "docs/design/*.order"

jobs:
  pdf:
    name: Build PDF
    uses: innofactororg/markdown2pdf/.github/workflows/convert-markdown.yml@v3beta1
    secrets: inherit
    with:
      # The first change description.
      #
      # This value will be used if a HistoryFile
      # is not specified and a git commit comment
      # is not available.
      #
      # Default: Initial draft
      FirstChangeDescription: Initial draft

      # The repository folder where the order file exist.
      # Default: docs
      Folder: docs/design

      # Maximum entries to get from Git Log for version history.
      # Default: 15
      GitLogLimit: 15

      # The name of the history file.
      #
      # This is a file with the version history content.
      #
      # The file must contain the following structure:
      # Version|Date|Author|Description
      #
      # Example content for a history.txt file:
      # 1|Oct 26, 2023|Jane Doe|Initial draft
      # 2|Oct 28, 2023|John Doe|Added detailed design
      #
      # Default: ''
      HistoryFile: history.txt

      # The main author of the PDF content.
      #
      # This value will be used if a HistoryFile
      # is not specified and author can't be retrieved
      # from git commits.
      #
      # Default: Innofactor
      MainAuthor: Innofactor

      # The name of the .order file.
      #
      # This is a text file with the name of each markdown file,
      # one for each line, in the correct order.
      #
      # Example content for a document.order file:
      # summary.md
      # details.md
      # faq.md
      #
      # Default: document.order
      OrderFile: document.order

      # The name of the output file.
      #
      # This file will be uploaded to the job artifacts.
      #
      # Default: document.pdf
      OutFile: Design.pdf

      # The project ID or name.
      # Default: ''
      Project: 12345678

      # Skip using git commit history.
      #
      # When set to true, the change history will not be
      # retrieved from the git commit log.
      #
      # Default: false
      SkipGitCommitHistory: false

      # The document subtitle.
      # Default: ''
      Subtitle: DESIGN DOCUMENT

      # The template name. Must be: designdoc.
      # Default: designdoc
      Template: designdoc

      # The document title.
      # Required
      Title: Design

      # The name of the replace file.
      #
      # This is a JSON file with key and value strings.
      # Each key will be searched for in the markdown files and
      # replaced with the value before conversion to PDF.
      #
      # Example content for a replace.json file:
      # {
      #   "{data center name}": "WE1",
      #   "{organization name}": "contoso"
      # }
      #
      # Default:
      ReplaceFile: replace.json

      # Number of days to retain job artifacts.
      # Default: 5 days
      RetentionDays: 5
```

## License

The code and documentation in this project are released under the [BSD 3-Clause License](LICENSE).
