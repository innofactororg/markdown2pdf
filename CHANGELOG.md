# Changelog

All notable changes to this project are documented in this file.

Each release has a `## <version> (YYYY-MM-DD)` section. The Release workflow publishes that section as the release notes and announces it in Teams, and fails if the section is missing. Add the entry in the pull request that makes the change.

## Unreleased

### Fixed

- Update the actions cache version ([#39](https://github.com/innofactororg/markdown2pdf/pull/39))

### Changed

- README and CODEOWNERS updates

## 3.0.3 (2024-04-25)

### Fixed

- Use inline `sed` for the replace logic to avoid a file system race condition ([#37](https://github.com/innofactororg/markdown2pdf/pull/37))

## 3.0.2 (2024-03-19)

### Added

- Azure DevOps pipeline sample ([#36](https://github.com/innofactororg/markdown2pdf/pull/36))
- Show debug step
- Caching
- Output for the PDF path

### Fixed

- Various shellcheck fixes

## 3.0.1 (2024-02-15)

### Fixed

- Adjust the position of the title on the first page. Long titles placed the title at the end of the page and the disclaimer on a new page.

## 3.0.0 (2024-02-14)

Converted to a composite action ([#35](https://github.com/innofactororg/markdown2pdf/pull/35)).

### Changed

- Rename input `DefaultAuthor` to `MainAuthor`
- Rename input `DefaultDescription` to `FirstChangeDescription`
- Rename input `LimitVersionHistory` to `GitLogLimit`
- Rename input `ForceDefault` to `SkipGitCommitHistory`

### Added

- Support for comment lines in order files

### Fixed

- Running the script from the markdown2pdf repo (composite action)
- The last line of an order file was ignored when the file did not end with CRLF

## 2.0.1 (2024-02-13)

### Changed

- Replace relative markdown links with the full path ([#34](https://github.com/innofactororg/markdown2pdf/pull/34))

## 2.0.0 (2024-01-16)

### Added

- Devcontainer ([#29](https://github.com/innofactororg/markdown2pdf/pull/29))

### Changed

- Update README ([#28](https://github.com/innofactororg/markdown2pdf/pull/28))
- Use the `pandoc/extra:edge-alpine` image in the workflow ([#29](https://github.com/innofactororg/markdown2pdf/pull/29))

### Fixed

- Update tlmgr before installing lastpage ([#31](https://github.com/innofactororg/markdown2pdf/pull/31))

## 1.0.0 (2023-08-09)

### Added

- Release action ([#27](https://github.com/innofactororg/markdown2pdf/pull/27))
- Allow sub pages ([#13](https://github.com/innofactororg/markdown2pdf/pull/13))
- Case variants for admonition blocks ([#24](https://github.com/innofactororg/markdown2pdf/pull/24))

### Changed

- Minor fixes of the build script and workflow ([#14](https://github.com/innofactororg/markdown2pdf/pull/14))
- Remove `--first-parent` so merge commits are included ([#17](https://github.com/innofactororg/markdown2pdf/pull/17))
- Set the location before the pandoc call, for relative paths ([#22](https://github.com/innofactororg/markdown2pdf/pull/22))

### Fixed

- Clean up after the repo rename ([#26](https://github.com/innofactororg/markdown2pdf/pull/26))
- Admonition blocks ([#23](https://github.com/innofactororg/markdown2pdf/pull/23))

## 0.1.0 (2022-09-28)

Initial beta release. A clean PDF is produced and shareable; some LaTeX bugs remain to be fixed.
