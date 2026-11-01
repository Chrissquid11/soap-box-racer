---
skill: studio
title: This project's own editor tools
when: Before using a project_<name> tool, or when adding an editor tool or an MCP tool of the project's own -- each comes with its page here
covers:
  tools: []
order: 90
---
# This project's own editor tools

Besides the studio's own editors, a project may have tools of its own in `src/tools/` (`src/tools/index.ts` lists
them): a tab, a Config page, an inspector block -- and MCP tools, `mcpTools`, which Claude calls as
`project_<name>` beside the studio's. Each such tool has a page in this skill, a `<name>.skill.md` beside its code,
saying how to do a job with it. When this page is the only one from `src/tools/`, the project has none yet.

## Using one

- A project's MCP tools are page tools: they run in the open studio tab, each edit one world step `Z` undoes, and
  they wait behind the tool search -- search for `project_<name>`, or by words.
- Read its page first, then as with any tool: read the world, act, look ([working in the studio](studio.md)).

## Adding one

Every action a person has in a tool of the project's comes with its MCP tool, and every tool with its page:

1. The tool itself in `src/tools/<tool>/` -- an `EditorTool` from `@vibe/editor`, listed in `src/tools/index.ts`;
   every button, menu entry and key of it declares the MCP tool that does the same -- `button(mcp, text, title,
   run)`, `iconButton(mcp, ...)` and `control(mcp, ...)` take it as their first argument, `MenuItem.mcp` and
   `ToolKey.mcp` are fields -- as `'project_<name>'`, `'ui'` for one that only changes the view, or
   `projectNone('<why>')` (from `@vibe/editor`) while its tool is to write.
2. Its MCP tool in `mcpTools` of `src/tools/index.ts`: a `ProjectMcpTool` -- `name` (Claude calls it
   `project_<name>`), `description`, `input` as JSON Schema, `annotations`, `run` -- in a file of its own beside the
   tool, so a node test can run it on a world.
3. Its page, `src/tools/<tool>/<id>.skill.md`, named as the tool's `id` (a tool `id: 'tiles'` has `tiles.skill.md`),
   with this frontmatter:

   ```
   ---
   skill: studio
   title: The Tiles tab
   when: Before painting a tile layer through project_tiles_paint
   covers:
     tools: [project_tiles_paint]
   ---
   ```

   then who it is for, what the tool is, the jobs as short recipes with real calls, its refusals and what to do
   about each, a job end to end, and the rules that bite. Link other pages by file name (`scene.md`).

`npm test`'s `skills` check fails on a tool of `src/tools/` with no page named as its id, on a `project_<name>`
tool no page covers, and on a page that names a tool that is not there; the `mcp` check on a button or key that
declares nothing. `vibe sync` (and the dev server, before each turn) copies the pages into `.claude/skills/studio/`.
