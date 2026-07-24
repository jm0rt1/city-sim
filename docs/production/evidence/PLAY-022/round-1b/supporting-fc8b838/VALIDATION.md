# PLAY-022 Round 1B supporting-sheet validation

- **Candidate product commit:** `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`
- **Expected exact-candidate sources:** 16/16 present and decoded
- **Required source gates missing:** none
- **Generated sheets:** 4/4 at `1800 x 1150`
- **Transforms:** Rec. 709 grayscale plus Machado severity-1 protanopia, deuteranopia, and tritanopia matrices
- **Determinism:** fixed source order, matrices, Lanczos scaling, padding, labels, system font path, PNG compression, and no timestamp/random input
- **Truth boundary:** transforms change pixels only; no state labels, gameplay facts, topology, or source captures were invented

## Coverage

| Evidence class | Exact source coverage |
|---|---|
| Default | normal, selection, valid placement, utilities overlay |
| Compact | normal 900 x 600 content, selection, valid placement, invalid placement, utilities overlay |
| Construction | 0%, 25%, 50%, 75%, 100% at residential coordinate 16,14 |
| Reduce Motion | compact samples A and B |

## Unavailable cross-size variants

These variants were not present in the exact live packet and were not fabricated:

- default invalid-placement frame
- default Reduce Motion A/B frames
- compact 0/25/50/75/100 construction sequence

The requested source mapping itself has no missing gate: each evidence class is represented where an exact source frame exists.

## Output hashes

- `49d290ffab976668ed4eb653653744b3902f4158a087f975a5595585ae5941c2`  `grayscale-contact-sheet.png`
- `04e8dc988d2358b9612496de0353d073af4e4d3aed461a818c32ea96a4773460`  `protanopia-contact-sheet.png`
- `c610d98112ed89c28c2475cfa784a7e71b5f0fded833d64e9601230f274a576e`  `deuteranopia-contact-sheet.png`
- `38a584f312035113aacef2bdc054ea36dd4a80b2caf79908d4253f93b7f27a86`  `tritanopia-contact-sheet.png`
