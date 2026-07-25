# PLAY-070 AX and Action Ledger

All observations came from the exact staged
`63eb5086f79a294d497190d7ff880aefb9c079ac` app and isolated copies of
accepted frozen fixtures.

| Journey | Input | Before | Observed route/result | Focus / AX |
| --- | --- | --- | --- | --- |
| Current terminal, regular | `Command-O` | Current Regional Capital quicksave | Blocking terminal opened | Modal label `Regional Capital victory`; CTA `victory.start-new-region` focused |
| Current terminal containment | `Escape` | Regional terminal visible | Terminal remained visible; no replay or underlying action | Same Regional modal and focused CTA remained |
| Current replay | Real pointer CTA | Regional terminal visible | One fresh authored region; `A fresh region is ready` | Terminal removed; city map focused |
| Current replay | `Return` | Regional terminal CTA focused | One fresh authored region | Terminal removed; city map focused |
| Current replay | `Space` | Regional terminal CTA focused | One fresh authored region | Terminal removed; city map focused |
| Current replay | File > New Region | Regional terminal visible | One fresh authored region | Terminal removed; city map focused |
| Guide parity | `Command-/`, query `new region`, `Return` | Fresh playing city | One available `New Region` result executed existing store intent | Guide closed; city map focused |
| Current terminal, compact | `Command-O` | 900 x 600 content, Reduce Motion proof | Complete Regional result and both actions visible | Regional modal; CTA focused and unclipped |
| Current compact replay | Real pointer CTA | Compact Regional terminal | One fresh authored region | Terminal removed; city map focused |
| Legacy terminal, regular | `Command-O` | Authentic missing-`secondAct` Charter quicksave | Blocking legacy terminal opened | Modal label `Town Charter victory`; CTA focused |
| Regional mandate diagnosis | Real pointer Tax policy | Accepted current midpoint | Existing Finances/Tax Policy details opened | Details AX tree exposed Tax Policy slider and decision support |
| Regional mandate remedy | Act menu, `Down`, `Down`, `Return` | Existing two-action Regional mandate menu | Existing Park tool selected exactly once | `Park tool selected`; Park selected; city map focused |
| Remedy cancellation | `Escape` | Park tool selected | Existing tool cancelled to Inspect | Park selection removed; Inspect selected; city map focused |

## Terminal AX identity

### Current

- Modal: `Regional Capital victory`
- Details begin:
  `Regional Capital Recognized. New Arcadia Became a Regional Capital.`
- Story: `Your Regional Capital Story`
- CTA: `Start a New Region`
- CTA help: `Starts one fresh authored city and closes this result`
- Initial focused element: `victory.start-new-region`

### Authentic legacy

- Modal: `Town Charter victory`
- Details begin:
  `Town Charter Secured. New Arcadia Earned Its Town Charter.`
- Story: `Your Charter Story`
- CTA and focus contract are unchanged.

## Regional command AX identity

- Priority container:
  `City priority: Regional Capital mandate`
- Value:
  `MANDATE · 16 DAYS. Regional mandate arrives in 16 days`
- Diagnostic button:
  `Tax policy & cashflow`
- Action menu:
  `Act on Regional Capital mandate`
- Menu value:
  `2 available routes`
- Responses:
  - `Review tax policy`
  - `Build a park`

The action responses use existing catalog commands and preserve their existing
AX help. No independent action or availability truth was introduced.
