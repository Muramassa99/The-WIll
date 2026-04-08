

## Recommended standard for your game

Use this rule:

* **Normalize input to NFC**
* Measure length by **Unicode extended grapheme clusters**
* Allow **1 to 30 total weighted units**
* Use this weight model:

  * **ASCII printable grapheme**: cost **1**
  * **Non-ASCII normal grapheme**: cost **1**
  * **East Asian Wide / Fullwidth grapheme**: cost **2**
  * **Emoji grapheme**: cost **2**
* Combining marks, variation selectors, and ZWJ do **not** add cost by themselves when they are part of a valid grapheme cluster
* Reject control characters and most invisible formatting characters

This is not a single official Unicode naming standard, but it is built from Unicode-standard pieces:

* NFC normalization is standardized by Unicode Normalization Forms. ([unicode.org][1])
* “User-perceived character” counting is standardized via extended grapheme clusters in Unicode Text Segmentation. ([unicode.org][2])
* Wide/fullwidth handling comes from East Asian Width properties. ([unicode.org][3])
* A real-world example of a weighted counting model is X’s character counting, where some Unicode ranges and emoji count more heavily after normalization. ([docs.x.com][4])

---

# Exact policy spec

## 1. Normalization

Before validation or counting:

* Convert input string to **NFC**

Reason:

* Unicode allows visually equivalent text to be encoded in different ways.
* NFC reduces that inconsistency and makes counting/comparison more stable. ([unicode.org][1])

Rule:

```text
name_normalized = NFC(name_input)
```

Do **not** use NFKC unless you explicitly want compatibility folding, because it can change meaning/styling in ways players may not expect. NFC is the safer default for item names. ([unicode.org][1])

---

## 2. What counts as one “character”

Use **extended grapheme clusters**, not:

* bytes
* UTF-16 code units
* raw Unicode code points

Reason:

* A single user-visible character may be made of multiple code points.
* Unicode’s recommended general-purpose model for user-perceived characters is the **extended grapheme cluster**. ([unicode.org][2])

Examples:

* `é` can be one code point or two code points, but should count as one visible character after normalization. ([unicode.org][1])
* `🇯🇵` is multiple code points but one grapheme cluster. ([unicode.org][2])
* `👨‍👩‍👧‍👦` is multiple code points joined by ZWJ but one grapheme cluster. ([unicode.org][2])

---

## 3. Allowed length

After normalization and segmentation:

* minimum total cost: **1**
* maximum total cost: **30**

Rule:

```text
1 <= sum(grapheme_cost(cluster)) <= 30
```

---

## 4. Exact weighted cost table

This is the exact table I recommend.

## 4A. Base table by grapheme cluster type

| Grapheme cluster type                 | Cost |
| ------------------------------------- | ---: |
| ASCII printable only                  |    1 |
| Non-ASCII ordinary text grapheme      |    1 |
| East Asian Wide or Fullwidth grapheme |    2 |
| Emoji grapheme                        |    2 |

---

## 4B. Definition of each bucket

### A. ASCII printable only → cost 1

A grapheme cluster costs **1** if **every code point** in it is in printable ASCII:

* U+0020 to U+007E

That includes:

* letters A-Z a-z
* digits 0-9
* space
* punctuation
* symbols like `! @ # $ % ^ & * ( ) _ + - = [ ] { } ; : ' " , . / ? < > \ | ~`

Examples:

* `A` = 1
* `7` = 1
* `&` = 1
* ` ` = 1
* `~` = 1

Note:

* You may choose to disallow leading/trailing spaces separately as a style rule.

---

### B. Non-ASCII ordinary text grapheme → cost 1

A grapheme cluster costs **1** if:

* it is not ASCII-only
* it is not classified as emoji
* it does not contain any code point with East Asian Width = `W` or `F`

Examples:

* `é` = 1
* `ñ` = 1
* `Ω` = 1
* `Ж` = 1
* `ع` = 1
* `क` = 1

This is the fairness-friendly default for most international text.

---

### C. East Asian Wide / Fullwidth grapheme → cost 2

A grapheme cluster costs **2** if it contains at least one base character whose East Asian Width is:

* `W` = Wide
* `F` = Fullwidth

Reason:

* Unicode defines East Asian Width as a standard character property related to inherent width. ([unicode.org][3])

Examples often falling here:

* `中`
* `界`
* `あ`
* `ア`
* `한`
* `Ｚ` fullwidth Latin Z
* `９` fullwidth digit 9

Recommended rule:

```text
if any base code point in grapheme has EastAsianWidth in {W, F}:
    cost = 2
```

Do **not** treat `A` = Ambiguous as wide by default. Keep ambiguous characters at cost 1 unless you have a very specific CJK-terminal-style UI reason.

---

### D. Emoji grapheme → cost 2

A grapheme cluster costs **2** if it is an emoji presentation grapheme, including:

* single-code-point emoji
* emoji with variation selectors
* ZWJ emoji sequences
* flag emoji
* skin-tone emoji sequences
* keycap emoji sequences

Examples:

* `😀` = 2
* `⚔️` = 2
* `👍🏽` = 2
* `👨‍👩‍👧‍👦` = 2
* `🇷🇴` = 2
* `1️⃣` = 2

This matches player expectation better than charging by code point count.

---

## 5. Zero-cost internal code points inside a valid grapheme

These should **not** add extra cost when they are part of a valid grapheme cluster:

* combining marks
* variation selectors
* zero-width joiner used inside a valid emoji/text sequence

Reason:

* They are structural pieces of the grapheme, not standalone user-facing characters. Unicode grapheme segmentation is built for exactly this behavior. ([unicode.org][2])

Examples:

* `e + ◌́` should still count with the grapheme’s final bucket, not as separate extra characters
* `👩 + ZWJ + 🔬` should count as one emoji grapheme, cost 2

---

## 6. Reject list

These should be rejected entirely.

## 6A. Control characters

Reject all control characters, including:

* C0 controls: U+0000–U+001F
* DEL: U+007F
* C1 controls: U+0080–U+009F

Examples:

* newline
* tab
* carriage return
* null

These are not suitable in player-facing item names.

---

## 6B. Standalone combining marks

Reject a name if any grapheme cluster starts with a combining mark and does not form a valid intended grapheme.

Reason:

* Visually unstable
* Easy abuse case
* Bad UX

---

## 6C. Most invisible formatting characters

Reject these by default:

* Zero Width Space `U+200B`
* Zero Width Non-Joiner `U+200C`
* Zero Width Joiner `U+200D` unless it is part of a valid grapheme sequence you explicitly accept
* Word Joiner `U+2060`
* Soft Hyphen `U+00AD`
* Directional formatting controls
* Isolates/embeddings/overrides used for bidi trickery

Why:

* They allow invisible spoofing, weird rendering, and moderation headaches.

Unicode supports many formatting controls, but for game item names they are usually more trouble than value. The Unicode Character Database defines these kinds of character properties and categories; this is exactly the kind of property-based filtering it supports. ([unicode.org][5])

---

## 6D. Unassigned / private-use / surrogate code points

Reject:

* unassigned code points
* surrogate code points
* private-use code points

These should not appear in stable player-visible names.

---

# Precedence rules

Use this exact order for each grapheme cluster:

```text
1. If cluster contains forbidden code points -> reject whole name
2. Else if cluster is emoji grapheme -> cost 2
3. Else if cluster contains base code point with EastAsianWidth W or F -> cost 2
4. Else -> cost 1
```

This matters because some emoji-related characters may also have width-related behavior. Emoji should win first.

---

# Full validation algorithm

Use this as your source-of-truth behavior spec.

## Input pipeline

1. Read raw player input
2. Normalize to NFC
3. Split into extended grapheme clusters
4. For each grapheme cluster:

   * check forbidden content
   * assign cost
5. Sum total cost
6. Accept only if total is between 1 and 30 inclusive

---

# Pseudocode spec

```pseudo
function validate_item_name(input_string):
    if input_string is null:
        return INVALID("Name is missing")

    s = NFC_NORMALIZE(input_string)

    graphemes = SPLIT_EXTENDED_GRAPHEME_CLUSTERS(s)

    if graphemes.count == 0:
        return INVALID("Name must contain at least 1 character")

    total_cost = 0

    for cluster in graphemes:
        if cluster_contains_forbidden_code_point(cluster):
            return INVALID("Name contains forbidden characters")

        if cluster_is_invalid_standalone_combining_sequence(cluster):
            return INVALID("Name contains invalid combining sequence")

        if is_emoji_grapheme(cluster):
            total_cost += 2
            continue

        if cluster_has_east_asian_width_W_or_F(cluster):
            total_cost += 2
            continue

        total_cost += 1

        if total_cost > 30:
            return INVALID("Name is too long")

    if total_cost < 1:
        return INVALID("Name must contain at least 1 character")

    return VALID(
        normalized_name = s,
        total_cost = total_cost,
        grapheme_count = graphemes.count
    )
```

---

# Exact forbidden categories to hand to Copilot

Tell the agent to reject code points with these properties:

* General Category = `Cc` control
* General Category = `Cs` surrogate
* General Category = `Co` private use
* General Category = `Cn` unassigned

Also reject these format/control-style cases unless explicitly whitelisted:

* most `Cf` format characters
* especially:

  * U+200B ZERO WIDTH SPACE
  * U+200C ZERO WIDTH NON-JOINER
  * U+200D ZERO WIDTH JOINER except when part of valid accepted grapheme
  * U+2060 WORD JOINER
  * U+00AD SOFT HYPHEN
  * bidi overrides / embeddings / isolates

That is stricter than Unicode itself, but good for games.

---

# Examples table

Here is a direct example suite.

## Valid examples

| Name          | Grapheme view            | Cost |
| ------------- | ------------------------ | ---: |
| `Sword`       | 6 ASCII graphemes        |    6 |
| `Sword+1`     | 7 ASCII graphemes        |    7 |
| `Épée`        | `É` + `p` + `é` + `e`    |    4 |
| `Katana 中`    | ASCII + space + wide CJK |    9 |
| `🔥Blade`     | emoji + ASCII            |    7 |
| `👨‍👩‍👧‍👦` | 1 emoji grapheme         |    2 |
| `🇷🇴`        | 1 flag grapheme          |    2 |
| `ＡＢＣ`         | 3 fullwidth graphemes    |    6 |

## Invalid examples

| Name                                | Why invalid                |
| ----------------------------------- | -------------------------- |
| `` empty string                     | below minimum              |
| `\nSword`                           | contains control character |
| `Blade\u200B`                       | contains zero-width space  |
| standalone combining mark sequence  | invalid combining use      |
| string with total weighted cost 31+ | exceeds cap                |

---

# Recommended UI behavior

Show both:

* visible name
* current weighted cost

Example:

```text
Name: 🔥Blade中
Cost: 9 / 30
```

This reduces confusion immediately.

---

# Recommendation on spaces and punctuation

Because you said “ASCII including special characters,” I recommend:

Allowed:

* ASCII printable `U+0020` to `U+007E`

Extra style rules worth adding:

* no leading spaces
* no trailing spaces
* no repeated internal spaces beyond 1 in a row
* optionally ban some punctuation runs like `@@@@@@`

These are not Unicode requirements, just moderation/UX rules.

---

# What to tell Copilot explicitly

Paste this:

```text
Implement item-name validation with these exact rules:

1. Normalize input using Unicode NFC.
2. Split the normalized string into Unicode extended grapheme clusters.
3. Reject the name if any grapheme contains forbidden code points:
   - General Category Cc, Cs, Co, Cn
   - most Cf format characters
   - especially U+200B, U+200C, U+2060, U+00AD
   - reject U+200D unless it is part of a valid emoji/text grapheme sequence we accept
   - reject bidi override/embedding/isolate formatting characters
4. Weighted length:
   - emoji grapheme = cost 2
   - grapheme containing any base code point with EastAsianWidth W or F = cost 2
   - all other valid grapheme clusters = cost 1
5. Combining marks, variation selectors, and valid ZWJ internals do not add extra cost beyond their grapheme’s bucket.
6. Accept only names with total weighted cost between 1 and 30 inclusive.
7. Return:
   - normalized_name
   - total_cost
   - grapheme_count
   - validity
   - rejection_reason
8. Also add style validation:
   - trim is not automatic
   - reject leading/trailing spaces
   - reject consecutive spaces if more than 1
```

---

# Final recommendation

For your the WIll, this is the safest production choice:

* **NFC normalized**
* **extended grapheme cluster counting**
* **weighted cap 1–30**
* **ASCII/non-ASCII ordinary text = 1**
* **emoji and East Asian Wide/Fullwidth = 2**
* **reject invisible/control/spoof-prone characters**


[1]: https://unicode.org/reports/tr15/?utm_source=chatgpt.com "UAX #15: Unicode Normalization Forms"
[2]: https://www.unicode.org/reports/tr29/?utm_source=chatgpt.com "UAX #29: Unicode Text Segmentation"
[3]: https://www.unicode.org/reports/tr11/?utm_source=chatgpt.com "UAX #11: East Asian Width"
[4]: https://docs.x.com/fundamentals/counting-characters?utm_source=chatgpt.com "Counting Characters - X - X Developer Platform - Twitter"
[5]: https://www.unicode.org/reports/tr44/?utm_source=chatgpt.com "UAX #44: Unicode Character Database"
