# Sequences Community Editorial Redesign

Date: 2026-04-29  
Status: Approved in conversation, awaiting final user review of written spec  
Scope: `/community` sequences experience only

## Goal

Redesign the sequences community page so it feels less like a long social list and more like a living sequence catalog with strong discovery, clearer hierarchy, and warmer interaction.

The page should help people:

- discover a good sequence quickly
- jump into the map with confidence
- notice community activity without the social layer overwhelming the core experience
- feel that the page is curated and alive on both mobile and desktop

This redesign is for the **community sequences page**, not the map-side sequence panel and not the generator flow.

## Product Direction

We are taking the **hybrid editorial** direction.

That means:

- the page leads with discovery and usefulness
- community signals remain visible and attractive
- the primary emotional impression is “there is something good here for me to open now”
- the primary functional action is still `Ver no mapa`

This is intentionally not:

- a pure social feed
- a plain personal library
- a dense admin-like list

## Problems With the Current Page

Today the page works, but it distributes visual weight too evenly:

- tabs, search, sorting, likes, favorites, author, comments, and map actions all compete at similar intensity
- sequence cards feel like information blocks with buttons, not like objects worth exploring
- the page rewards reading more than touching
- the community layer exists, but it does not guide discovery very elegantly
- the “mine” and “community” modes differ in data source, but not enough in tone or intent

The result is competent but flat.

## Design Principles

The redesigned page should follow these rules:

1. **Discovery first**  
   A person landing here should immediately see useful paths into the catalog.

2. **Map-first action hierarchy**  
   `Ver no mapa` stays the main action inside sequence cards.

3. **Social, but not noisy**  
   Likes, comments, follows, and authorship are important, but they should enrich the card instead of fragmenting it.

4. **Editorial warmth**  
   The page should feel closer to a curated cultural catalog than to a plain app dashboard.

5. **Mobile and desktop parity**  
   The information architecture should be the same across devices, with layout shifting gracefully rather than becoming two different products.

## Information Architecture

The page keeps two primary modes:

- `Comunidade`
- `Minhas`

But each mode should feel intentionally different.

### Comunidade

Purpose:

- discover sequences from the broader ecosystem
- see what is gaining traction
- enter the map from a curated surface

Tone:

- editorial
- inviting
- socially alive

### Minhas

Purpose:

- act as a personal shelf
- make created and saved sequences easier to revisit
- support more purposeful return visits

Tone:

- still warm and elegant
- slightly more library-like than community

## 1. Hero / Top Section

The hero should be shorter and stronger than the current heading/search row.

It should contain:

- a more intentional title than a plain “Sequências”
- one short line of support copy
- search input
- sorting control
- a strong `Criar sequência` CTA

The search remains prominent, but it should no longer visually dominate the page.

## 2. Discovery Rail

Below the hero, the community view should introduce an editorial discovery band made of quick-entry blocks.

Initial candidates:

- `Em alta`
- `Boas para treinar hoje`
- `De quem você segue`
- `Salvas`

These are not all required in v1 implementation, but the layout should be built to support this family of entry points.

The main job of this section is to let the page say:

- “here is a good place to begin”
- “you don’t need to scroll a long list before value appears”

## 3. Sequence Grid / Stream

The main list becomes a more editorial stream of cards.

Cards should breathe more and feel less like stacked records.

On desktop:

- likely a two-column rhythm in at least part of the page, or a mixed-width editorial stream
- enough width to make cards feel deliberate, not squeezed

On mobile:

- a one-column stack is acceptable
- but cards should still feel touch-friendly and visually chunked

## Sequence Card Design

Each sequence card should feel like an explorable object rather than a data container.

### Card hierarchy

1. sequence name
2. compact context line
3. preview of steps
4. author block
5. social indicators
6. actions

### Required card content

- sequence name in a stronger typographic treatment
- quick metadata such as:
  - number of steps
  - sequence length feel / short descriptor if available later
  - possibly dominant step family in future versions
- visual preview of contained steps
- author identity, with clickable name leading to the user profile
- like count
- comment count
- saved state
- `Ver no mapa` CTA
- secondary `Abrir detalhes` or equivalent expansion affordance

### Step preview

The existing inline code pills are useful, but too dry when used alone.

The redesign should keep the idea of quick step scanning, but make it feel more visual:

- step chips can remain
- layout should suggest flow, not just inventory
- future enhancement can include a tiny path/sequence visual treatment

## Social Layer

The social layer remains important, but becomes calmer and more integrated.

### Keep

- likes
- favorites
- comments
- author link
- follow button where relevant

### Change

- these elements should no longer compete equally with the main CTA
- they should read as supporting signals around the sequence, not as a toolbar explosion
- author identity should feel a bit more alive and less like a tiny footer attachment

## Card Expansion / Details

The current expand/collapse behavior is functionally useful, but visually abrupt.

The redesign should preserve inline expansion, but refine it so the card feels intentionally layered.

Expanded detail area can contain:

- video preview or embed
- sequence description, if present
- comments thread
- extra actions if needed later

The expansion should feel like opening a richer view of the card, not bolting on another interface under it.

## Search, Sort, and Filters

### Search

The current search by sequence name is too limited for the future shape of the page.

The redesign should prepare for search that can eventually include:

- sequence name
- contained step
- author
- later, style or mood

Copy should be updated to reflect that broader ambition once supported.

### Sort

Keep sort visible, but visually quieter than today.

Expected sorts:

- `Mais curtidas`
- `Mais recentes`

### Quick Filters

The page should prepare for lightweight quick filters beneath the hero or discovery band.

Candidate filters:

- `Curtas`
- `Com giros`
- `Mais curtidas`
- `Favoritas`
- `De quem eu sigo`

Not all need to ship in the first implementation, but the design should reserve a stable place for them.
The first pass can ship with the discovery band alone if that produces a cleaner hierarchy.

## “Minhas” Mode Direction

`Minhas` should not just be “the same page with different records”.

It should feel more personal and shelf-like.

Good directions for v1:

- preserve same hero shell for consistency
- reduce community-style discovery emphasis
- keep the clearer cards
- surface created and saved sequences more intentionally

Possible later enhancements:

- recently viewed
- drafts
- grouped saved sequences

## Interaction Rules

- Clicking a user name or identity block must navigate to that user’s profile.
- `Ver no mapa` is the primary action in every sequence card.
- Secondary actions must not visually overshadow the map action.
- Expansion should not feel required to understand the sequence’s value.
- Empty states must feel encouraging, not bare.

## Visual Language

The visual tone should be:

- warm
- editorial
- premium but not stiff
- more app-like than blog-like

Guidance:

- stronger typographic hierarchy
- more visual grouping at the top
- more deliberate spacing
- less reliance on repeated tiny controls
- subtle card hover and press behavior
- richer card silhouettes without over-rounding or over-framing

This redesign should align with the newer header/navigation polish already being developed elsewhere in the product.

## Technical Direction

This redesign should reuse the existing LiveView route and most of the current server-side behavior where possible.

Likely implementation shape:

- keep `CommunityLive`
- refactor template structure significantly
- add assigns/helpers for discovery sections if needed
- preserve existing like/favorite/follow/comment actions
- avoid introducing unnecessary new backend models for the first pass

The first implementation should prefer:

- presentation-layer refactor
- selective helper extraction
- minimal behavioral churn

## Testing Strategy

We should validate at three levels.

### LiveView tests

Cover:

- community and mine tabs still render correctly
- primary CTA presence
- user profile links still exist
- expand/collapse flow still works
- map navigation links remain present

### Manual browser validation

Desktop:

- hero hierarchy
- discovery band readability
- card rhythm
- expanded details

Mobile:

- touch targets
- card scanability
- no overlapping controls
- `Ver no mapa` remains obvious

### Regression focus

Be especially careful not to break:

- likes
- favorites
- follow buttons
- comments
- video embeds
- navigation to map
- navigation to profile

## Out of Scope

This spec does not include:

- redesign of the map-side sequence panel
- redesign of the sequence generator
- algorithmic changes to sequence ranking
- a new backend taxonomy for sequence types
- draft/publish workflow changes

## Recommended First Implementation Slice

The first implementation should deliver:

1. new hero/top section
2. initial discovery band
3. redesigned community cards
4. refined expansion area
5. clearer visual distinction for `Minhas`

That gives a meaningful product leap without requiring a deep backend rewrite.
