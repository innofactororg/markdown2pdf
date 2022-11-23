#!/bin/sh -l
time=$(date)
echo "Title: $1"
echo "Subtitle: $2"
echo "OrderFile: $3"
echo "MetadataFile: $4"
echo "Template: $5"
echo "OutFile: $6"
echo "DocsRootFolder: $7"
echo "DefaultAuthor: $8"
echo "DefaultDescription: $9"
echo "ForceDefault: ${10}"
echo "BuildBranch: ${11}"
echo "time=$time" >> $GITHUB_OUTPUT
