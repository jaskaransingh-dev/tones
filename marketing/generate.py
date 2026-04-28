#!/usr/bin/env python3
"""Generate Tones App Store + Product Hunt marketing SVGs.

Run from anywhere:  python3 marketing/generate.py
Optional: convert SVG -> PNG with `rsvg-convert` (brew install librsvg)
or open the SVG in any browser and screenshot at 100% zoom.
"""

from pathlib import Path

ROOT = Path(__file__).parent
APPSTORE = ROOT / "appstore"
PH = ROOT / "producthunt"
APPSTORE.mkdir(exist_ok=True)
PH.mkdir(exist_ok=True)

# ---------- Palette ----------
CREAM   = "#FCF7ED"
SAND    = "#F4ECDC"
DARK    = "#1A1714"
BROWN   = "#5C4D43"
CORAL   = "#FB6E5C"
PEACH   = "#FFD9C9"
GREEN   = "#29B86B"
SOFTGRN = "#4DC78A"
WHITE   = "#FFFFFF"

FONT = ('-apple-system, "SF Pro Display", "Helvetica Neue", '
        'system-ui, sans-serif')

# ---------- Helpers ----------
def svg(w, h, body, bg=CREAM):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
<defs>
  <radialGradient id="warmwash" cx="20%" cy="0%" r="80%">
    <stop offset="0%" stop-color="{PEACH}" stop-opacity="0.45"/>
    <stop offset="60%" stop-color="{CREAM}" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="phoneShadow" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#000" stop-opacity="0.06"/>
    <stop offset="100%" stop-color="#000" stop-opacity="0.18"/>
  </linearGradient>
</defs>
<rect width="{w}" height="{h}" fill="{bg}"/>
<rect width="{w}" height="{h}" fill="url(#warmwash)"/>
{body}
</svg>'''


def text(x, y, content, size=72, weight=400, color=DARK, anchor="middle",
         tracking=0, family=FONT):
    ls = f'letter-spacing="{tracking}"' if tracking else ""
    return (f'<text x="{x}" y="{y}" font-family=\'{family}\' '
            f'font-size="{size}" font-weight="{weight}" fill="{color}" '
            f'text-anchor="{anchor}" {ls}>{content}</text>')


def phone_frame(x, y, w, h, body):
    """Render an iPhone-shaped frame with rounded screen and content body."""
    r = 90  # outer radius
    inner = f'''
    <rect x="{x-12}" y="{y-12}" width="{w+24}" height="{h+24}" rx="{r+10}" ry="{r+10}" fill="url(#phoneShadow)" filter="blur(28px)"/>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" fill="{DARK}"/>
    <rect x="{x+10}" y="{y+10}" width="{w-20}" height="{h-20}" rx="{r-10}" ry="{r-10}" fill="{CREAM}"/>
    <clipPath id="screenClip-{x}-{y}"><rect x="{x+10}" y="{y+10}" width="{w-20}" height="{h-20}" rx="{r-10}" ry="{r-10}"/></clipPath>
    <g clip-path="url(#screenClip-{x}-{y})">{body}</g>
    '''
    return inner


def avatar(cx, cy, r, color=PEACH, initial=None, initial_color=DARK):
    out = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"/>'
    if initial:
        out += text(cx, cy + r*0.32, initial, size=int(r*1.2), weight=500,
                    color=initial_color)
    return out


def wave_bars(cx, cy, count=22, max_h=120, color=GREEN, seed=0):
    import math
    out = ""
    bw = 14
    gap = 10
    total = count * (bw + gap) - gap
    start = cx - total / 2
    for i in range(count):
        # pseudo-shape
        h = (math.sin(i * 0.62 + seed) + 1.4) * max_h * 0.4 + 12
        h = min(h, max_h)
        x = start + i * (bw + gap)
        y = cy - h / 2
        out += (f'<rect x="{x}" y="{y}" width="{bw}" height="{h}" rx="6" '
                f'fill="{color}" opacity="{0.6 + 0.4*((i%5)/5)}"/>')
    return out


# ---------- App Store Screen Bodies (rendered inside phone frame) ----------

def screen_home(x, y, w, h):
    """Home screen: friend strip + tone list."""
    cx = x + w / 2
    parts = []
    # status bar
    parts.append(f'<rect x="{x+10}" y="{y+10}" width="{w-20}" height="80" fill="{CREAM}"/>')
    parts.append(text(cx, y+135, "tones", size=44, weight=400, tracking=10, color=DARK))
    # friends label
    parts.append(text(x+90, y+240, "FRIENDS", size=26, weight=500, tracking=8,
                      color=BROWN, anchor="start"))
    # friends row
    fx = x + 90
    fy = y + 320
    initials = [("+", PEACH, CORAL), ("M", PEACH, DARK), ("A", "#E5DAC5", DARK),
                ("J", PEACH, DARK), ("K", "#E5DAC5", DARK)]
    for i, (ini, col, ic) in enumerate(initials):
        parts.append(avatar(fx + 50 + i*140, fy, 56, col, ini, ic))
        parts.append(text(fx + 50 + i*140, fy+108, ["add","mom","alex","jas","ky"][i],
                          size=22, weight=500, color=BROWN))
    # tones label
    parts.append(text(x+90, y+520, "TONES", size=26, weight=500, tracking=8,
                      color=BROWN, anchor="start"))
    # rows
    rows = [
        ("M", "mom", "2 new tones", True),
        ("A", "alex", "8 tones", False),
        ("J", "jas", "1 new tone", True),
        ("K", "ky", "3 tones", False),
    ]
    ry = y + 590
    for ini, name, sub, unread in rows:
        bg = f'rgba(41,184,107,0.08)' if unread else 'rgba(255,255,255,0.7)'
        parts.append(f'<rect x="{x+60}" y="{ry}" width="{w-120}" height="120" rx="28" fill="{bg}"/>')
        parts.append(avatar(x+130, ry+60, 38, PEACH, ini))
        parts.append(text(x+200, ry+58, name, size=32, weight=500, color=DARK, anchor="start"))
        parts.append(text(x+200, ry+96, sub, size=22, weight=400,
                          color=GREEN if unread else BROWN, anchor="start"))
        if unread:
            parts.append(f'<circle cx="{x+w-130}" cy="{ry+60}" r="9" fill="{GREEN}"/>')
        ry += 138
    # mic FAB
    parts.append(f'<circle cx="{cx}" cy="{y+h-180}" r="62" fill="{GREEN}"/>')
    parts.append(f'<circle cx="{cx}" cy="{y+h-180}" r="92" fill="{GREEN}" opacity="0.18"/>')
    parts.append(text(cx, y+h-167, "🎙", size=44))
    return "\n".join(parts)


def screen_record(x, y, w, h):
    cx = x + w/2
    cy = y + h/2 - 120
    parts = []
    # pulse rings
    for r, op in [(280, 0.06), (210, 0.10), (160, 0.16)]:
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{GREEN}" opacity="{op}"/>')
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="115" fill="{GREEN}"/>')
    parts.append(text(cx, cy+22, "🎙", size=70))
    # waveform
    parts.append(wave_bars(cx, cy+260, count=24, max_h=120, color=GREEN, seed=0.2))
    # caption
    parts.append(text(cx, cy+440, "TAP TO SEND", size=28, weight=400, tracking=10, color=BROWN))
    # hangup
    parts.append(f'<circle cx="{cx}" cy="{y+h-180}" r="60" fill="{CORAL}"/>')
    parts.append(text(cx, y+h-168, "✕", size=44, color=WHITE))
    return "\n".join(parts)


def screen_tape(x, y, w, h):
    cx = x + w/2
    parts = []
    # avatar with halo
    parts.append(f'<circle cx="{cx}" cy="{y+260}" r="125" fill="{PEACH}" opacity="0.4"/>')
    parts.append(avatar(cx, y+260, 88, PEACH, "M"))
    parts.append(text(cx, y+420, "@mom", size=22, weight=300, tracking=8, color=BROWN))
    # tape segments
    py = y+520
    parts.append(f'<rect x="{x+90}" y="{py}" width="{w-180}" height="220" rx="48" fill="{PEACH}" opacity="0.55"/>')
    # active waveform
    parts.append(wave_bars(cx, py+90, count=22, max_h=80, color=CORAL, seed=1.1))
    parts.append(text(cx, py+185, "12", size=92, weight=200, color=DARK, family='"SF Mono", monospace'))
    # connector
    py += 260
    parts.append(f'<circle cx="{cx}" cy="{py}" r="3" fill="{CORAL}" opacity="0.4"/>')
    parts.append(f'<rect x="{cx-1}" y="{py+8}" width="2" height="14" fill="{CORAL}" opacity="0.3"/>')
    parts.append(f'<circle cx="{cx}" cy="{py+30}" r="4" fill="{CORAL}" opacity="0.5"/>')
    # done segment
    py += 60
    parts.append(f'<rect x="{x+250}" y="{py}" width="{w-500}" height="64" rx="32" fill="{PEACH}" opacity="0.4"/>')
    parts.append(text(cx-30, py+42, "✓ 8s", size=24, weight=400, color=BROWN))
    # counter
    parts.append(text(cx, py+150, "2 / 3", size=22, weight=300, tracking=8, color=BROWN))
    # hangup
    parts.append(f'<circle cx="{cx}" cy="{y+h-180}" r="60" fill="{CORAL}"/>')
    parts.append(text(cx, y+h-168, "✕", size=44, color=WHITE))
    return "\n".join(parts)


def screen_chat(x, y, w, h):
    cx = x + w/2
    parts = []
    parts.append(text(cx, y+100, "@alex", size=34, weight=400, color=DARK))
    # bubbles
    bubbles = [
        ("them", "M", "12s", True),
        ("me",   None, "8s", False),
        ("them", "M", "5s", False),
        ("me",   None, "20s", False),
        ("them", "M", "9s", True),
    ]
    by = y + 180
    for who, ini, dur, unread in bubbles:
        if who == "them":
            bx = x + 90
            bg = WHITE
            parts.append(f'<rect x="{bx}" y="{by}" width="430" height="120" rx="40" fill="{bg}"/>')
            parts.append(avatar(bx+62, by+60, 30, PEACH, ini))
            # progress line
            parts.append(f'<rect x="{bx+108}" y="{by+58}" width="240" height="3" rx="2" fill="{PEACH}"/>')
            parts.append(f'<rect x="{bx+108}" y="{by+58}" width="80" height="3" rx="2" fill="{GREEN}"/>')
            parts.append(text(bx+108, by+92, dur, size=22, weight=300, color=BROWN, anchor="start"))
            if unread:
                parts.append(f'<circle cx="{bx+115}" cy="{by+88}" r="6" fill="{GREEN}"/>')
        else:
            bx = x + w - 90 - 430
            parts.append(f'<rect x="{bx}" y="{by}" width="430" height="120" rx="40" fill="{PEACH}" opacity="0.6"/>')
            parts.append(avatar(bx+430-62, by+60, 30, PEACH, "Y", CORAL))
            parts.append(f'<rect x="{bx+82}" y="{by+58}" width="240" height="3" rx="2" fill="{PEACH}"/>')
            parts.append(f'<rect x="{bx+82}" y="{by+58}" width="160" height="3" rx="2" fill="{CORAL}"/>')
            parts.append(text(bx+322, by+92, dur, size=22, weight=300, color=BROWN, anchor="end"))
        by += 142
    # mic FAB
    parts.append(f'<circle cx="{cx}" cy="{y+h-180}" r="62" fill="{GREEN}"/>')
    parts.append(f'<circle cx="{cx}" cy="{y+h-180}" r="92" fill="{GREEN}" opacity="0.18"/>')
    parts.append(text(cx, y+h-165, "🎙", size=44))
    return "\n".join(parts)


def screen_friends(x, y, w, h):
    cx = x + w/2
    parts = []
    parts.append(text(cx, y+130, "add a friend", size=42, weight=300, tracking=4, color=DARK))
    # input
    parts.append(f'<rect x="{x+90}" y="{y+260}" width="{w-180}" height="120" rx="36" fill="{WHITE}"/>')
    parts.append(text(cx, y+335, "@username", size=34, weight=400, color=BROWN))
    # button
    parts.append(f'<rect x="{x+90}" y="{y+420}" width="{w-180}" height="120" rx="36" fill="{CORAL}"/>')
    parts.append(text(cx, y+495, "add", size=34, weight=600, color=WHITE))
    # divider
    parts.append(f'<rect x="{x+200}" y="{y+620}" width="{w-400}" height="1" fill="{BROWN}" opacity="0.15"/>')
    # share row
    parts.append(f'<rect x="{x+90}" y="{y+670}" width="{w-180}" height="100" rx="28" fill="{WHITE}" opacity="0.85"/>')
    parts.append(text(cx, y+730, "share your link", size=28, weight=500, color=DARK))
    # contacts row
    parts.append(f'<rect x="{x+90}" y="{y+790}" width="{w-180}" height="100" rx="28" fill="{WHITE}" opacity="0.85"/>')
    parts.append(text(cx, y+850, "invite from contacts", size=28, weight=500, color=DARK))
    return "\n".join(parts)


def screen_group(x, y, w, h):
    cx = x + w/2
    parts = []
    # header
    parts.append(text(cx, y+130, "new group", size=42, weight=300, tracking=4, color=DARK))
    # group avatar
    parts.append(f'<circle cx="{cx}" cy="{y+320}" r="80" fill="{CORAL}"/>')
    parts.append(text(cx, y+360, "T", size=64, weight=300, color=WHITE))
    parts.append(text(cx, y+430, "tap to change", size=22, weight=400, color=BROWN))
    # name input
    parts.append(f'<rect x="{x+90}" y="{y+500}" width="{w-180}" height="120" rx="36" fill="{WHITE}"/>')
    parts.append(text(cx, y+575, "group name (optional)", size=34, weight=400, color=BROWN))
    # members section
    parts.append(text(x+90, y+700, "add members", size=26, weight=500, tracking=8, color=BROWN, anchor="start"))
    # member slots
    for i in range(4):
        mx = x + 130 + i * 160
        parts.append(f'<circle cx="{mx}" cy="{y+800}" r="50" fill="{PEACH}"/>')
        parts.append(text(mx, y+795, "+", size=32, weight=300, color=BROWN))
    return "\n".join(parts)


def screen_welcome(x, y, w, h):
    cx = x + w/2
    parts = []
    # logo circle
    parts.append(f'<circle cx="{cx}" cy="{y+300}" r="90" fill="{CORAL}"/>')
    parts.append(f'<circle cx="{cx}" cy="{y+300}" r="70" fill="{WHITE}"/>')
    # tones text
    parts.append(text(cx, y+450, "tones", size=60, weight=200, tracking=10, color=DARK))
    parts.append(text(cx, y+490, "voice messages, nothing else", size=24, weight=300, color=BROWN))
    # Apple button placeholder
    parts.append(f'<rect x="{x+180}" y="{y+600}" width="{w-360}" height="100" rx="24" fill="{DARK}"/>')
    parts.append(text(cx, y+670, "Sign in with Apple", size=28, weight=400, color=WHITE))
    # divider
    parts.append(text(cx, y+730, "or try Tones", size=20, weight=300, color=BROWN))
    # username input + button
    parts.append(f'<rect x="{x+180}" y="{y+780}" width="{w-440}" height="80" rx="20" fill="{WHITE}"/>')
    parts.append(text(cx, y+820, "username", size=24, weight=300, color=BROWN))
    parts.append(f'<rect x="{x+w-340}" y="{y+785}" width="140" height="70" rx="16" fill="{CORAL}"/>')
    parts.append(text(cx, y+820, "go", size=24, weight=600, color=WHITE))
    return "\n".join(parts)


def screen_logo(x, y, w, h):
    cx = x + w/2
    parts = []
    parts.append(f'<rect x="{cx-160}" y="{y+h/2-280}" width="320" height="320" rx="80" fill="{CORAL}"/>')
    # tiny mic shape
    parts.append(f'<rect x="{cx-50}" y="{y+h/2-220}" width="100" height="160" rx="50" fill="{WHITE}"/>')
    parts.append(f'<rect x="{cx-3}" y="{y+h/2-50}" width="6" height="60" fill="{WHITE}"/>')
    parts.append(f'<rect x="{cx-50}" y="{y+h/2+10}" width="100" height="6" rx="3" fill="{WHITE}"/>')
    parts.append(text(cx, y+h/2+120, "tones", size=82, weight=300, tracking=14, color=DARK))
    parts.append(text(cx, y+h/2+170, "voice messages, nothing else.", size=28, weight=300, color=BROWN))
    return "\n".join(parts)


# ---------- App Store screenshot generator (6 for iPhone) ----------

def make_appstore(filename, headline_lines, sub, body_fn,
                   W=1290, H=2796):
    px, py, pw, ph_ = 130, 720, W-260, 1820
    body = phone_frame(px, py, pw, ph_, body_fn(px, py, pw, ph_))
    # headline
    head = ""
    line_y = 240
    for i, line in enumerate(headline_lines):
        col = CORAL if i == len(headline_lines)-1 and len(headline_lines)>1 else DARK
        head += text(W/2, line_y + i*150, line, size=132, weight=500, color=col)
    sub_t = text(W/2, line_y + len(headline_lines)*150 + 26, sub,
                 size=42, weight=300, color=BROWN)
    page = f"{head}{sub_t}{body}"
    out = svg(W, H, page)
    (APPSTORE / filename).write_text(out)

# ---------- Generate App Store (6) ----------

make_appstore(
    "01_hero.svg",
    ["tones", "voice messages."],
    "no typing. just talking.",
    screen_welcome,
)

make_appstore(
    "02_tap_to_talk.svg",
    ["tap.", "talk.", "send."],
    "instant voice. no buttons.",
    screen_record,
)

make_appstore(
    "03_auto_play.svg",
    ["auto-plays."],
    "open → listen → reply.",
    screen_tape,
)

make_appstore(
    "04_inbox.svg",
    ["your friends.", "in voice."],
    "no feeds. just tones.",
    screen_home,
)

make_appstore(
    "05_chat.svg",
    ["threads", "of voice."],
    "share a tone back.",
    screen_chat,
)

make_appstore(
    "06_groups.svg",
    ["group tones."],
    "up to 32 friends.",
    screen_group,
)

make_appstore(
    "02_tap_to_talk.svg",
    ["tap.", "talk.", "tone."],
    "live waveform. instant send.",
    screen_record,
)

make_appstore(
    "03_auto_play.svg",
    ["auto-plays your tones."],
    "open a chat → it plays → reply.",
    screen_tape,
)

make_appstore(
    "04_inbox.svg",
    ["your inbox,", "in voice."],
    "no feeds. no likes. just friends.",
    screen_home,
)

make_appstore(
    "05_chat.svg",
    ["real conversations."],
    "share a tone. start a thread.",
    screen_chat,
)


# ---------- Product Hunt images ----------
# Product Hunt gallery: 1270x760 (16:9-ish). Thumbnail: 240x240.
# We make 6 horizontal images, plus 1 thumbnail.

PHW, PHH = 1270, 760

def make_ph(filename, body):
    out = svg(PHW, PHH, body)
    (PH / filename).write_text(out)


# 1. Cover
def ph_cover():
    cx = PHW/2
    cy = PHH/2
    parts = []
    parts.append(f'<rect x="{cx-90}" y="{cy-180}" width="180" height="180" rx="44" fill="{CORAL}"/>')
    parts.append(f'<rect x="{cx-32}" y="{cy-150}" width="64" height="100" rx="32" fill="{WHITE}"/>')
    parts.append(f'<rect x="{cx-3}" y="{cy-50}" width="6" height="36" fill="{WHITE}"/>')
    parts.append(f'<rect x="{cx-32}" y="{cy-14}" width="64" height="6" rx="3" fill="{WHITE}"/>')
    parts.append(text(cx, cy+80, "tones", size=120, weight=300, tracking=18, color=DARK))
    parts.append(text(cx, cy+135, "voice messages, nothing else.", size=32, weight=300, color=BROWN))
    parts.append(text(cx, PHH-50, "iOS · launching today on Product Hunt", size=20, weight=400, tracking=4, color=BROWN))
    return "\n".join(parts)

make_ph("01_cover.svg", ph_cover())


# 2. Problem / pitch
def ph_pitch():
    parts = []
    parts.append(text(PHW/2, 200, "texting is exhausting.", size=82, weight=500, color=DARK))
    parts.append(text(PHW/2, 290, "voice notes are scattered.", size=82, weight=500, color=DARK))
    parts.append(text(PHW/2, 460, "tones is just voice.", size=72, weight=500, color=CORAL))
    parts.append(text(PHW/2, 540, "every message plays automatically.", size=28, weight=300, color=BROWN))
    parts.append(text(PHW/2, 580, "every reply is one tap.", size=28, weight=300, color=BROWN))
    return "\n".join(parts)

make_ph("02_pitch.svg", ph_pitch())


# 3. Feature grid
def ph_features():
    parts = [text(PHW/2, 130, "what's inside", size=56, weight=500, color=DARK)]
    feats = [
        ("auto-play", "open a chat → unheard tones play in order"),
        ("tap to send", "no record button. tap once. talk. tap to send."),
        ("groups", "shared voice threads with up to 32 friends"),
        ("on-device", "audio stored locally. no scrolling feed."),
    ]
    cols = 2
    cw = (PHW - 240) / cols
    rh = 220
    for i, (t, d) in enumerate(feats):
        col = i % cols
        row = i // cols
        x = 120 + col * cw
        y = 220 + row * rh
        parts.append(f'<rect x="{x}" y="{y}" width="{cw-40}" height="{rh-40}" rx="24" fill="{WHITE}" opacity="0.7"/>')
        parts.append(text(x+40, y+70, t, size=42, weight=500, color=DARK, anchor="start"))
        parts.append(text(x+40, y+115, d, size=24, weight=300, color=BROWN, anchor="start"))
    return "\n".join(parts)

make_ph("03_features.svg", ph_features())


# 4. Mockup row
def ph_mockup_row(screen_fn, headline):
    parts = [text(PHW/2, 110, headline, size=64, weight=500, color=DARK)]
    # phone (smaller for landscape)
    pw = 320
    ph_ = 660
    px = PHW/2 - pw/2
    py = 120
    # scale screen content visually
    parts.append(phone_frame(px, py, pw, ph_, screen_fn(px, py, pw, ph_)))
    return "\n".join(parts)

make_ph("04_record.svg", ph_mockup_row(screen_record, "tap to talk."))
make_ph("05_tape.svg",   ph_mockup_row(screen_tape,   "auto-plays unheard."))
make_ph("06_inbox.svg",  ph_mockup_row(screen_home,   "your inbox, in voice."))


# Thumbnail 240x240
def ph_thumb():
    return f'''
<rect x="60" y="60" width="120" height="120" rx="30" fill="{CORAL}"/>
<rect x="100" y="80" width="40" height="68" rx="20" fill="{WHITE}"/>
<rect x="118" y="148" width="4" height="22" fill="{WHITE}"/>
<rect x="100" y="170" width="40" height="4" rx="2" fill="{WHITE}"/>
'''
out = svg(240, 240, ph_thumb())
(PH / "thumbnail.svg").write_text(out)


print("Generated:")
for f in sorted(APPSTORE.glob("*.svg")):
    print(" ", f.relative_to(ROOT))
for f in sorted(PH.glob("*.svg")):
    print(" ", f.relative_to(ROOT))
