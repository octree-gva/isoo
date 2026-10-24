---
name: ISOO
description: Self-hosted ISO 27001 documentation desk. Signal orange, carbon ink, VG5000 and IBM Plex Sans.
colors:
  primary: "#ff661a"
  primary-hover: "#e04d00"
  ink: "#2c2c2b"
  paper: "#ffffff"
  muted: "#737373"
  border: "#d4d4d4"
  hairline: "#e5e5e5"
  surface: "#fafafa"
  surface-header: "#f0f0f0"
  table-rule: "#b8b8b8"
  on-wash: "#dcfce7"
  on-ink: "#166534"
  off-wash: "#fee2e2"
  off-ink: "#991b1b"
  warning-wash: "#fffbeb"
  warning-ink: "#92400e"
  warning-line: "#fcd34d"
  selection: "#ffd9c6"
  track: "#c8c8c8"
typography:
  display:
    fontFamily: "VG5000, ui-sans-serif, system-ui, sans-serif"
    fontSize: "2.25rem"
    fontWeight: 400
    lineHeight: 1.2
  headline:
    fontFamily: "VG5000, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 400
    lineHeight: 1.25
  title:
    fontFamily: "VG5000, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 400
    lineHeight: 1.3
  body:
    fontFamily: "IBM Plex Sans, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.5
  body-lg:
    fontFamily: "IBM Plex Sans, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 400
    lineHeight: 1.5
  field:
    fontFamily: "IBM Plex Sans, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.5
  meta:
    fontFamily: "IBM Plex Sans, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.4
  compact:
    fontFamily: "IBM Plex Sans, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.8125rem"
    fontWeight: 400
    lineHeight: 1.35
  switch:
    fontFamily: "IBM Plex Sans, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "0.04em"
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "0.8rem"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "VG5000, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "1.2px"
rounded:
  control: "10px"
  surface: "0.5rem"
  pill: "9999px"
spacing:
  xs: "0.25rem"
  sm: "0.5rem"
  md: "0.75rem"
  lg: "1rem"
  xl: "1.5rem"
  2xl: "2rem"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.paper}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0.625rem 1.25rem"
    height: "2.75rem"
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
    textColor: "{colors.paper}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0.625rem 1.25rem"
    height: "2.75rem"
  button-outline:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0.625rem 1rem"
    height: "2.75rem"
  text-field:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.surface}"
    height: "2.75rem"
  badge-on:
    backgroundColor: "{colors.on-wash}"
    textColor: "{colors.on-ink}"
    rounded: "{rounded.surface}"
  alert-warning:
    backgroundColor: "{colors.warning-wash}"
    textColor: "{colors.warning-ink}"
    rounded: "{rounded.surface}"
    padding: "0.875rem 1rem"
  hint:
    textColor: "{colors.muted}"
    typography: "{typography.body}"
  table-header:
    backgroundColor: "{colors.surface-header}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
  rule:
    backgroundColor: "{colors.border}"
    height: "1px"
  hairline:
    backgroundColor: "{colors.hairline}"
    height: "1px"
  table-rule:
    backgroundColor: "{colors.table-rule}"
    height: "1px"
  badge-off:
    backgroundColor: "{colors.off-wash}"
    textColor: "{colors.off-ink}"
    rounded: "{rounded.surface}"
  presence:
    backgroundColor: "{colors.warning-wash}"
    textColor: "{colors.warning-ink}"
    rounded: "{rounded.surface}"
  selection-mark:
    backgroundColor: "{colors.selection}"
    textColor: "{colors.ink}"
  warning-rule:
    backgroundColor: "{colors.warning-line}"
    height: "1px"
  wizard-track:
    backgroundColor: "{colors.track}"
    rounded: "{rounded.pill}"
---

# Design System: ISOO

Who reads this: someone changing ISOO screens. The person using those screens keeps an ISO 27001 documentation set: projects, text, tables, annexes, reviews, export.

## Overview

**Creative North Star: "The field manual"**

Visitor mode is **Operate**. ISOO is the desk where someone writes, reviews, and exports an ISO 27001 documentation set. The page is a paper sheet with a carbon ink rule and one signal-orange action. VG5000 labels the controls. IBM Plex Sans carries the reading.

The palette and the two faces are the implemented system. Status green, red, and amber already live on switches, withheld rows, and the co-editing banner. They mark state. They are not a second brand.

**Key Characteristics:**

- Signal orange (#ff661a), carbon ink (#2c2c2b), paper (#ffffff)
- VG5000 for titles and buttons, IBM Plex Sans for reading and tables
- 10px control corners, 8px surfaces, 1px rules, no drop shadow
- Controls at least 2.75rem, focus ring 3px orange

## Colors

One signal orange on paper and ink. State colors are washes with darker ink, already used by switches and the presence banner.

### Primary

- **Signal orange** (`colors.primary`): the action. Primary buttons, skip link, focus ring, checkbox, radio dot, wizard step, links in the app.
- **Pressed orange** (`colors.primary-hover`): the same hue, darker, for hover and press. Do not fade the control with opacity.

### Neutral

- **Carbon ink** (`colors.ink`): body text, outline buttons, table text.
- **Paper** (`colors.paper`): page, dialog, field, toast.
- **Muted** (`colors.muted`): hints, placeholders, metadata, secondary icons. Use the color. Do not reach it by fading ink with opacity.
- **Rule** (`colors.border`): fields, empty panels, dialogs, footers.
- **Hairline** (`colors.hairline`): splits inside a readonly row and the editor toolbar.
- **Surface** (`colors.surface`): empty panels, toolbar, zebra row.
- **Header surface** (`colors.surface-header`): table header cells.
- **Table rule** (`colors.table-rule`): cell borders.

### State

- **On**: wash `colors.on-wash`, ink `colors.on-ink`. Switch on, success badge, success alert.
- **Off**: wash `colors.off-wash`, ink `colors.off-ink`. Switch off, destructive outline, error alert.
- **Warning**: wash `colors.warning-wash`, ink `colors.warning-ink`, line `colors.warning-line`. Presence banner, warning badge, warning alert.
- **Selection**: `colors.selection` behind ink. It is a tint of the orange, not a new accent.

### Named Rules

**The One Orange Rule.** Signal orange is the only brand accent. Green, red, and amber appear only as state.

**The Solid Control Rule.** Hover changes the fill. It does not drop the whole control to partial opacity.

## Typography

**Display font:** VG5000 (weight 400 only; the file has no bold)
**Body font:** IBM Plex Sans (400, 500, 600, 700)
**Label font:** VG5000, uppercase, 1.2px tracking, on buttons

**Character:** VG5000 is the instrument face for names and actions. IBM Plex Sans is the reading face for documents, tables, and hints.

### Hierarchy

- **Display** (400, 2.25rem, line-height 1.2; floors at 1.875rem on a narrow screen): page title. Same range as the document header.
- **Headline** (400, 1.5rem, line-height 1.25): section title and dialog title.
- **Title** (400, 1.25rem, line-height 1.3): subsection.
- **Body** (400, 1rem, line-height 1.5; 1.125rem from 640px): reading, fields, hints. Measure stays inside the page column (`max-w-3xl` on form pages, full width on tables).
- **Label** (400, 1rem, uppercase, 1.2px tracking): buttons and the skip link.

### Named Rules

**The Two Face Rule.** Titles, buttons, and captions use VG5000. Reading, tables, fields, and hints use IBM Plex Sans. Do not load Inter, Arial, or a system face as the voice. The fallback stack exists only when the files fail to load.

**The Real Weight Rule.** VG5000 is drawn at 400. Do not apply a bold utility to it. IBM Plex Sans may use 600 on table headers and field labels.

## Layout

The reading column is `max-w-3xl`, centered inside `.page-gutter`. The gutter is 1rem, and 2rem from 768px, plus the device safe area. It sits on the header, the main frame, and the action bar. The column does not add a second horizontal padding. Wide tables scroll inside their own panel. The page itself is not clipped.

Sticky page actions sit on a paper bar with a 1px top rule. From 640px that bar is one row, and the column keeps 5.5rem clear of it. Below 640px the actions stack, and the column keeps 10rem clear. Dialogs are nearly full width on small screens and 50rem from 1024px. The fullscreen table keeps its header and footer fixed and scrolls the grid.

**The Gutter Rule.** One horizontal inset, outside the column, shared by the header, the page, and the action bar. A spacing mistake may scroll. It must not be hidden.

Space stacks in 0.25rem steps. A heading has more space above it than below it. Empty states use the same panel as an empty table: surface fill, 1px rule, 8px corner, 1.25rem 1.5rem padding.

## Elevation & Depth

The system is flat. A 1px rule separates regions. Dialogs dim the page with ink at 45% opacity. Sticky bars are solid paper.

### Named Rules

**The Flat Rule.** No drop shadow and no blurred glass. A menu, a toast, a table panel, and a footer separate themselves with a border.

## Shapes

Controls (buttons, skip link) use a 10px corner. Surfaces (fields, panels, badges, alerts, empty states) use 8px. Radios and wizard dots are pills. Table cells are square.

## Components

Markup is daisyUI 4 on `data-theme="isoo"`, restyled in `assets/css/app.css`. Use the classes below. Do not add a second component library.

### Buttons

- **Shape:** 10px corner, at least 2.75rem square, uppercase VG5000, 1.2px tracking.
- **Primary:** signal orange fill, paper label. Hover and press use pressed orange. The label stays paper.
- **Outline:** paper fill, ink text, ink border. Hover fills with surface. Destructive outline uses off-ink and off-wash on hover.
- **Ghost:** transparent, ink text. Hover fills with surface.
- **Focus:** 3px signal orange outline, 2px offset.
- **Disabled:** 45% opacity. This is the one opacity treatment, and it is only for disabled.

### Badges

IBM Plex Sans, 600, 8px corner. Primary uses signal orange and a paper label. On, off, and warning use the state washes and their inks. Outline and ghost stay paper with a rule and ink text.

### Alerts and toasts

Same washes as badges, with a 1px border in the matching ink or warning line. No shadow. The toast sits at the top end and can be dismissed.

### Inputs / Fields

Paper fill, ink text, rule border, 8px corner, at least 2.75rem tall. Placeholder is muted. Focus is the same 3px orange outline as buttons. The markdown editor uses that outline on the whole field, not a glow. Compact cells in the fullscreen table are the density exception: the grid stays editable, so those inputs are shorter than 2.75rem.

### Navigation

A paper bar, 1px bottom rule. The wordmark is VG5000 with the shield icon. Actions in the bar are ghost buttons. The signed-in name is muted. There is no second sidebar.

### Tables

IBM Plex Sans, square cells, table-rule borders, header surface, zebra surface on even rows. Row actions are a ghost menu with a paper panel and a 1px rule.

### Empty states

One panel (`.empty-note` or `.doc-table-empty`): surface, rule, 8px corner, ink sentence. Do not leave an empty list as faded body text.

### Links

In the app, `.link-primary` is signal orange, underlined with a 0.18em offset, pressed orange on hover. In the print export, body links are ink and underlined. The export table of contents may stay signal orange.

## Do's and Don'ts

### Do:

- **Do** keep signal orange, carbon ink, paper, VG5000, and IBM Plex Sans when adding a screen.
- **Do** use daisyUI classes already on these pages: `btn`, `btn-primary`, `btn-outline`, `btn-ghost`, `input`, `textarea`, `select`, `checkbox`, `radio`, `modal`, `badge`, `alert`, `navbar`.
- **Do** give every new control a hover, a 3px orange focus ring, and a disabled state when it can be disabled.
- **Do** use muted (#737373) for hints.

### Don't:

- **Don't** introduce a second brand color, a gradient, a drop shadow, or a glass blur.
- **Don't** set secondary text with `opacity-70` or `opacity-80`.
- **Don't** faux-bold VG5000.
- **Don't** size a page title like a poster. Display stops at 2.25rem.
- **Don't** swap the faces for Inter, Arial, or system-ui as the designed voice.
- **Don't** build a page as a grid of icon tiles.
