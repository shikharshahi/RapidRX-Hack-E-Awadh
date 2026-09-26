---
name: RapidRX
description: A paper desk for the family portal. Warm paper, ink, and one amber action.
colors:
  amber: "#f6b20a"
  amber-dark: "#c98d00"
  amber-soft: "#fff7da"
  amber-border: "#d9c06c"
  amber-hover: "#ffc22b"
  ink: "#111111"
  ink-soft: "#1b1a17"
  muted: "#5d574b"
  paper: "#fffdf5"
  surface: "#ffffff"
  hairline: "#e4ddcb"
  green: "#1b7a3d"
  green-soft: "#e3f3e8"
  green-border: "#b6dcc3"
  warn: "#b4690e"
  warn-soft: "#fdf0dc"
  warn-border: "#e8c89a"
  red: "#b3261e"
  red-deep: "#6f1a15"
  red-soft: "#fbe7e5"
  red-border: "#edc2bf"
typography:
  display:
    fontFamily: "Noto Sans RX, Noto Sans, system-ui, sans-serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0"
  headline:
    fontFamily: "Noto Sans RX, Noto Sans, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "0"
  title:
    fontFamily: "Noto Sans RX, Noto Sans, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "0"
  body:
    fontFamily: "Noto Sans RX, Noto Sans, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "0"
  label:
    fontFamily: "Noto Sans RX, Noto Sans, system-ui, sans-serif"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "0"
  meta:
    fontFamily: "Noto Sans RX, Noto Sans, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "0"
rounded:
  pill: "999px"
  phone: "28px"
  card: "20px"
  control: "14px"
spacing:
  gutter: "16px"
  section: "36px"
  card: "22px"
  row: "15px 18px"
components:
  button-primary:
    backgroundColor: "{colors.amber}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "14px 22px"
    height: "56px"
  button-primary-hover:
    backgroundColor: "{colors.amber-hover}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "14px 22px"
    height: "56px"
  nav-current:
    backgroundColor: "{colors.amber-soft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "0 14px"
    height: "44px"
  chip-taken:
    backgroundColor: "{colors.green-soft}"
    textColor: "{colors.green}"
    rounded: "{rounded.pill}"
    padding: "4px 11px"
  chip-missed:
    backgroundColor: "{colors.red-soft}"
    textColor: "{colors.red-deep}"
    rounded: "{rounded.pill}"
    padding: "4px 11px"
  chip-upcoming:
    backgroundColor: "{colors.warn-soft}"
    textColor: "{colors.warn}"
    rounded: "{rounded.pill}"
    padding: "4px 11px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    padding: "22px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "12px 16px"
    height: "56px"
---

# Design System: RapidRX

## Overview

**Creative North Star: "The paper desk"**

The family portal is a sheet of warm paper on a desk: ink for the words, one amber mark for the action, white cards for the things a caretaker has to read. It follows the public site at getrapidrx.web.app. Density is a document, not a dashboard. The phone app's 20px type and 64px black buttons stay on the phone.

**Key Characteristics:**

- Paper ground, ink type, amber only for the marker and the primary action
- White cards with a hairline and one soft shadow
- Status as a tinted pill: green taken, red missed, amber upcoming
- A sticky bar with the mark, the name, and text links

## Colors

One amber carries the action. Status colors are quiet tints, not a second brand.

### Primary

- **Dose amber** (#f6b20a): The primary button and the marker behind a word in the page title. Hover is #ffc22b. The button border is amber-dark #c98d00.

### Neutral

- **Paper** (#fffdf5): Page background.
- **Ink** (#111111): Text, the pressed segment, focus rings.
- **Ink soft** (#1b1a17): Lede text.
- **Muted** (#5d574b): Secondary copy, hints, timestamps.
- **Surface** (#ffffff): Cards, inputs, the queue.
- **Hairline** (#e4ddcb): Borders and row dividers.

### Status

- **Taken green** (#1b7a3d on #e3f3e8): A dose that was taken.
- **Missed red** (#6f1a15 on #fbe7e5): A missed dose or a high-priority note. The stronger red #b3261e is for the error line and the count numeral.
- **Upcoming amber** (#b4690e on #fdf0dc): A dose still ahead, and a medium note.

**The One Amber Rule.** Amber is the button and the title marker. It is not body text, not a page wash, and not a second button style.

## Typography

**Display Font:** Noto Sans RX (Noto Sans, system-ui)
**Body Font:** Noto Sans RX (same file, weight 400)
**Label Font:** Noto Sans RX at 13px bold

**Character:** One sans, two weights. The title is large, tight, and bold. Body stays at 17px. There is no display serif and no monospace costume.

### Hierarchy

- **Display** (700, clamp(32px, 5vw, 48px), 1.08, -0.03em): The page title. One word sits on an amber marker.
- **Headline** (700, clamp(22px, 3vw, 28px), -0.02em): Section titles such as Today, Missed doses, Schedule.
- **Title** (700, 17px): Card titles and the wordmark.
- **Body** (400, 17px, 1.55): Reading copy. Ledes stay near 62ch.
- **Label** (700, 13px): The bar tag, facts, timestamps, pills.

**The Marker Rule.** The amber mark is a background band behind one word (`linear-gradient(transparent 62%, #f6b20a 62%)`). It is not gradient text.

## Layout

The column is `min(100% - 32px, 1040px)`. A first viewport that is a decision (install, load, or the PIN) is two columns, 1.15fr and 0.85fr, with 48px between them. A page of records stacks. Below 800px both become one column, the bar wraps, and a section head stacks above its counts.

Space between sections is 36px. More space sits above a heading than between a heading and its list.

## Elevation & Depth

Depth is a hairline plus one soft shadow on white cards and the queue. The page itself is flat paper. The bar is paper at 92% opacity with an 8px blur so rows can pass under it.

### Shadow Vocabulary

- **Card** (`0 1px 2px rgba(17, 17, 17, 0.04), 0 8px 24px rgba(17, 17, 17, 0.05)`): Install card, dose queue, week summary, PIN card.

**The Flat Paper Rule.** Do not add a second shadow, a glow, or a hard offset. The hairline does the separating.

## Shapes

Cards and the queue use 18px. Buttons, inputs, and the QR frame use 14px. Pills, the segment, and nav links use a full pill. The QR sits in a 2px ink frame.

## Components

### Buttons

- **Shape:** 14px radius, 56px tall, 18px bold.
- **Primary:** Amber fill, ink text, 1px amber-dark border.
- **Hover / Focus:** Hover #ffc22b. Press shifts down 1px. Focus is a 2px ink outline, 3px out.
- **Inside a card:** The button is full width. In the page flow it sizes to its label, max 320px.

### Segment

- **Shape:** Pill track, white, hairline. Each option is a pill, 44px tall.
- **Pressed:** Ink fill, white text. Released is muted on white.

### Chips

- **Style:** 12px bold, pill, 4px 11px, a tinted fill and a 1px border in the same hue.
- **Counts:** A larger chip, 18px numeral in the status color, the word in muted.

### Cards / Queue

- **Corner Style:** 18px.
- **Background:** White.
- **Shadow Strategy:** The card shadow.
- **Border:** 1px hairline. Rows divide with the same hairline and no radius of their own.
- **Internal Padding:** 22px on a decision card. 15px 18px on a queue row.

### Inputs

- **Style:** White, hairline, 14px radius, 56px, 22px type for the PIN.
- **Focus:** Border becomes ink. The outline is suppressed on the field because the border carries it.
- **Error:** Bold red sentence under the button. The field is not restyled.

### Navigation

- **Bar:** Sticky, 72px, paper at 92% with blur, hairline under it. Mark is 40px.
- **Links:** 15px bold, muted, pill. Current page is amber-soft with an amber-border inset ring.
- **Mobile:** The links wrap onto their own row.

### Marker title

- One word in the h1 gets the amber band. The rest of the title stays plain ink.

## Do's and Don'ts

### Do

- **Do** keep the phone's records off this site. The copy says so.
- **Do** use amber for the one action on the page.
- **Do** show dose status as a tinted pill, with the medicine name in ink.
- **Do** use the self-hosted Noto Sans files in `portal/fonts`.

### Don't

- **Don't** bring the phone app's black 64px buttons or 20px body onto these pages.
- **Don't** put an eyebrow label above a heading.
- **Don't** use gradient text, glass panels, or a hard offset shadow.
- **Don't** invent a size or a hash for the APK. Show the version that is known.
