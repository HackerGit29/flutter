# DESIGN.md — aricie (MindCare Energy)
> Complete design system for the MindCare Energy Flutter app. Drop this file into your project root and instruct any AI coding agent: **"Build me a page that looks like this."**

---
> **2026 update**: Project evolving to multi-user architecture with admin roles, VIP subscriptions, device ownership/perimeter separation, and unique hardware UID sync. System-diagram accent: `rgb(121, 207, 244)`. See `AGENTS.md` for architecture context.
---

## 1. DESIGN PHILOSOPHY

### Core Aesthetic
**Soft Wellness Minimalism** — A calm, approachable health app that balances clinical trust with emotional warmth. The interface feels like a digital spa: airy whites, muted pastels, gentle curves, and soft shadows. Nothing is harsh or aggressive. Every element communicates safety, balance, and care.

### Design Principles
1. **Softness first** — Rounded corners everywhere. No sharp edges, no hard contrasts.
2. **Calm hierarchy** — Information is gently layered, never overwhelming.
3. **Pastel personality** — Color is used for warmth and category, never for shock.
4. **Tactile cards** — Content lives in soft, elevated cards with subtle shadows.
5. **Human-centered** — Real faces, friendly illustrations, warm greetings.
6. **Accessible spaciousness** — Generous padding, breathing room between elements.

### Personality Keywords
`calm` · `trustworthy` · `warm` · `approachable` · `scientific` · `friendly` · `clean` · `mindful`

---

## 2. COLOR SYSTEM

### Base Palette

```css
:root {
  /* Backgrounds */
  --color-bg-app:        #C8D9E0;  /* Muted teal-grey app shell background */
  --color-bg-primary:    #FFFFFF;  /* Main card/screen background */
  --color-bg-secondary:  #F0F6F8;  /* Soft light blue-grey, secondary panels */
  --color-bg-tertiary:   #E8F2F5;  /* Very light teal tint, input areas */

  /* Brand / Accent Colors */
  --color-accent-teal:   #1A3A4A;  /* Deep teal — primary CTA, selected states, strong text */
  --color-accent-pink:   #F0B8C8;  /* Soft rose pink — hero gradient, featured sections */
  --color-accent-purple: #C8A8D8;  /* Muted lavender — Mind Detox category tag */
  --color-accent-sage:   #A8C8A8;  /* Soft sage green — Conscious Breath, nature/calm */
  --color-accent-coral:  #E8C0A8;  /* Warm peach/coral — Gratitude Notes category */
  --color-accent-blue:   #A8C8E0;  /* Sky blue — results panel, mood summary card */
  --color-accent-mint:   #B8E0D0;  /* Mint green — positive states, success */
  --color-accent-gold:   #F5C842;  /* Amber/yellow — star ratings, highlights */
  --color-accent-dot:    #E8506A;  /* Vibrant pink-red — notification dot, live indicators */

  /* Text Colors */
  --color-text-primary:  #1A2530;  /* Near-black, main headings */
  --color-text-secondary:#4A5A68;  /* Dark slate, body text */
  --color-text-muted:    #8A9AAA;  /* Grey, captions, timestamps */
  --color-text-inverse:  #FFFFFF;  /* White text on dark backgrounds */
  --color-text-accent:   #1A3A4A;  /* Teal for interactive/selected text */

  /* Interactive */
  --color-interactive:   #1A3A4A;  /* Selected date, primary button */
  --color-interactive-hover: #2A4A5A;
  --color-border-subtle: rgba(26, 58, 74, 0.08); /* Hair-thin card borders */
  --color-shadow-card:   rgba(26, 58, 74, 0.08); /* Soft card shadows */
}
```

### Semantic Color Usage

| Context | Token | Value |
|---------|-------|-------|
| App shell background | `--color-bg-app` | `#C8D9E0` |
| Card/screen surface | `--color-bg-primary` | `#FFFFFF` |
| Selected date circle | `--color-interactive` | `#1A3A4A` |
| Average bar / dot | `--color-text-primary` | `#1A2530` |
| Highlighted bar (chart) | `--color-interactive` | `#1A3A4A` |
| Hero gradient start | `--color-accent-pink` | `#F0B8C8` |
| Hero gradient end | `--color-bg-primary` | `#FFFFFF` |
| Mind Detox pill | `--color-accent-purple` | `#C8A8D8` |
| Gratitude Notes pill | `--color-accent-coral` | `#E8C0A8` |
| Conscious Breath pill | `--color-accent-sage` | `#A8C8A8` |
| Mood summary card | `--color-accent-blue` | `#A8C8E0` |
| Star rating | `--color-accent-gold` | `#F5C842` |
| Notification dot | `--color-accent-dot` | `#E8506A` |

### Gradient Recipes

```css
/* Hero/Doctor Profile gradient */
.gradient-hero {
  background: linear-gradient(180deg, #F2B8CC 0%, #EEC8D8 40%, #FFFFFF 100%);
}

/* Mood Summary Card */
.gradient-mood {
  background: linear-gradient(135deg, #A8C8E0 0%, #B8D8E8 100%);
}

/* Selected date badge */
.badge-selected {
  background: #1A3A4A;
  color: #FFFFFF;
}

/* App shell */
.app-shell {
  background: #C8D9E0;
}
```

---

## 3. TYPOGRAPHY

### Font Stack

```css
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;1,9..40,400&family=DM+Serif+Display:ital@0;1&display=swap');

:root {
  --font-display: 'DM Serif Display', Georgia, serif;  /* Hero headings, feature titles */
  --font-body:    'DM Sans', -apple-system, sans-serif; /* All UI text */
}
```

> **Rationale**: DM Sans perfectly matches the rounded, friendly, modern sans-serif used throughout the app. Its optical sizing and variable weight range covers all use cases. DM Serif Display is used for impactful feature titles (e.g., "Health Brain Assistant").

### Type Scale

```css
:root {
  /* Display / Hero */
  --text-hero:       28px;  /* "Health Brain Assistant" — bold serif feature */
  --text-display:    24px;  /* Page titles, section headers */
  --text-title:      20px;  /* Card titles, doctor name */
  --text-heading:    17px;  /* Section headings "Consistency score", "Trending" */
  --text-subheading: 15px;  /* Subsection labels, tab items */
  --text-body:       14px;  /* Standard body text, list items */
  --text-small:      12px;  /* Captions, timestamps, metadata */
  --text-micro:      10px;  /* Labels on mini-tags, axis labels */

  /* Line Heights */
  --lh-tight:   1.1;  /* Hero display text */
  --lh-heading: 1.3;  /* Titles */
  --lh-body:    1.5;  /* Body text */
  --lh-loose:   1.7;  /* Descriptive paragraphs */

  /* Letter Spacing */
  --ls-tight:   -0.02em;  /* Large headings */
  --ls-normal:   0em;
  --ls-wide:     0.03em;  /* All-caps labels, small metadata */
  --ls-wider:    0.06em;  /* Section labels, pill text */
}
```

### Type Tokens

| Token | Size | Weight | Usage |
|-------|------|--------|-------|
| `text-greeting` | 22px | 700 | "Good Morning, Frede 👋" |
| `text-date-label` | 13px | 400 | "Thursday, 16 Oct" |
| `text-section-title` | 17px | 700 | "Consistency score", "Favorite activities" |
| `text-hero-feature` | 28px | 700 | "Health Brain Assistant" |
| `text-doctor-name` | 18px | 600 | "Dr. Sam Kartner" |
| `text-doctor-role` | 13px | 400 | "Psychologist" (muted) |
| `text-score-large` | 22px | 800 | "12.4" chart highlight |
| `text-score-avg` | 11px | 500 | "Avg.12.3%" label |
| `text-activity-title` | 12px | 600 | "Mind Detox", "Gratitude Notes" |
| `text-activity-meta` | 11px | 400 | "⏱ 13h" durations |
| `text-tab-active` | 14px | 600 | "Rankings" (underlined tab) |
| `text-tab-inactive` | 14px | 400 | "Activity" (inactive tab) |
| `text-rank-name` | 14px | 600 | "Geremy Boundea" |
| `text-rank-score` | 12px | 400 | "Score: 9,988" |
| `text-mood-label` | 26px | 800 | "Good" (mood result) |
| `text-mood-desc` | 11px | 400 | Mood description caption |
| `text-trending-title` | 14px | 600 | "Meditation" |
| `text-trending-meta` | 11px | 400 | "12h 32m in total" |
| `text-cta-button` | 13px | 600 | "Heal your mind" button label |
| `text-nav-month` | 14px | 500 | "October" in navigation |

---

## 4. SPACING SYSTEM

### Base Grid: 4px

```css
:root {
  --space-1:   4px;
  --space-2:   8px;
  --space-3:  12px;
  --space-4:  16px;
  --space-5:  20px;
  --space-6:  24px;
  --space-7:  28px;
  --space-8:  32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;
}
```

### Component Spacing Rules

| Component | Padding | Gap |
|-----------|---------|-----|
| Screen/page container | `20px horizontal` | — |
| Card (standard) | `16px` | — |
| Card (large/hero) | `20px` | — |
| Activity pill | `10px 14px` | — |
| CTA button | `10px 20px` | — |
| Date circle | `8px` | — |
| Date strip | `8px vertical` | `12px between dates` |
| Section spacing | `20px top` | — |
| List item spacing | `12px between` | — |
| Tab bar items | `8px 0` | `24px between` |
| Stats row | `8px vertical` | `16px between` |
| Chart bar spacing | — | `8px between bars` |

---

## 5. BORDER RADIUS

```css
:root {
  --radius-xs:   6px;   /* Tiny tags, mini labels */
  --radius-sm:   10px;  /* Small buttons, tight pills */
  --radius-md:   14px;  /* Standard cards, input fields */
  --radius-lg:   20px;  /* Large cards, activity pills */
  --radius-xl:   24px;  /* Main screen cards, hero sections */
  --radius-2xl:  32px;  /* App screen shell / phone frame */
  --radius-full: 9999px; /* Date circles, avatar badges, dot indicators */
}
```

### Radius Application Guide

| Element | Radius |
|---------|--------|
| App phone frame | `--radius-2xl` (32px) |
| Main screen cards | `--radius-xl` (24px) |
| Activity category pills | `--radius-lg` (20px) |
| Trending/result cards | `--radius-md` (14px) |
| CTA button ("Heal your mind") | `--radius-full` |
| Date picker circle | `--radius-full` |
| Input field | `--radius-full` |
| Avatar image | `--radius-full` |
| Chart bars | `--radius-sm` top only |
| Nav month button | `--radius-full` |
| Mood summary card | `--radius-lg` (20px) |
| Tab indicator underline | `--radius-full` (2px height) |

---

## 6. SHADOW SYSTEM

```css
:root {
  /* Card elevation levels */
  --shadow-xs:  0 1px 3px rgba(26, 58, 74, 0.06);
  --shadow-sm:  0 2px 8px rgba(26, 58, 74, 0.08);
  --shadow-md:  0 4px 16px rgba(26, 58, 74, 0.10);
  --shadow-lg:  0 8px 32px rgba(26, 58, 74, 0.12);

  /* Inner glow for selected states */
  --shadow-inset: inset 0 1px 3px rgba(26, 58, 74, 0.10);

  /* Floating elements (modals, tooltips) */
  --shadow-float: 0 16px 48px rgba(26, 58, 74, 0.16);
}
```

### Elevation Usage

| Shadow | Use case |
|--------|----------|
| `--shadow-xs` | Inline tags, pills, minor elements |
| `--shadow-sm` | Standard cards, activity pills |
| `--shadow-md` | Main screen cards, profile cards |
| `--shadow-lg` | Featured hero sections, sticky headers |
| `--shadow-float` | Modals, popovers, bottom sheets |

---

## 7. COMPONENT LIBRARY

### 7.1 Screen / App Frame

```css
.app-screen {
  width: 375px;              /* Mobile width */
  min-height: 812px;         /* iPhone-style height */
  border-radius: var(--radius-2xl);
  background: var(--color-bg-primary);
  padding: 20px 20px 32px;
  overflow: hidden;
  box-shadow: var(--shadow-lg);
}
```

### 7.2 Greeting Header

**Pattern**: Full-width row with greeting on left, notification bell on right.

```html
<header class="greeting-header">
  <div>
    <h1 class="greeting-title">Good Morning,<br>Frede 👋</h1>
  </div>
  <button class="icon-btn">
    <span class="bell-icon">🔔</span>
    <span class="notif-dot"></span>
  </button>
</header>
```

```css
.greeting-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--space-5);
}

.greeting-title {
  font-family: var(--font-body);
  font-size: 22px;
  font-weight: 700;
  color: var(--color-text-primary);
  line-height: var(--lh-heading);
}

.icon-btn {
  width: 40px;
  height: 40px;
  border-radius: var(--radius-full);
  background: var(--color-bg-primary);
  box-shadow: var(--shadow-sm);
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  position: relative;
}

.notif-dot {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 8px;
  height: 8px;
  border-radius: var(--radius-full);
  background: var(--color-accent-dot);
  border: 2px solid white;
}
```

### 7.3 Date Strip / Calendar Picker

**Pattern**: Horizontal scrollable strip of day numbers with selected state as dark filled circle.

```html
<div class="date-strip">
  <span class="date-label">Thursday, 16 Oct</span>
  <button class="date-add-btn">+</button>
  <div class="date-row">
    <button class="date-item">21</button>
    <button class="date-item selected">22</button>
    <button class="date-item">23</button>
    <button class="date-item">24</button>
    <button class="date-item">25</button>
    <button class="date-item">26</button>
    <button class="date-item">27</button>
  </div>
</div>
```

```css
.date-label {
  font-size: 13px;
  color: var(--color-text-secondary);
  font-weight: 400;
}

.date-row {
  display: flex;
  gap: 12px;
  margin-top: 10px;
}

.date-item {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-full);
  border: none;
  background: transparent;
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: 500;
  color: var(--color-text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s ease;
}

.date-item.selected {
  background: var(--color-interactive);
  color: var(--color-text-inverse);
  font-weight: 700;
}

.date-item:hover:not(.selected) {
  background: var(--color-bg-secondary);
}
```

### 7.4 Consistency Score Chart

**Pattern**: Bar chart with average dotted line, current bar highlighted in dark teal, day labels below.

```css
.chart-container {
  background: transparent;
  padding: 0;
  margin-top: var(--space-4);
}

.chart-avg-label {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: var(--color-text-primary);
  color: var(--color-text-inverse);
  font-size: 10px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: var(--radius-full);
  margin-bottom: 8px;
}

.chart-bars {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  height: 80px;
}

.chart-bar {
  flex: 1;
  border-radius: 4px 4px 0 0;
  background: var(--color-bg-secondary);
  transition: height 0.3s ease;
}

.chart-bar.active {
  background: var(--color-interactive);
}

.chart-bar.highlighted {
  /* The tallest / current day bar */
  background: var(--color-interactive);
}

.chart-day-labels {
  display: flex;
  gap: 8px;
  margin-top: 6px;
}

.chart-day-label {
  flex: 1;
  text-align: center;
  font-size: 10px;
  color: var(--color-text-muted);
  font-weight: 400;
}

.chart-day-label.active {
  color: var(--color-text-accent);
  font-weight: 600;
}

/* Score annotation above bar */
.chart-score-annotation {
  font-size: 11px;
  font-weight: 700;
  color: var(--color-text-primary);
  text-align: center;
}

/* Dotted average line */
.chart-avg-line {
  border-top: 1.5px dashed var(--color-text-muted);
  position: absolute;
  width: 100%;
  opacity: 0.5;
}
```

### 7.5 Activity Category Pills

**Pattern**: Horizontal row of 3 colored pill cards, each with icon on right and title + duration on left.

```html
<div class="activity-pills-row">
  <div class="activity-pill" style="--pill-bg: #C8A8D8">
    <span class="pill-title">Mind Detox</span>
    <span class="pill-duration">⏱ 13h</span>
    <span class="pill-icon">🧠</span>
  </div>
  <div class="activity-pill" style="--pill-bg: #E8D0B8">
    <span class="pill-title">Gratitude Notes</span>
    <span class="pill-duration">⏱ 34h</span>
    <span class="pill-icon">✳</span>
  </div>
  <div class="activity-pill" style="--pill-bg: #A8C8A8">
    <span class="pill-title">Conscious Breath</span>
    <span class="pill-duration">⏱ 34h</span>
    <span class="pill-icon">🌿</span>
  </div>
</div>
```

```css
.activity-pills-row {
  display: flex;
  gap: 10px;
  margin-top: var(--space-3);
}

.activity-pill {
  flex: 1;
  background: var(--pill-bg);
  border-radius: var(--radius-lg);
  padding: 12px 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  position: relative;
  min-height: 80px;
  box-shadow: var(--shadow-xs);
}

.pill-title {
  font-size: 11px;
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1.2;
}

.pill-duration {
  font-size: 10px;
  color: var(--color-text-secondary);
  display: flex;
  align-items: center;
  gap: 3px;
}

.pill-icon {
  position: absolute;
  bottom: 10px;
  right: 10px;
  font-size: 18px;
  opacity: 0.9;
}
```

### 7.6 Trending Item Card

**Pattern**: Horizontal card with icon on left, title + meta in center, week indicator dots + arrow on right.

```css
.trending-card {
  background: var(--color-bg-secondary);
  border-radius: var(--radius-md);
  padding: 12px 14px;
  display: flex;
  align-items: center;
  gap: 12px;
  box-shadow: var(--shadow-xs);
}

.trending-icon {
  width: 44px;
  height: 44px;
  border-radius: var(--radius-md);
  background: var(--color-bg-tertiary);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  flex-shrink: 0;
}

.trending-info {
  flex: 1;
}

.trending-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.trending-meta {
  font-size: 11px;
  color: var(--color-text-muted);
  margin-top: 2px;
  display: flex;
  align-items: center;
  gap: 4px;
}

.trending-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 6px;
}

.trending-last-week {
  font-size: 10px;
  color: var(--color-text-muted);
  white-space: nowrap;
}

/* Week dot indicators (s m t w t f s) */
.week-dots {
  display: flex;
  gap: 3px;
  align-items: center;
}

.week-dot {
  width: 6px;
  height: 6px;
  border-radius: var(--radius-full);
  background: var(--color-bg-tertiary);
}

.week-dot.active {
  background: var(--color-interactive);
}

.week-label {
  font-size: 8px;
  color: var(--color-text-muted);
  text-align: center;
  margin-top: 1px;
}
```

### 7.7 Hero / Doctor Profile Card

**Pattern**: Full-bleed screen with pink-to-white gradient background, large profile photo floating in upper half, feature title in bold serif, CTA button, doctor info + rating in lower card area.

```css
.hero-card {
  border-radius: var(--radius-xl);
  background: linear-gradient(180deg, #F2B8CC 0%, #EEC8D8 35%, #FFFFFF 100%);
  overflow: hidden;
  position: relative;
  min-height: 480px;
}

.hero-back-btn {
  position: absolute;
  top: 16px;
  left: 16px;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-full);
  background: rgba(255,255,255,0.8);
  backdrop-filter: blur(8px);
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: var(--shadow-sm);
}

.hero-share-btn {
  position: absolute;
  top: 16px;
  right: 16px;
  /* Same styling as back-btn */
}

.hero-feature-tag {
  position: absolute;
  top: 52px;
  left: 16px;
  background: rgba(255,255,255,0.3);
  border-radius: var(--radius-full);
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  color: var(--color-text-primary);
}

.hero-titles {
  position: absolute;
  bottom: 170px;
  left: 20px;
  z-index: 2;
}

.hero-category {
  font-size: 16px;
  font-weight: 400;
  color: var(--color-text-primary);
  opacity: 0.8;
}

.hero-main-title {
  font-family: var(--font-display);
  font-size: 28px;
  font-weight: 700;
  color: var(--color-text-primary);
  line-height: 1.1;
  margin: 2px 0 12px;
}

.hero-cta-btn {
  background: rgba(255,255,255,0.85);
  border: none;
  border-radius: var(--radius-full);
  padding: 8px 18px;
  font-family: var(--font-body);
  font-size: 12px;
  font-weight: 600;
  color: var(--color-text-primary);
  cursor: pointer;
  backdrop-filter: blur(8px);
  box-shadow: var(--shadow-sm);
}

.hero-doctor-photo {
  position: absolute;
  right: 0;
  top: 0;
  height: 70%;
  object-fit: cover;
  /* Photo bleeds to right edge */
}

.hero-doctor-info {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--color-bg-primary);
  padding: 16px 20px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.doctor-name {
  font-size: 18px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.doctor-role {
  font-size: 13px;
  color: var(--color-text-muted);
  margin-top: 2px;
}

.doctor-rating {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 14px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.star-icon {
  color: var(--color-accent-gold);
  font-size: 14px;
}
```

### 7.8 Month Navigator

**Pattern**: Centered month label with left/right arrow buttons, used for appointment scheduling.

```css
.month-navigator {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin: 16px 0;
}

.month-nav-btn {
  width: 32px;
  height: 32px;
  border-radius: var(--radius-full);
  background: var(--color-bg-secondary);
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text-secondary);
  font-size: 16px;
}

.month-label-btn {
  background: var(--color-accent-pink);
  border: none;
  border-radius: var(--radius-full);
  padding: 8px 28px;
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: 500;
  color: var(--color-text-primary);
  cursor: pointer;
}
```

### 7.9 Availability Slots Row

**Pattern**: Horizontal scrollable row of date chips for booking.

```css
.availability-row {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  scrollbar-width: none;
  padding: 4px 0;
}

.availability-slot {
  flex-shrink: 0;
  background: var(--color-bg-secondary);
  border-radius: var(--radius-md);
  padding: 10px 14px;
  font-size: 12px;
  font-weight: 500;
  color: var(--color-text-secondary);
  white-space: nowrap;
  cursor: pointer;
  transition: background 0.15s;
}

.availability-slot.selected {
  background: var(--color-interactive);
  color: var(--color-text-inverse);
}

.availability-slot:hover:not(.selected) {
  background: var(--color-bg-tertiary);
}
```

### 7.10 Message Input

**Pattern**: Full-width pill input with send button on right.

```css
.message-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--color-bg-secondary);
  border-radius: var(--radius-full);
  padding: 10px 10px 10px 16px;
}

.message-input {
  flex: 1;
  border: none;
  background: transparent;
  font-family: var(--font-body);
  font-size: 14px;
  color: var(--color-text-secondary);
  outline: none;
}

.message-input::placeholder {
  color: var(--color-text-muted);
}

.message-send-btn {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-full);
  background: var(--color-interactive);
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 14px;
}
```

### 7.11 Tab Bar (Segmented Control)

**Pattern**: Two or more tabs with an underline indicator on active tab.

```css
.tab-bar {
  display: flex;
  gap: 24px;
  border-bottom: 1px solid var(--color-border-subtle);
  margin-bottom: 16px;
}

.tab-item {
  padding: 8px 0;
  font-size: 14px;
  font-weight: 400;
  color: var(--color-text-muted);
  cursor: pointer;
  position: relative;
  background: none;
  border: none;
  font-family: var(--font-body);
}

.tab-item.active {
  font-weight: 600;
  color: var(--color-text-primary);
}

.tab-item.active::after {
  content: '';
  position: absolute;
  bottom: -1px;
  left: 0;
  right: 0;
  height: 2px;
  border-radius: var(--radius-full);
  background: var(--color-text-primary);
}
```

### 7.12 Ranking List Item

**Pattern**: Numbered rank + avatar + name/score on left, stats row below, chevron on right.

```css
.rank-item {
  background: var(--color-bg-primary);
  border-radius: var(--radius-md);
  padding: 14px 16px;
  box-shadow: var(--shadow-sm);
  margin-bottom: 8px;
}

.rank-item-header {
  display: flex;
  align-items: center;
  gap: 12px;
}

.rank-number {
  font-size: 14px;
  font-weight: 700;
  color: var(--color-text-secondary);
  width: 16px;
  flex-shrink: 0;
}

.rank-avatar {
  width: 38px;
  height: 38px;
  border-radius: var(--radius-full);
  object-fit: cover;
  flex-shrink: 0;
}

.rank-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--color-text-primary);
  flex: 1;
}

.rank-score {
  font-size: 12px;
  color: var(--color-text-muted);
}

.rank-chevron {
  color: var(--color-text-muted);
  font-size: 14px;
}

/* Stats pills row below rank header */
.rank-stats {
  display: flex;
  gap: 16px;
  margin-top: 10px;
  padding-left: 28px;
}

.rank-stat {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  color: var(--color-text-secondary);
}

.rank-stat-icon {
  font-size: 12px;
  opacity: 0.7;
}
```

### 7.13 Mood Summary Card

**Pattern**: Full-width card with blue gradient, large mood label, description text, and cute illustrated character.

```css
.mood-card {
  background: linear-gradient(135deg, #A8C8E0 0%, #B8D8E8 100%);
  border-radius: var(--radius-lg);
  padding: 16px 16px 16px 18px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  overflow: hidden;
  position: relative;
}

.mood-card-left {
  flex: 1;
}

.mood-subtitle {
  font-size: 11px;
  font-weight: 500;
  color: var(--color-text-secondary);
  opacity: 0.8;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin-bottom: 2px;
}

.mood-label {
  font-size: 30px;
  font-weight: 800;
  color: var(--color-text-primary);
  line-height: 1;
}

.mood-description {
  font-size: 10px;
  color: var(--color-text-secondary);
  margin-top: 6px;
  max-width: 160px;
  line-height: 1.4;
  opacity: 0.8;
}

.mood-illustration {
  width: 64px;
  height: 64px;
  flex-shrink: 0;
  /* Cute character illustration / emoji art */
}
```

### 7.14 Performance Stat Row (Rankings Screen)

**Pattern**: Three small stat items in a horizontal row, each with icon + value + label.

```css
.perf-stats-row {
  display: flex;
  gap: 20px;
  padding: 8px 0;
  border-top: 1px solid var(--color-border-subtle);
  margin-top: 8px;
}

.perf-stat {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.perf-stat-header {
  display: flex;
  align-items: center;
  gap: 4px;
}

.perf-stat-icon {
  font-size: 12px;
  opacity: 0.7;
}

.perf-stat-label {
  font-size: 9px;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.perf-stat-value {
  font-size: 12px;
  font-weight: 600;
  color: var(--color-text-primary);
}
```

### 7.15 Mind Performance Tracker Page Title

**Pattern**: Large bold 2-line heading used as feature section titles.

```css
.tracker-title {
  font-family: var(--font-body);
  font-size: 26px;
  font-weight: 800;
  color: var(--color-text-primary);
  line-height: 1.1;
  letter-spacing: -0.02em;
  margin-bottom: 16px;
}
```

### 7.16 Add Button (Floating Action)

**Pattern**: Circular or pill `+` button in teal or background.

```css
.add-btn {
  width: 28px;
  height: 28px;
  border-radius: var(--radius-full);
  border: 1.5px solid var(--color-border-subtle);
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  color: var(--color-text-secondary);
  cursor: pointer;
}
```

---

## 8. ILLUSTRATION & ICONOGRAPHY

### Icon Style
- **Style**: Rounded, flat, 2D emoji-style or line icons
- **Size standard**: 16px inline, 20px small UI, 24px medium, 32px+ for category icons
- **Weight**: Medium weight (1.5–2px stroke)
- **Color**: Match surrounding context; icons on colored pills use dark teal at 70% opacity

### Category Icons (Activity Pills)

| Activity | Icon | Color |
|----------|------|-------|
| Mind Detox | 🧠 Brain | Purple `#C8A8D8` bg |
| Gratitude Notes | ✳️ Sparkle/burst | Coral `#E8C0A8` bg |
| Conscious Breath | 🌿 Leaf/plant | Sage `#A8C8A8` bg |
| Meditation | 🕯️ Candle | Neutral bg |

### Illustration Style
- **Mood character**: Simple, round, kawaii-style face with minimal features (dots for eyes, simple smile arc)
- **Doctor/practitioner photos**: Real photography, warm lighting, professional attire, neutral/light backgrounds
- **Charts**: Minimal, no gridlines visible, soft bar fills

### Navigation Icons
- Bell (notifications): Outline style, 20px
- Back arrow (`←`): Left chevron, 16px
- Share/QR code: Square with dots pattern
- Plus (`+`): Simple cross
- Send arrow: Diagonal arrow in circle
- Chevron right (`>`): Navigation affordance

---

## 9. MOTION & ANIMATION

### Principles
- **Ease**: All transitions use `ease` or `cubic-bezier(0.25, 0.46, 0.45, 0.94)`
- **Duration scale**:
  - Micro interactions: `100–150ms`
  - Component transitions: `200–250ms`
  - Page transitions: `300–400ms`
  - Chart animations: `400–600ms` staggered

```css
:root {
  --ease-standard: cubic-bezier(0.25, 0.46, 0.45, 0.94);
  --ease-spring:   cubic-bezier(0.34, 1.56, 0.64, 1.0);
  --duration-fast:   150ms;
  --duration-base:   220ms;
  --duration-slow:   350ms;
  --duration-page:   400ms;
}
```

### Animation Recipes

```css
/* Chart bars entrance */
@keyframes barRise {
  from { transform: scaleY(0); transform-origin: bottom; }
  to   { transform: scaleY(1); transform-origin: bottom; }
}
.chart-bar { animation: barRise var(--duration-slow) var(--ease-spring) both; }
.chart-bar:nth-child(2) { animation-delay: 60ms; }
.chart-bar:nth-child(3) { animation-delay: 120ms; }
/* ...continue stagger */

/* Card entrance */
@keyframes cardSlideUp {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}
.card-enter { animation: cardSlideUp var(--duration-base) var(--ease-standard) both; }

/* Notification dot pulse */
@keyframes dotPulse {
  0%, 100% { transform: scale(1); opacity: 1; }
  50%       { transform: scale(1.3); opacity: 0.7; }
}
.notif-dot { animation: dotPulse 2s ease-in-out infinite; }

/* Tab indicator slide */
.tab-item.active::after {
  transition: transform var(--duration-base) var(--ease-standard);
}

/* Button press */
.btn:active { transform: scale(0.97); transition: transform 100ms ease; }

/* Date picker selection */
.date-item { transition: background var(--duration-fast), color var(--duration-fast); }
```

---

## 10. LAYOUT PATTERNS

### Screen Structure

```
┌─────────────────────────────────┐
│  Greeting Header (icon btn)     │  ← 22px bold + notification bell
│  Date Label + Date Strip        │  ← 13px muted + 7 date circles
│  Section Title                  │  ← 17px bold
│  ▓▓▓▓▓▓▓▓ Chart ▓▓▓▓▓▓▓▓       │  ← 80px height bars
│  [Sun][Mon][Tue][Wed][Thr]...   │  ← 10px labels
│  Section Title                  │
│  [Pill 1] [Pill 2] [Pill 3]     │  ← Equal-width 3-col grid
│  Section Title                  │
│  [Trending Card]                │  ← Full-width card
└─────────────────────────────────┘
```

### Doctor Profile Screen

```
┌─────────────────────────────────┐
│ [←]                        [⬡]  │  ← Back + share
│                                 │
│  Health                         │
│  Brain          [Doctor Photo]  │  ← Photo bleeds right
│  Assistant                      │
│  [Heal your mind]               │
│─────────────────────────────────│
│  Dr. Sam Kartner        ★ 4.6   │  ← White bg info bar
│  Psychologist                   │
│─────────────────────────────────│
│  [←]     [ October ]     [→]    │  ← Month nav
│  [Thr 16] [Thr 17] [Thr 18]... │  ← Availability slots
│─────────────────────────────────│
│  [Write a message...     [➤]]   │  ← Message input
└─────────────────────────────────┘
```

### Performance Tracker Screen

```
┌─────────────────────────────────┐
│  Good Morning, Frede 👋    [🔔] │
│                                 │
│  Mind Performance               │
│  Tracker                        │
│                                 │
│  [Activity]  [Rankings ──]      │  ← Tab bar
│                                 │
│  1 [Avatar] Geremy Boundea  [>] │  ← Rank 1 card
│     Score: 9,988                │
│     🌿 3,330s  ✳ 2,331p  🧠 3m  │  ← Stats row
│                                 │
│  ── Your result ─────────────   │
│  [Monthly Mood: Good 😊]        │  ← Blue gradient card
│  [Conscious Breath  19h 32m]    │  ← Activity result
└─────────────────────────────────┘
```

---

## 11. INTERACTION PATTERNS

### Date Selection
- Tap → immediate fill to `--color-interactive`
- Previous selection deselects (single select)
- Scroll indicator if dates overflow

### Tab Navigation
- Tap → underline slides to new tab (`transition: left 220ms ease`)
- Content fades in: `opacity 0→1` over `200ms`

### Chart Bar Hover
- Bar brightens: `filter: brightness(1.1)`
- Tooltip appears above with exact value

### Card Press States
- All tappable cards: `transform: scale(0.98)` on active
- Duration: `100ms` press, `200ms` release

### Availability Slot Selection
- Toggle: tap once to select (dark fill), tap again to deselect
- Multiple selections possible for booking range

### Activity Pills
- Press state: slight scale down + brightness increase
- Could expand to detail view on tap

---

## 12. DATA VISUALIZATION

### Bar Chart (Consistency Score)

```
Chart specs:
- Container height: 80px
- Bar width: equal flex, ~32px each
- Bar gap: 8px
- Border radius: 4px (top corners only)
- Default bar color: #E8F2F5 (light teal)
- Active/selected bar: #1A3A4A (dark teal)
- No visible axes lines
- Y-axis: hidden
- X-axis: day abbreviations below (Sun, Mon...)
- Average reference: dotted line + pill label
- Score annotation: shown above active bar
```

### Progress/Activity Tracker (Week Dots)

```
Pattern: 7 dots (s m t w t f s) in a row
Active dot: --color-interactive (#1A3A4A)
Inactive: --color-bg-tertiary
Size: 6px diameter
Gap: 3px
```

### Trend Sparkline

```
Mini area chart in trending/result cards
Color: --color-interactive or category color
Height: ~24px
Width: ~60px
No axes, no labels
Filled area with low opacity
```

---

## 13. CONTENT GUIDELINES

### Tone of Voice
- **Warm and personal**: Use first-name greetings ("Good Morning, Frede 👋")
- **Encouraging**: Positive framing ("Good" mood, scores as achievements)
- **Clinical without coldness**: Professional titles (Dr., Psychologist) but approachable layout
- **Emoji-friendly**: Use sparingly — 1 per greeting, category icons only

### Copywriting Patterns

| Pattern | Example |
|---------|---------|
| Greeting | "Good Morning, [Name] 👋" |
| Date label | "Thursday, 16 Oct" |
| Section header | "Consistency score" / "Favorite activities" / "Trending" |
| CTA button | "Heal your mind" |
| Result label | "Good" / "Great" / "Fair" |
| Duration | "12h 32m in total" |
| Score | "9,988" (comma separator) |
| Stat unit | "3,330s", "2,331p", "3m" |

---

## 14. ACCESSIBILITY

### Contrast Requirements
- Body text on white: minimum 4.5:1 (WCAG AA)
- `#1A2530` on `#FFFFFF` = 14.9:1 ✅
- `#4A5A68` on `#FFFFFF` = 7.2:1 ✅
- White on `#1A3A4A` (dark teal) = 8.4:1 ✅
- `#1A2530` on `#C8A8D8` (purple pill) = 6.1:1 ✅

### Touch Targets
- Minimum: 44×44px for all interactive elements
- Date circles: 36px display but 44px touch area via padding
- Ensure adequate spacing between adjacent tappable elements

### Focus States
```css
:focus-visible {
  outline: 2px solid var(--color-interactive);
  outline-offset: 2px;
  border-radius: var(--radius-sm);
}
```

---

## 15. RESPONSIVE BEHAVIOR

### Breakpoints

```css
/* Mobile-first — this app is mobile-primary */
:root {
  --screen-xs: 320px;  /* Small phones */
  --screen-sm: 375px;  /* iPhone standard (primary target) */
  --screen-md: 430px;  /* iPhone Pro Max */
  --screen-lg: 768px;  /* Tablet adaptation */
}
```

### Adaptive Rules
- Date strip: horizontal scroll on `< 375px`
- Activity pills: 2-col grid on `< 340px`
- Hero card: doctor photo scales proportionally
- Charts: maintain 7 bars, reduce individual bar width on smaller screens

---

## 16. USAGE INSTRUCTIONS FOR AI AGENTS

### Prompt Template
> "Build a [screen name] screen for a health/wellness mobile app using this DESIGN.md. The screen should feel soft, minimal, and calm. Use DM Sans throughout, the color palette defined in section 2, rounded corners everywhere (minimum 12px), and white card surfaces on a light teal-grey app background. All interactive elements should have gentle 200ms transitions."

### Screen-Specific Hints

**Home / Dashboard screen:**
> "Include a greeting header, horizontal date strip with selected state in dark teal, a bar chart section for 'Consistency score' with the active day highlighted, a 3-pill row for favorite activities using colored backgrounds (purple, coral, sage), and a trending card at the bottom."

**Doctor/Specialist profile screen:**
> "Full-bleed pink-to-white gradient top half with a photo bleeding to the right edge. Feature title in large bold text bottom-left of gradient area. White bottom panel with doctor name, role, star rating, month navigator, and availability date chips."

**Mind Performance Tracker / Rankings screen:**
> "Large bold heading, tab bar with Activity/Rankings tabs, ranked list cards with avatar + name + score + stats row, and a 'Your result' section with a blue gradient mood card."

### Component Assembly Order
1. Import color tokens and typography from sections 2–3
2. Establish spacing/radius variables (sections 4–5)
3. Build base card, button, and input atoms (section 7)
4. Compose screen layouts from section 10
5. Add motion per section 9
6. Apply content guidelines from section 13

---

*Generated by design system extraction from MindCare UI. Version 1.0.*
