# Palet Pelaminan

A simple web page (a single `index.html`, no install needed) for matching wedding colours and scoring whether they all go together.

The app's interface is in Indonesian.

## How to use

Open `index.html` directly in a browser.

1. Pick an element on the left: stage & decor (*panggung & dekorasi*), flowers (*bunga*), bride's gown (*gaun pengantin wanita*), groom's attire (*busana pengantin pria*), wedding gift trays (*seserahan*), family uniforms (*seragam keluarga*), bridesmaids (*bridesmaid / pagar ayu*), and helpers / ushers (*panitia / among tamu*). You can add your own elements, such as invitations or souvenirs.
2. Set its colour with the triangle picker:
   - **Ring + triangle** (*Cincin + segitiga*): the ring picks the hue, and the triangle mixes that pure hue with white and black.
   - **RGB triangle** (*Segitiga RGB*): each corner is Red, Green, or Blue, plus a brightness (V) slider.
   - You can also use the R/G/B sliders, a hex code, or the popular wedding colour swatches.
3. The stage preview draws the scene in your chosen colours. It shows a layered *gebyok* backdrop, pillars, drapes and floral arrangements. It also shows the bride and groom, parents in *beskap* and *kebaya*, bridesmaids, the *seserahan* tables, and the ushers. Click any part of the scene to select that element.
4. Check the score (0–100) and each element's status: **Match**, **Hampir** (close), or **Tidak match** (no match). The suggestions panel proposes replacement colours that raise the score.

## How scoring works

| Criterion | Weight | What it checks |
|---|---|---|
| Hue harmony | 40% | The hues of coloured (non-neutral) items are fitted to a monochromatic, analogous, complementary, split-complementary, or triadic pattern. Neutrals (white, cream, grey, black) always fit. |
| Couple visible on stage | 20% | Colour difference (ΔE, CIELAB) between the gown / groom's attire and the stage; ideal ≥ 20. |
| Bride stands out | 10% | The gown should differ from the family, bridesmaid, and helper uniforms; ideal ΔE ≥ 14. |
| Balance | 15% | At most 2 vivid colours, and a light-to-dark range of at least 30. |
| No clashing colours | 15% | Flags colours that are almost but not quite the same (ΔE 2–7, e.g. ivory vs. pure white). Also flags complementary pairs that are both very bright. |

The total score is a weighted geometric mean, so one very poor criterion pulls the score down noticeably.

Score labels: ≥85 *sangat serasi* (very harmonious), ≥70 *serasi* (harmonious), ≥55 *cukup serasi* (fairly harmonious), ≥40 *kurang serasi* (not very harmonious), and below that *bertabrakan* (clashing).

The most recent palette is saved automatically in the browser (localStorage).
