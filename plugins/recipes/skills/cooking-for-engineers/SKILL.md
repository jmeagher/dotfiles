---
name: cooking-for-engineers
description: Use when formatting, converting, summarizing, or writing out any cooking recipe — especially when the user mentions Cooking for Engineers, tabular recipe notation, recipe summary table, recipe infographic, or wants a recipe as a compact table.
---

# Cooking for Engineers Recipe Format (Tabular Recipe Notation)

## Overview

Render a recipe as a single 2-D table (Michael Chu's format from cookingforengineers.com): ingredients down the left, actions in columns to the right. Time flows left to right — an action right of another happens after it. An action cell vertically spans exactly the rows of the ingredients (or intermediate results) it acts on.

## When NOT to use

Recipes that discard part of an ingredient or reintroduce reserved portions later don't fit the notation. Format the main flow as a table and note the exception in one line below it (part 2 of the response shape).

## Output contract

The response consists of exactly these parts, in order:

1. A fenced code block containing a single ASCII table. The first character of the response is the opening fence.
2. Only if the recipe reserves an ingredient and reintroduces it later: one line below the block noting what the notation can't show.

Table rules:

1. **Title row**: first row is one cell spanning the full width — recipe name, yield, and pan/equipment size.
2. **Ingredient column**: leftmost column, one ingredient per row, in order of first use. Format: quantity, then name, then prep state in parentheses — `150 g sugar`, `75 g butter (melted)`.
3. **Units are grams** whenever the ingredient can be weighed — convert volumes using the table below. Discrete items stay counts (`1 egg`, `3 ripe bananas`). Round to clean numbers (±5% is fine).
4. **Action cells**: each action spans the rows of everything it acts on. Actions in the same column are order-independent (parallelizable). Cell text sits on the top line of its span.
5. **No empty cells**: every cell stretches rightward until that row's next action. A late-joining ingredient's name cell stretches right to meet its first action.
6. **Final cell**: the last column is one cell spanning all ingredient rows — the finishing step, including oven temp in °F and °C and time. Fold preheat and pan-prep notes into this cell (or into the action cell where they're needed), never outside the table.

## Building it

1. Convert all quantities to grams (reference below).
2. List ingredients in order of first use.
3. Turn the instructions into a merge tree: each action consumes ingredients and/or earlier results. Place each action one column right of the latest thing it consumes.
4. Draw the table with stretched cells per the contract.
5. Verify: read each row left to right — it must be that ingredient's complete story. Every `+` junction must align vertically; all lines the same length.

## Gram conversions (per US cup unless noted)

| Ingredient | g/cup | Ingredient | g/cup |
|---|---|---|---|
| all-purpose flour | 120 | butter | 227 (14/tbsp) |
| granulated sugar | 200 | milk, water | 240 |
| brown sugar (packed) | 220 | vegetable oil | 218 (13.5/tbsp) |
| powdered sugar | 120 | honey, syrup | 340 |
| cocoa powder | 84 | rolled oats | 90 |
| chopped nuts | 120 | rice (uncooked) | 200 |

Per teaspoon: salt 6 g, baking soda 5 g, baking powder 4 g, vanilla extract 4 g, ground spices 2 g.

## Example

```
+---------------------------------------------------------------------------------------------+
| Banana Bread (one loaf, 8x4 in pan)                                                         |
+------------------------+--------+--------+-------+-------+-------+--------------------------+
| 3 ripe bananas         | mash   | stir   | mix   | mix   | mix   | pour into buttered       |
+------------------------+--------+        |       |       |       |                          |
| 75 g butter (melted)            |        |       |       |       | loaf pan; bake at        |
+---------------------------------+--------+       |       |       |                          |
| 150 g sugar                              |       |       |       | 350°F (175°C) for        |
+------------------------------------------+       |       |       |                          |
| 1 egg (beaten)                           |       |       |       | 60 min; cool before      |
+------------------------------------------+       |       |       |                          |
| 4 g vanilla extract                      |       |       |       | slicing                  |
+------------------------------------------+-------+       |       |                          |
| 5 g baking soda                                  |       |       |                          |
+--------------------------------------------------+       |       |                          |
| 1 g salt                                         |       |       |                          |
+--------------------------------------------------+-------+       |                          |
| 180 g flour                                              |       |                          |
+----------------------------------------------------------+-------+--------------------------+
```

Reading row 1: mash bananas → stir in butter → mix in sugar/egg/vanilla → mix in soda/salt → mix in flour → pour and bake. Each "mix" spans exactly the rows it combines.

## Common mistakes

| Mistake | Fix |
|---|---|
| Lead-in text, verification notes, or step walkthrough around the table | Response = fence, table, fence, optional exception line |
| Empty filler cells left of a late ingredient's action | Stretch the ingredient cell rightward to its first action |
| Preheat/pan notes as text outside the table | Fold into the final cell |
| Prose walkthrough of the steps after the table | The table stands alone |
| `1 egg (50 g)` or `3 bananas → 350 g` | Discrete items stay counts; grams only for weighed ingredients |
| Misaligned `+` junctions | All lines equal length; junctions in identical character columns |
| One action spanning ingredients it doesn't touch | Span exactly the consumed rows |
