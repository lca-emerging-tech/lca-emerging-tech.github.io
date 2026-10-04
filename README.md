# LCA of Emerging Technologies Working Group website

Source for the working group's website, built with [Quarto](https://quarto.org) and published on GitHub Pages. Every push to `main` rebuilds and republishes the site automatically.

## Publish it for the first time (about 15 minutes, once)

1. **Create a GitHub organization** for the group, for example `lca-emerging-tech` (github.com, your profile menu, Organizations, New organization, free plan). Add two or three admins so the site does not depend on one person.
2. **Create a repository** in that organization named `website`, and upload all files from this folder, keeping the folder structure, including the hidden `.github` folder.
3. **Turn on Pages:** repository Settings, Pages, under "Build and deployment" set Source to **GitHub Actions**.
4. **Run it:** open the Actions tab. The "Publish site" workflow runs on every push; you can also start it by hand with "Run workflow". After 2 to 3 minutes the site is live at `https://lca-emerging-tech.github.io/website/`.
5. If you chose different organization or repository names, update `site-url` and `repo-url` at the top of `_quarto.yml`.

## Before publishing, fill in the TODOs

Search the files for `TODO`:

- [ ] `get-involved.qmd`: add the contact form link (a Google Form works well)
- [ ] `projects/*.qmd`: confirm leads' names and affiliations (each lead should agree to be listed)
- [ ] `publications.qmd`: add citations and DOIs for the two Journal of Industrial Ecology papers

## Everyday editing (no installation needed)

1. Open the file on GitHub and click the pencil icon.
2. Edit the text. Files are plain Markdown: `## Heading`, `**bold**`, `- bullet`, `[link text](page.qmd)`.
3. Click "Commit changes". The site updates by itself within a few minutes.

Every page also has an "Edit this page" link at the bottom that opens the right file.

## Posting an update after a meeting

1. In the `updates` folder, copy an existing post and rename it `YYYY-MM-DD-short-title.qmd`.
2. Change the `title`, `date`, `description`, and `categories` at the top, then write a few short bullets.
3. Commit. The post appears on the Updates page, on the home page under "What's new", and in the RSS feed.

## Keeping it current

- Update the `date-modified` line at the top of any page you change. That date is shown to readers.
- Guidance pages carry a version and a "next review by" date. Review them quarterly.
- To keep a page private while drafting, add `draft: true` to its top block. Drafts are not published.
- Suggested routine: in the last five minutes of each biweekly meeting, agree what goes into that meeting's update post and who writes it.

## Owners (fill in)

| Page | Owner |
|---|---|
| Updates feed | |
| Tiers of LCA | |
| AI for LCA of emerging technologies, guidance pages | |
| Design flexibility across TRL | |

## Preview locally (optional, for technical members)

Install Quarto, then run `quarto preview` in this folder.
