# Markdown to PDF converter

This is a Azure DevOps [pipeline](./markdown2pdf.yml) to publish a PDF artifact by converting Markdown files using a predefined template.

## Get started

To use the pipeline, several prerequisite steps are required:

1. If needed, [create a repo](https://learn.microsoft.com/en-us/azure/devops/repos/git/create-new-repo?view=azure-devops#create-a-repo-using-the-web-portal).

1. If needed, add [markdown](https://www.markdownguide.org/) documentation to the repo. It is recommended to keep the markdown files in a subfolder of a **"docs"** folder, for example **"docs/hld"**.

1. Add a **"document.order"** file in the markdown folder. It is recommended to only keep one order in each markdown folder.

1. Add markdown file names to **"document.order"**, one file name for each line.

   Ensure that the file names are in the correct order. This is how they will appear in the PDF file.

   Note that lines that start with the comment sign `#` will be ignored.

1. Add the [markdown2pdf.yml](./markdown2pdf.yml) to a repo folder with a name that represent what it converts, e.g. **".pipelines/docs.dns.design.yml"**.

1. Customize the variable values in the pipeline file and commit the changes.

1. Go to the Azure DevOps **Pipelines** page. Then choose the action to create a **New pipeline**.

1. Select **Azure Repos Git** as the location of the source code.

1. When the list of repositories appears, select the repository.

1. Select **Existing Azure Pipelines YAML file** and choose the YAML file, e.g. **"/.pipelines/docs.dns.design.yml"**.

1. Save the pipeline without running it.

1. Configure [branch policies](https://learn.microsoft.com/en-us/azure/devops/repos/git/branch-policies?view=azure-devops&tabs=browser#configure-branch-policies) for the default/main branch.

1. Add a [build validation branch policy](https://learn.microsoft.com/en-us/azure/devops/repos/git/branch-policies?view=azure-devops&tabs=browser#build-validation).

## Pipeline

The pipeline converts markdown to PDF using a [script](./../tools/convert.sh) and a [LaTeX template](./../tools/designdoc.tex).

### Template sections

The template has the following sections:

1. A **Title page** with a [cover logo](./../tools/designdoc-cover.png) and the document title and subtitle.

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

   - Left side: [logo](./../tools/designdoc-logo.png)
   - Center: **Project** and **Author(s)**
   - Right side: Current date.

1. **Page footer** on all pages, except for the **Title page**.

   - Center: page number and total number of pages.

### Markdown tips

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

### Issues

The following are known issues:

- Relative paths should start with `./` to ensure it can be replaced with absolute path before converting it to PDF.
- Markdown table columns can overlap in the PDF if the table is to wide, making text unreadable. To work around this:
  - limit the text in the table. Typically it should be less than 80 characters wide.
  - split the table up.
  - use an ordered or unordered list.
- The template is designed for a standing A4 layout. It has no option to flip page orientation for one or several pages in a document.
- Titles are not automatically numbered. Titles can be manually numbered and maintained in the markdown document. To avoid having to manually update all titles, it is best to not use numbered titles if possible.

## Variables

- **FIRST_CHANGE_DESCRIPTION**: The first change description. This value will be used if a HistoryFile is not specified and a git commit comment is not available.

- **FOLDER**: The repository folder where the order file exist.

- **GIT_LOG_LIMIT**: Maximum entries to get from Git Log for version history.

- **HISTORY_FILE**: The name of the history file. This is a file with the version history content. The file must contain the following structure:

  Version|Date|Author|Description

  Example content for a history.txt file:

  1|Oct 26, 2023|Jane Doe|Initial draft
  2|Oct 28, 2023|John Doe|Added detailed design

- **MAIN_AUTHOR**: The main author of the PDF content. This value will be used if a HistoryFile is not specified and author can't be retrieved from git commits.

- **ORDER_FILE**: The name of the .order file. This is a text file with the name of each markdown file, one for each line, in the correct order.

  Example content for a document.order file:

  summary.md
  details.md
  faq.md

- **OUT_FILE**: The name of the output file. This file will be uploaded to the job artifacts.

- **PROJECT**: The project ID or name.

- **REPLACE_FILE**: The name of the replace file. This is a JSON file with key and value strings. Each key will be searched for in the markdown files and replaced with the value before conversion to PDF.

- **SKIP_GIT_COMMIT_HISTORY**: Skip using git commit history. When set to true, the change history will not be retrieved from the git commit log.

- **SUBTITLE**: The document subtitle.

- **TITLE**: The document title.

  Example content for a replace.json file:

  ```json
  {
    "{data center name}": "WE1",
    "{organization name}": "contoso"
  }
  ```

- **WORKFLOW_VERSION**: The version of the markdown2pdf scripts to use. See <https://github.com/innofactororg/markdown2pdf/tags>.

## License

The code and documentation in this project are released under the [BSD 3-Clause License](./../LICENSE).
