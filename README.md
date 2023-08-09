# Markdown to PDF complier

This reusable workflow can be used to publish PDF from Markdown.

## Example Workflow

```yaml
name: 🧳 Convert Markdown
on:
  workflow_dispatch:
  pull_request:
    branches: [main]
    paths:
      - 'docs/design/*.md'
      - 'docs/design/*.order'
      - 'docs/design/.attachments/**'
  push:
    paths:
      - 'docs/design/*.md'
      - 'docs/design/*.order'
      - 'docs/design/.attachments/**'

jobs:
  pdf:
    name: Build PDF
    uses: innofactororg/markdown2pdf/.github/workflows/convert-markdown.yml@v1
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
      # Default: document.order
      OrderFile: document.order

      # The name of the output file that will be uploaded to the job artifacts
      # Default: document.pdf
      OutFile: Design.pdf

      # The default value to use for author of the PDF content. When specified, this value will be used if autors can't be retreived from the git commits
      # Default: Innofactor
      DefaultAuthor: Innofactor

      # The description of the first line of document change history. When specified, this value will be used when no git comment can be retreived from the git commits
      # Default: Initial draft
      DefaultDescription: Initial draft

      # Force to use the DefaultAuthor and DefaultDescription instead of using information for git commits
      # Default: false
      ForceDefault: false

      # Number of days to retains the output PDF file in the job artifacts.
      # Default: 5 days
      RetentionDays: 5
```
