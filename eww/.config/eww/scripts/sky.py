#!/usr/bin/env python3
"""Stargazing: tonight's sky, drawn live over the dashboard (opened from the weather tile).

    sky.py [MONITOR]     MONITOR = gdk monitor index, same as `eww open --screen`

Full screen. Drag to look around, scroll to zoom, arrows turn, L hides lines + labels, , and . step an hour,
N jumps back to tonight. Back (or ESC through the dash submap) returns to the dashboard.

Location comes from the weather cache (wttr.in). Star, constellation and milky way data is
d3-celestial (BSD, github.com/ofrohn/d3-celestial), planets are JPL DE421 through skyfield.
Everything downloads once into ~/.cache/eww/sky.
"""

import datetime
import json
import math
import os
import subprocess
import sys
import threading
import urllib.request

import cairo
import numpy as np
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell  # noqa: E402

CACHE = os.path.expanduser("~/.cache/eww/sky")
WEATHER = os.path.expanduser("~/.cache/eww/weather.json")
DASH = os.path.expanduser("~/.config/eww/scripts/dash.sh")
D3 = "https://raw.githubusercontent.com/ofrohn/d3-celestial/7e720a3de062059d4c5400a379146a601d9010e0/data/"
D3_FILES = ["stars.6.json", "constellations.lines.json", "constellations.json", "mw.json", "starnames.json"]

HEAD_H, FOOT_H = 44, 74
FONT = "JetBrainsMono Nerd Font"

# Colors: the rice's grays (eww.scss)
BG = (0x0E / 255, 0x0E / 255, 0x0E / 255)
FG = (0xD0 / 255,) * 3
DIM = (0x55 / 255,) * 3
LINE = (0x2A / 255,) * 3

PLANETS = [  # name, de421 key, color, size
    ("mercury", "mercury", (0.85, 0.80, 0.75), 2.6),
    ("venus", "venus", (1.00, 0.97, 0.88), 4.2),
    ("mars", "mars", (1.00, 0.58, 0.42), 3.0),
    ("jupiter", "jupiter barycenter", (1.00, 0.93, 0.82), 3.8),
    ("saturn", "saturn barycenter", (0.96, 0.86, 0.62), 3.2),
]

# Meteor Showers: peak (month, day)
SHOWERS = [("quadrantids", 1, 3), ("lyrids", 4, 22), ("eta aquariids", 5, 6), ("perseids", 8, 12),
           ("draconids", 10, 8), ("orionids", 10, 21), ("leonids", 11, 17), ("geminids", 12, 14),
           ("ursids", 12, 22)]

COMPASS = ["n", "nne", "ne", "ene", "e", "ese", "se", "sse", "s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw"]
OBLIQUITY = math.radians(23.4393)


def compass(az):
    return COMPASS[int((az % 360) / 22.5 + 0.5) % 16]


# == data ==

def fetch_data(status):
    os.makedirs(CACHE, exist_ok=True)
    for f in D3_FILES:
        path = os.path.join(CACHE, f)
        if not os.path.exists(path):
            status("downloading star data (first run)…")
            urllib.request.urlretrieve(D3 + f, path + ".part")
            os.replace(path + ".part", path)


def load_json(name):
    with open(os.path.join(CACHE, name), encoding="utf-8") as f:
        return json.load(f)


def location():
    if not os.path.exists(WEATHER):
        subprocess.run([os.path.expanduser("~/.config/eww/scripts/weather.sh")], capture_output=True)
    try:
        with open(WEATHER) as f:
            area = json.load(f)["nearest_area"][0]
        return float(area["latitude"]), float(area["longitude"])
    except (OSError, KeyError, ValueError, IndexError):
        return None


def bv_color(bv):
    # B-V color index -> rgb, kept soft
    pts = [-0.4, 0.0, 0.4, 0.8, 1.2, 1.6, 2.0]
    r = np.interp(bv, pts, [0.72, 0.84, 1.00, 1.00, 1.00, 1.00, 1.00])
    g = np.interp(bv, pts, [0.80, 0.88, 0.98, 0.93, 0.85, 0.76, 0.70])
    b = np.interp(bv, pts, [1.00, 1.00, 0.95, 0.82, 0.68, 0.56, 0.48])
    return np.stack([r, g, b], axis=1)


def milky_way_map():
    """Milky way glow in equatorial coords: 720 x 360 float map (x = ra -180..180, y = dec 90..-90)."""
    cached = os.path.join(CACHE, "mw.npy")
    if os.path.exists(cached):
        return np.load(cached)
    w, h = 720, 360
    surf = cairo.ImageSurface(cairo.FORMAT_A8, w, h)
    ctx = cairo.Context(surf)
    ctx.set_fill_rule(cairo.FILL_RULE_EVEN_ODD)
    for feature in load_json("mw.json")["features"]:   # ol1 (faint) .. ol5 (bright), stacked
        for poly in feature["geometry"]["coordinates"]:
            for shift in (-360, 0, 360):
                for ring in poly:
                    lon = np.array([p[0] for p in ring])
                    lat = np.array([p[1] for p in ring])
                    if lon.max() - lon.min() > 180:   # crosses the ±180 seam: unwrap
                        lon = np.where(lon < 0, lon + 360, lon)
                    xs = (lon + shift + 180) / 360 * w
                    ys = (90 - lat) / 180 * h
                    ctx.move_to(xs[0], ys[0])
                    for x, y in zip(xs[1:], ys[1:]):
                        ctx.line_to(x, y)
                    ctx.close_path()
            ctx.set_source_rgba(0, 0, 0, 0.2)
            ctx.fill()
    surf.flush()
    stride = surf.get_stride()
    m = np.frombuffer(surf.get_data(), dtype=np.uint8).reshape(h, stride)[:, :w].astype(np.float32) / 255
    # Soft Edges: box blur, 3 passes
    for _ in range(3):
        for axis in (0, 1):
            m = sum(np.roll(m, k, axis=axis) for k in range(-4, 5)) / 9
    np.save(cached, m)
    return m


class Sky:
    """Catalog + positions for one moment. ENU vectors: x = east, y = north, z = up."""

    def __init__(self, lat, lon, status):
        from skyfield.api import Loader, wgs84
        self.lat, self.lon = lat, lon
        fetch_data(status)
        status("loading stars…")
        stars = load_json("stars.6.json")["features"]
        names = load_json("starnames.json")
        self.s_ra = np.radians([f["geometry"]["coordinates"][0] % 360 for f in stars])
        self.s_dec = np.radians([f["geometry"]["coordinates"][1] for f in stars])
        self.s_mag = np.array([f["properties"]["mag"] for f in stars])
        bv = np.array([float(f["properties"]["bv"] or 0.6) for f in stars])
        self.s_rgb = bv_color(bv)
        self.s_name = [" ".join(names.get(str(f["id"]), {}).get("name", "").split()) for f in stars]

        # Constellation Lines: one flat array, segments between consecutive points of a line
        pts, segs = [], []
        for f in load_json("constellations.lines.json")["features"]:
            for line in f["geometry"]["coordinates"]:
                start = len(pts)
                pts += line
                segs += [(i, i + 1) for i in range(start, start + len(line) - 1)]
        self.c_ra = np.radians([p[0] % 360 for p in pts])
        self.c_dec = np.radians([p[1] for p in pts])
        self.c_segs = np.array(segs)
        labels = load_json("constellations.json")["features"]
        self.cl_name = [" ".join(f["properties"]["en"].split()).lower() for f in labels]   # odd unicode spaces
        self.cl_ra = np.radians([f["geometry"]["coordinates"][0] % 360 for f in labels])
        self.cl_dec = np.radians([f["geometry"]["coordinates"][1] for f in labels])

        # Ecliptic + Equator: 0.5° steps
        lam = np.radians(np.arange(0, 360.5, 0.5))
        self.ecl_ra = np.arctan2(np.sin(lam) * math.cos(OBLIQUITY), np.cos(lam)) % (2 * math.pi)
        self.ecl_dec = np.arcsin(math.sin(OBLIQUITY) * np.sin(lam))
        self.eq_ra, self.eq_dec = lam, np.zeros_like(lam)

        status("drawing the milky way…")
        self.mw = milky_way_map()

        status("loading planets…")
        load = Loader(CACHE, verbose=False)
        self.ts = load.timescale(builtin=True)
        self.eph = load("de421.bsp")
        self.obs = self.eph["earth"] + wgs84.latlon(lat, lon)

    # equatorial (J2000 rad) -> ENU vectors for the current sidereal time
    def enu(self, ra, dec):
        h = self.lst - ra
        phi = math.radians(self.lat)
        sin_alt = math.sin(phi) * np.sin(dec) + math.cos(phi) * np.cos(dec) * np.cos(h)
        alt = np.arcsin(np.clip(sin_alt, -1, 1))
        az = np.arctan2(-np.cos(dec) * np.sin(h), np.sin(dec) * math.cos(phi) - np.cos(dec) * math.sin(phi) * np.cos(h))
        return altaz_vec(alt, az)

    def radec_of(self, alt, az):
        phi = math.radians(self.lat)
        dec = np.arcsin(np.clip(math.sin(phi) * np.sin(alt) + math.cos(phi) * np.cos(alt) * np.cos(az), -1, 1))
        h = np.arctan2(-np.sin(az) * np.cos(alt), math.cos(phi) * np.sin(alt) - math.sin(phi) * np.cos(alt) * np.cos(az))
        return (self.lst - h) % (2 * math.pi), dec

    def set_time(self, when):
        from skyfield import almanac
        self.when = when
        t = self.ts.from_datetime(when)
        self.t = t
        self.lst = math.radians((t.gast * 15 + self.lon) % 360)
        self.s_v = self.enu(self.s_ra, self.s_dec)
        self.c_v = self.enu(self.c_ra, self.c_dec)
        self.cl_v = self.enu(self.cl_ra, self.cl_dec)
        self.ecl_v = self.enu(self.ecl_ra, self.ecl_dec)
        self.eq_v = self.enu(self.eq_ra, self.eq_dec)

        def body(key):
            ra, dec, _ = self.obs.at(t).observe(self.eph[key]).radec()
            return self.enu(np.array([ra.radians]), np.array([dec.radians]))[0]

        self.planets = [(name, body(key), rgb, size) for name, key, rgb, size in PLANETS]
        self.sun_v = body("sun")
        self.moon_v = body("moon")
        self.moon_lit = float(almanac.fraction_illuminated(self.eph, "moon", t))
        self.sun_alt = math.degrees(math.asin(self.sun_v[2]))
        self.info = self.tonight()

    def tonight(self):
        """One line: planets up, moon, close pairs, meteor showers."""
        from skyfield import almanac
        parts = []
        up = [(n, v) for n, v, _, _ in self.planets if v[2] > 0.02]
        for name, v in up:
            parts.append(f"{name} {math.degrees(math.asin(v[2])):.0f}° up in the {compass(vec_az(v))}")
        if not up:
            parts.append("no planets up")
        moon = f"moon {self.moon_lit * 100:.0f}%"
        try:   # next moonrise / moonset in the coming 12 hours
            t1 = self.ts.from_datetime(self.when + datetime.timedelta(hours=12))
            key = "sets" if self.moon_v[2] > 0 else "rises"
            find = almanac.find_settings if key == "sets" else almanac.find_risings
            times, _ = find(self.obs, self.eph["moon"], self.t, t1)
            if len(times):
                moon += f", {key} {times[0].astimezone(self.when.tzinfo):%H:%M}"
        except Exception:
            pass
        parts.append(moon)
        # Close Pairs: moon + planets within 5°
        bodies = [("moon", self.moon_v)] + [(n, v) for n, v, _, _ in self.planets]
        for i in range(len(bodies)):
            for j in range(i + 1, len(bodies)):
                (a, va), (b, vb) = bodies[i], bodies[j]
                sep = math.degrees(math.acos(np.clip(va @ vb, -1, 1)))
                if sep < 5 and (va[2] > 0 or vb[2] > 0):
                    parts.append(f"{a} near {b} ({sep:.0f}°)")
        today = self.when.date()
        for name, m, d in SHOWERS:
            for year in (today.year - 1, today.year, today.year + 1):
                days = (datetime.date(year, m, d) - today).days
                if 0 < days <= 10:
                    parts.append(f"{name} peak in {days} {'day' if days == 1 else 'days'}")
                elif days == 0:
                    parts.append(f"{name} peak tonight")
                elif -3 <= days < 0:
                    parts.append(f"{name} still active")
        return " · ".join(parts)


def altaz_vec(alt, az):
    return np.stack([np.cos(alt) * np.sin(az), np.cos(alt) * np.cos(az), np.sin(alt)], axis=-1)


def vec_az(v):
    return math.degrees(math.atan2(v[0], v[1])) % 360


def treeline():
    """Horizon altitude (deg) every 0.25° of azimuth: rolling hills + pointy trees."""
    az = np.arange(0, 360, 0.25)
    a = np.radians(az)
    h = 0.6 + 0.35 * np.sin(3 * a + 0.4) + 0.25 * np.sin(7 * a + 2.1) + 0.15 * np.sin(13 * a + 0.7)
    rng = np.random.default_rng(7)
    trees = np.zeros_like(az)
    for _ in range(140):
        c, height, width = rng.uniform(0, 360), rng.uniform(0.8, 3.2), rng.uniform(0.4, 1.4)
        d = np.abs((az - c + 180) % 360 - 180)
        trees = np.maximum(trees, height * np.clip(1 - d / width, 0, 1) ** 1.3)
    return az, np.maximum(h, 0.2) + trees


# == window ==

class SkyView(Gtk.Window):
    def __init__(self, monitor):
        super().__init__()
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_namespace(self, "eww-sky")
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_exclusive_zone(self, -1)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        mon = Gdk.Display.get_default().get_monitor(monitor)
        if mon:
            GtkLayerShell.set_monitor(self, mon)
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self.area = Gtk.DrawingArea()
        self.area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK |
                             Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.SCROLL_MASK |
                             Gdk.EventMask.SMOOTH_SCROLL_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
        self.area.connect("draw", self.on_draw)
        self.area.connect("button-press-event", self.on_press)
        self.area.connect("button-release-event", self.on_release)
        self.area.connect("motion-notify-event", self.on_motion)
        self.area.connect("scroll-event", self.on_scroll)
        self.connect("key-press-event", self.on_key)
        self.add(self.area)

        self.sky = None
        self.status = "looking up…"
        self.error = None
        self.yaw, self.pitch, self.fov = 180.0, 14.0, 90.0
        self.labels = True
        self.offset = 0          # hours from tonight
        self.drag = None
        self.mouse = None
        self.hover = None
        self.buttons = []
        self.static = None       # cached sky render, redrawn when the view changes
        self.dirty = True
        self.targets = []        # hover targets from the last render: (x, y, name, detail)
        self.twinkle = []        # bright stars from the last render: (x, y, r, rgb, phase)
        self.tz_az, self.tz_alt = treeline()
        self.tick = 0
        threading.Thread(target=self.load, daemon=True).start()
        GLib.timeout_add(100, self.on_tick)

    # Loading: off the gtk thread, the first run downloads ~20MB
    def load(self):
        def status(text):
            GLib.idle_add(self.set_status, text)
        try:
            loc = location()
            if loc is None:
                raise RuntimeError("no location yet, open the dashboard once with internet")
            sky = Sky(*loc, status)
            sky.set_time(self.tonight())
            GLib.idle_add(self.loaded, sky)
        except Exception as e:  # shown in the panel instead of crashing
            GLib.idle_add(self.set_error, str(e) or e.__class__.__name__)

    def set_status(self, text):
        self.status = text
        self.area.queue_draw()

    def set_error(self, text):
        self.error = text
        self.area.queue_draw()

    def loaded(self, sky):
        self.sky = sky
        # Start Facing: the brightest planet that's up, else south
        up = [(size, vec_az(v)) for _, v, _, size in sky.planets if v[2] > 0.05]
        if up:
            self.yaw = max(up)[1]
        self.dirty = True
        self.area.queue_draw()

    def tonight(self):
        """Now if it's dark, else 22:00 today. Plus the hour offset."""
        now = datetime.datetime.now().astimezone()
        base = now if self.sun_down(now) else now.replace(hour=22, minute=0, second=0, microsecond=0)
        return base + datetime.timedelta(hours=self.offset)

    def sun_down(self, when):
        if self.sky is None:
            return when.hour >= 20 or when.hour < 5
        s = self.sky
        t = s.ts.from_datetime(when)
        ra, dec, _ = s.obs.at(t).observe(s.eph["sun"]).radec()
        lst = math.radians((t.gast * 15 + s.lon) % 360)
        phi = math.radians(s.lat)
        alt = math.asin(math.sin(phi) * math.sin(dec.radians) + math.cos(phi) * math.cos(dec.radians) * math.cos(lst - ra.radians))
        return math.degrees(alt) < -12

    def set_offset(self, hours):
        if self.sky is None:
            return
        self.offset = hours
        self.sky.set_time(self.tonight())
        self.dirty = True
        self.area.queue_draw()

    # == geometry ==

    def panel(self):
        return 0, 0, self.get_allocated_width(), self.get_allocated_height()

    def basis(self):
        y, p = math.radians(self.yaw), math.radians(self.pitch)
        f = np.array([math.cos(p) * math.sin(y), math.cos(p) * math.cos(y), math.sin(p)])
        r = np.array([math.cos(y), -math.sin(y), 0.0])
        u = np.array([-math.sin(p) * math.sin(y), -math.sin(p) * math.cos(y), math.cos(p)])
        return f, r, u

    def project(self, v, pw, ph, limit=-0.5):
        """Stereographic projection of ENU vectors -> panel x, y + visible mask."""
        f, r, u = self.basis()
        x, y, z = v @ r, v @ u, v @ f
        s = (pw / 2) / (2 * math.tan(math.radians(self.fov) / 4))
        den = np.maximum(1 + z, 1e-6)
        return pw / 2 + s * 2 * x / den, ph / 2 - s * 2 * y / den, z > limit

    def unproject(self, px, py, pw, ph):
        """Panel pixels -> (alt, az) radians."""
        s = (pw / 2) / (2 * math.tan(math.radians(self.fov) / 4))
        X, Y = (px - pw / 2) / s, (ph / 2 - py) / s
        rho2 = X * X + Y * Y
        z = (4 - rho2) / (4 + rho2)
        x, y = 4 * X / (4 + rho2), 4 * Y / (4 + rho2)
        f, r, u = self.basis()
        v = x[..., None] * r + y[..., None] * u + z[..., None] * f
        return np.arcsin(np.clip(v[..., 2], -1, 1)), np.arctan2(v[..., 0], v[..., 1])

    # == rendering ==

    def render_static(self, pw, ph):
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, pw, ph)
        ctx = cairo.Context(surf)
        s = self.sky
        dark = min(max((-s.sun_alt - 4) / 14, 0), 1)     # 0 = day, 1 = full night
        self.targets, self.twinkle = [], []

        # Sky + Milky Way: low res grid, scaled up smooth
        step = 6
        gw, gh = pw // step + 2, ph // step + 2
        gx, gy = np.meshgrid(np.arange(gw) * step, np.arange(gh) * step)
        alt, az = self.unproject(gx.astype(float), gy.astype(float), pw, ph)
        up = np.clip(np.degrees(alt) / 90, 0, 1)[..., None]
        night = np.array([3, 5, 10]) * up + np.array([16, 22, 34]) * (1 - up)
        day = np.array([62, 112, 190]) * up + np.array([150, 186, 226]) * (1 - up)
        col = night * dark + day * (1 - dark)
        # twilight glow toward the sun
        if -18 < s.sun_alt < 2:
            sun_az = math.atan2(s.sun_v[0], s.sun_v[1])
            dist = np.abs((az - sun_az + math.pi) % (2 * math.pi) - math.pi)
            glow = np.exp(-dist / 0.6) * np.exp(-np.clip(np.degrees(alt), 0, 90) / 12)
            k = (1 - abs(s.sun_alt + 6) / 12) * 0.9
            col = col + np.array([210, 120, 60]) * (glow * max(k, 0))[..., None]
        ra, dec = s.radec_of(alt, az)
        mx = (((np.degrees(ra) + 180) % 360) / 360 * s.mw.shape[1]).astype(int) % s.mw.shape[1]
        my = np.clip(((90 - np.degrees(dec)) / 180 * s.mw.shape[0]).astype(int), 0, s.mw.shape[0] - 1)
        mw = s.mw[my, mx][..., None] * dark * np.clip(np.degrees(alt) / 15, 0, 1)[..., None]
        col = col + np.array([120, 128, 145]) * mw * 0.55
        col = col + np.random.default_rng(1).uniform(-0.7, 0.7, col.shape)   # dither: no banding in the dark
        img = np.zeros((gh, gw, 4), dtype=np.uint8)
        img[..., 2], img[..., 1], img[..., 0] = [np.clip(col[..., i], 0, 255) for i in range(3)]
        sky_surf = cairo.ImageSurface.create_for_data(memoryview(img), cairo.FORMAT_RGB24, gw, gh,
                                                      cairo.ImageSurface.format_stride_for_width(cairo.FORMAT_RGB24, gw))
        ctx.save()
        ctx.scale(step, step)
        ctx.set_source_surface(sky_surf, 0, 0)
        ctx.get_source().set_filter(cairo.FILTER_BILINEAR)
        ctx.get_source().set_extend(cairo.EXTEND_PAD)
        ctx.paint()
        ctx.restore()

        star_vis = dark
        if self.labels:
            # Guides: celestial equator (faint), ecliptic, meridian (dashed)
            self.polyline(ctx, s.eq_v, pw, ph, (1, 1, 1, 0.05 * star_vis + 0.03))
            self.polyline(ctx, s.ecl_v, pw, ph, (0.95, 0.85, 0.55, 0.16 * star_vis + 0.05))
            mer = np.concatenate([altaz_vec(np.radians(np.linspace(0, 90, 91)), np.zeros(91)),
                                  altaz_vec(np.radians(np.linspace(90, 0, 91)), np.full(91, math.pi))])
            ctx.set_dash([4, 6])
            self.polyline(ctx, mer, pw, ph, (1, 1, 1, 0.14))
            ctx.set_dash([])
            # Constellation Lines:
            cx, cy, ok = self.project(s.c_v, pw, ph)
            above = s.c_v[:, 2] > -0.05
            ctx.set_source_rgba(0.7, 0.75, 0.85, 0.22 * star_vis + 0.04)
            ctx.set_line_width(1)
            for a, b in s.c_segs:
                if ok[a] and ok[b] and (above[a] or above[b]):
                    ctx.move_to(cx[a], cy[a])
                    ctx.line_to(cx[b], cy[b])
            ctx.stroke()

        # Stars: fainter ones show up as you zoom in
        mag_lim = 5.2 + (90 - self.fov) / 70 * 1.3
        sx, sy, ok = self.project(s.s_v, pw, ph)
        zoom = (90 / self.fov) ** 0.3
        idx = np.nonzero(ok & (s.s_mag < mag_lim) & (s.s_v[:, 2] > -0.02) &
                         (sx > -10) & (sx < pw + 10) & (sy > -10) & (sy < ph + 10))[0]
        if star_vis > 0.02:
            for i in idx[np.argsort(-s.s_mag[idx])]:   # faint first, bright on top
                m = s.s_mag[i]
                r = min(max(0.8 + (5.4 - m) * 0.45, 0.75), 4.4) * zoom
                a = min(max((mag_lim + 0.8 - m) / 1.8, 0.3), 1.0) * star_vis
                rgb = s.s_rgb[i]
                if m < 1.8:   # glow
                    g = cairo.RadialGradient(sx[i], sy[i], 0, sx[i], sy[i], r * 4.5)
                    g.add_color_stop_rgba(0, *rgb, 0.35 * a)
                    g.add_color_stop_rgba(1, *rgb, 0)
                    ctx.set_source(g)
                    ctx.arc(sx[i], sy[i], r * 4.5, 0, 2 * math.pi)
                    ctx.fill()
                ctx.set_source_rgba(*rgb, a)
                ctx.arc(sx[i], sy[i], r, 0, 2 * math.pi)
                ctx.fill()
                if m < 2.6:
                    self.twinkle.append((sx[i], sy[i], r, rgb, (i * 2.399) % (2 * math.pi)))
                if s.s_name[i] and m < 3.5:
                    self.targets.append((sx[i], sy[i], s.s_name[i].lower(),
                                         f"star · mag {m:.1f} · {self.alt_text(s.s_v[i])}"))

        # Planets:
        for name, v, rgb, size in s.planets:
            (px,), (py,), (vis,) = self.project(v[None], pw, ph)
            if not vis or v[2] < -0.02:
                continue
            g = cairo.RadialGradient(px, py, 0, px, py, size * 4)
            g.add_color_stop_rgba(0, *rgb, 0.4)
            g.add_color_stop_rgba(1, *rgb, 0)
            ctx.set_source(g)
            ctx.arc(px, py, size * 4, 0, 2 * math.pi)
            ctx.fill()
            ctx.set_source_rgb(*rgb)
            ctx.arc(px, py, size * zoom, 0, 2 * math.pi)
            ctx.fill()
            self.targets.append((px, py, name, f"planet · {self.alt_text(v)}"))
            if self.labels:
                self.label(ctx, px + 9, py - 7, name, (*rgb, 0.9), 12)

        # Sun:
        (px,), (py,), (vis,) = self.project(s.sun_v[None], pw, ph)
        if vis and s.sun_alt > -1:
            g = cairo.RadialGradient(px, py, 0, px, py, 60)
            g.add_color_stop_rgba(0, 1, 0.97, 0.85, 1)
            g.add_color_stop_rgba(0.15, 1, 0.95, 0.8, 0.9)
            g.add_color_stop_rgba(1, 1, 0.9, 0.7, 0)
            ctx.set_source(g)
            ctx.arc(px, py, 60, 0, 2 * math.pi)
            ctx.fill()

        # Moon: lit side toward the sun
        self.draw_moon(ctx, pw, ph)

        # Ground: treeline silhouette, covers everything below the horizon
        self.draw_ground(ctx, pw, ph, dark)

        # Labels:
        if self.labels:
            lx, ly, lok = self.project(s.cl_v, pw, ph)
            for i, name in enumerate(s.cl_name):
                if lok[i] and s.cl_v[i, 2] > 0.06 and 0 < lx[i] < pw and 0 < ly[i] < ph:
                    self.label(ctx, lx[i], ly[i], name, (0.75, 0.78, 0.85, 0.32 * star_vis + 0.08), 11, center=True)
            for x, y, name, detail in self.targets:
                if detail.startswith("star") and float(detail.split("mag ")[1].split()[0]) < 1.6:
                    self.label(ctx, x + 7, y + 13, name, (0.85, 0.85, 0.85, 0.55 * star_vis), 11)
        # Cardinal Points: on the horizon
        for name, a in (("n", 0), ("ne", 45), ("e", 90), ("se", 135), ("s", 180), ("sw", 225), ("w", 270), ("nw", 315)):
            v = altaz_vec(np.radians(-1.6), np.radians(a))
            (px,), (py,), (vis,) = self.project(v[None], pw, ph, limit=0)
            if vis and 0 < px < pw and 0 < py < ph:
                self.label(ctx, px, py, name, (*FG, 0.8 if len(name) == 1 else 0.4), 15 if len(name) == 1 else 12,
                           center=True, bold=len(name) == 1)
        return surf

    def draw_moon(self, ctx, pw, ph):
        s = self.sky
        (mx,), (my,), (vis,) = self.project(s.moon_v[None], pw, ph)
        if not vis or s.moon_v[2] < -0.02:
            return
        r = max(7.0, (pw / 2) / (2 * math.tan(math.radians(self.fov) / 4)) * math.radians(0.26) * 2)
        # direction to the sun on screen: a point 2° from the moon toward it
        toward = s.sun_v - s.moon_v * (s.sun_v @ s.moon_v)
        n = np.linalg.norm(toward)
        step = s.moon_v + (toward / n if n > 0 else 0) * 0.035
        (sx,), (sy,), _ = self.project((step / np.linalg.norm(step))[None], pw, ph, limit=-1)
        ang = math.atan2(sy - my, sx - mx)
        k = s.moon_lit
        g = cairo.RadialGradient(mx, my, 0, mx, my, r * 5)
        g.add_color_stop_rgba(0, 0.9, 0.92, 1, 0.18 * k)
        g.add_color_stop_rgba(1, 0.9, 0.92, 1, 0)
        ctx.set_source(g)
        ctx.arc(mx, my, r * 5, 0, 2 * math.pi)
        ctx.fill()
        ctx.save()
        ctx.translate(mx, my)
        ctx.rotate(ang)
        dark = min(max((-s.sun_alt - 4) / 14, 0), 1)
        ctx.set_source_rgba(0.1, 0.1, 0.12, dark)   # dark disc (sky shows through by day)
        ctx.arc(0, 0, r, 0, 2 * math.pi)
        ctx.fill()
        # lit part: half disc toward the sun (+x) +/- the terminator ellipse
        ctx.set_source_rgb(0.93, 0.93, 0.9)
        ctx.new_path()
        ctx.arc(0, 0, r, -math.pi / 2, math.pi / 2)
        e = abs(2 * k - 1)
        ctx.save()
        ctx.scale(max(e, 0.001), 1)
        if k >= 0.5:
            ctx.arc(0, 0, r, math.pi / 2, 3 * math.pi / 2)
        else:
            ctx.arc_negative(0, 0, r, math.pi / 2, -math.pi / 2)
        ctx.restore()
        ctx.fill()
        ctx.restore()
        self.targets.append((mx, my, "moon", f"{k * 100:.0f}% lit · {self.alt_text(s.moon_v)}"))
        if self.labels:
            self.label(ctx, mx + r + 6, my - r, "moon", (0.9, 0.9, 0.9, 0.8), 12)

    def draw_ground(self, ctx, pw, ph, dark):
        """The horizon projects to a circle around the view. Looking up, the ground is outside it;
        looking down, inside. Near level the circle gets huge, so the part behind you is cut off
        and the loop closes through a point far up (or down) instead."""
        v = altaz_vec(np.radians(self.tz_alt), np.radians(self.tz_az))
        x, y, ok = self.project(v, pw, ph, limit=-0.9995)
        shade = 7 + (1 - dark) * 18
        ctx.set_source_rgb(shade / 255, shade / 255, (shade + 1) / 255)
        up = self.pitch > 0
        if ok.all():
            seq = np.arange(len(x))
        else:
            first_hidden = int(np.argmin(ok))
            order = np.roll(np.arange(len(x)), -first_hidden)
            seq = order[ok[order]]
        if len(seq) < 2:
            return
        if up:
            ctx.rectangle(-2e6, -2e6, 4e6, 4e6)
        ctx.move_to(x[seq[0]], y[seq[0]])
        for i in seq[1:]:
            ctx.line_to(x[i], y[i])
        if not ok.all():
            ctx.line_to(pw / 2, -1e6 if up else ph + 1e6)
        ctx.close_path()
        ctx.set_fill_rule(cairo.FILL_RULE_EVEN_ODD)
        ctx.fill()
        ctx.set_fill_rule(cairo.FILL_RULE_WINDING)

    def polyline(self, ctx, v, pw, ph, rgba):
        x, y, ok = self.project(v, pw, ph)
        above = v[:, 2] > -0.02
        ctx.set_source_rgba(*rgba)
        ctx.set_line_width(1)
        for i in range(len(x) - 1):
            if ok[i] and ok[i + 1] and above[i] and above[i + 1]:
                ctx.move_to(x[i], y[i])
                ctx.line_to(x[i + 1], y[i + 1])
        ctx.stroke()

    def alt_text(self, v):
        return f"{math.degrees(math.asin(np.clip(v[2], -1, 1))):.0f}° up in the {compass(vec_az(v))}"

    def label(self, ctx, x, y, text, rgba, size, center=False, bold=False):
        ctx.select_font_face(FONT, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
        ctx.set_font_size(size)
        ext = ctx.text_extents(text)
        if center:
            x, y = x - ext.width / 2 - ext.x_bearing, y + ext.height / 2
        ctx.set_source_rgba(*rgba)
        ctx.move_to(x, y)
        ctx.show_text(text)
        return ext.x_advance

    # == drawing ==

    def on_draw(self, _w, ctx):
        ox, oy, pw, ph = self.panel()
        ctx.translate(ox, oy)
        ctx.save()
        ctx.rectangle(0, 0, pw, ph)
        ctx.clip()
        ctx.set_source_rgb(*BG)
        ctx.paint()
        self.buttons = []
        if self.sky is None:
            text = self.error or self.status
            self.label(ctx, pw / 2, ph / 2, text, (*(DIM if not self.error else (0.82, 0.38, 0.38)), 1), 13, center=True)
            self.draw_head(ctx, pw, loading=True)
            ctx.restore()
            return
        if self.dirty or self.static is None or self.static.get_width() != pw or self.static.get_height() != ph:
            self.static = self.render_static(pw, ph)
            self.dirty = False
        ctx.set_source_surface(self.static, 0, 0)
        ctx.paint()
        # Twinkle: bright stars breathe a little
        t = self.tick * 0.1
        for x, y, r, rgb, phase in self.twinkle:
            a = 0.18 * (0.5 + 0.5 * math.sin(t * 2.3 + phase) * math.sin(t * 1.7 + phase * 1.9))
            ctx.set_source_rgba(*rgb, a)
            ctx.arc(x, y, r * 1.6, 0, 2 * math.pi)
            ctx.fill()
        self.draw_head(ctx, pw)
        self.draw_foot(ctx, pw, ph)
        self.draw_hover(ctx, pw, ph)
        ctx.restore()

    def bar(self, ctx, y, h, pw, top):
        g = cairo.LinearGradient(0, y, 0, y + h)
        a, b = (0.92, 0.0) if top else (0.0, 0.92)
        g.add_color_stop_rgba(0, *BG, a)
        g.add_color_stop_rgba(0.55 if top else 0.45, *BG, 0.82)
        g.add_color_stop_rgba(1, *BG, b)
        ctx.set_source(g)
        ctx.rectangle(0, y, pw, h)
        ctx.fill()

    def button(self, ctx, x, y, text, action, active=False):
        ctx.select_font_face(FONT)
        ctx.set_font_size(13)
        w = ctx.text_extents(text).x_advance + 20
        hot = self.mouse and x <= self.mouse[0] <= x + w and y <= self.mouse[1] <= y + 28
        if hot or active:
            rounded(ctx, x, y, w, 28, 4)
            ctx.set_source_rgba(0x1A / 255, 0x1A / 255, 0x1A / 255, 0.95)
            ctx.fill()
        ctx.set_source_rgb(*(FG if hot or active else (0.6, 0.6, 0.6)))
        ctx.move_to(x + 10, y + 19)
        ctx.show_text(text)
        self.buttons.append((x, y, w, 28, action))
        return w

    def draw_head(self, ctx, pw, loading=False):
        if not loading:
            self.bar(ctx, 0, HEAD_H + 22, pw, top=True)
        self.button(ctx, 10, 9, "󰁍 back", "back")
        if loading:
            return
        when = self.sky.when
        tag = "now" if abs((when - datetime.datetime.now().astimezone()).total_seconds()) < 120 else "tonight"
        if self.offset:
            tag = "+%dh" % self.offset if self.offset > 0 else "%dh" % self.offset
        title = f"{tag} · {when:%H:%M} · {when:%A, %B %-d}".lower()
        self.label(ctx, pw / 2, 23, title, (*FG, 1), 13, center=True)
        x = pw - 10
        for text, action, active in reversed([("󰑓 lines", "labels", self.labels), ("− 1h", "back1", False),
                                              ("tonight", "tonight", self.offset == 0), ("+ 1h", "fwd1", False)]):
            ctx.select_font_face(FONT)
            ctx.set_font_size(13)
            x -= ctx.text_extents(text).x_advance + 20 + 4
            self.button(ctx, x, 9, text, action, active)

    def draw_foot(self, ctx, pw, ph):
        top = ph - FOOT_H
        self.bar(ctx, top - 30, FOOT_H + 30, pw, top=False)
        # Compass Strip: ticks every 15°, click to face that way
        cy = top + 10
        deg_px = self.fov / pw
        ctx.set_line_width(1)
        for a in range(0, 360, 15):
            d = (a - self.yaw + 180) % 360 - 180
            x = pw / 2 + d / deg_px
            if not 0 < x < pw:
                continue
            fade = max(0.0, 1 - abs(x - pw / 2) / (pw / 2)) ** 0.5
            if a % 45 == 0:
                name = compass(a)
                self.label(ctx, x, cy + 4, name, (*FG, (0.9 if len(name) == 1 else 0.5) * fade), 12, center=True,
                           bold=len(name) == 1)
            else:
                ctx.set_source_rgba(*FG, 0.25 * fade)
                ctx.move_to(x + 0.5, cy)
                ctx.line_to(x + 0.5, cy + 6)
                ctx.stroke()
        # facing marker
        ctx.set_source_rgba(*FG, 0.9)
        ctx.move_to(pw / 2 - 4, cy - 8)
        ctx.line_to(pw / 2 + 4, cy - 8)
        ctx.line_to(pw / 2, cy - 3)
        ctx.close_path()
        ctx.fill()
        self.buttons.append((0, cy - 10, pw, 24, "compass"))
        # Info: tonight + how to move
        self.label(ctx, 16, top + 44, "󰖔 " + self.sky.info, (*FG, 0.85), 12)
        facing = f"looking {compass(self.yaw)} · {self.pitch:.0f}° up · drag to look around · scroll to zoom · L lines · , . hours"
        self.label(ctx, 16, top + 64, facing, (*DIM, 1), 11)

    def draw_hover(self, ctx, pw, ph):
        if not self.hover or self.drag:
            return
        x, y, name, detail = self.hover
        ctx.set_source_rgba(*FG, 0.8)
        ctx.set_line_width(1)
        ctx.arc(x, y, 9, 0, 2 * math.pi)
        ctx.stroke()
        ctx.select_font_face(FONT)
        ctx.set_font_size(12)
        w = max(ctx.text_extents(name).x_advance, ctx.text_extents(detail).x_advance) + 20
        bx, by = min(x + 14, pw - w - 8), max(y - 50, HEAD_H + 4)
        rounded(ctx, bx, by, w, 44, 4)
        ctx.set_source_rgba(*BG, 0.94)
        ctx.fill_preserve()
        ctx.set_source_rgb(*LINE)
        ctx.stroke()
        self.label(ctx, bx + 10, by + 18, name, (*FG, 1), 12)
        self.label(ctx, bx + 10, by + 35, detail, (*DIM, 1), 11)

    # == input ==

    def local(self, ev):
        ox, oy, pw, ph = self.panel()
        return ev.x - ox, ev.y - oy, pw, ph

    def hit(self, x, y):
        for bx, by, bw, bh, action in self.buttons:
            if bx <= x <= bx + bw and by <= y <= by + bh:
                return action
        return None

    def on_press(self, _w, ev):
        x, y, pw, ph = self.local(ev)
        action = self.hit(x, y)
        if action == "compass":
            self.yaw = (self.yaw + (x - pw / 2) * self.fov / pw) % 360
            self.dirty = True
        elif action:
            self.do(action)
        elif self.sky:
            self.drag = (x, y, self.yaw, self.pitch)
        self.area.queue_draw()
        return True

    def on_release(self, _w, _ev):
        self.drag = None
        return True

    def on_motion(self, _w, ev):
        x, y, pw, ph = self.local(ev)
        self.mouse = (x, y)
        if self.drag:
            x0, y0, yaw0, pitch0 = self.drag
            k = self.fov / pw
            self.yaw = (yaw0 - (x - x0) * k) % 360
            self.pitch = min(max(pitch0 + (y - y0) * k, -10), 90)
            self.dirty = True
        else:
            best, near = None, 16
            for t in self.targets:
                d = math.hypot(t[0] - x, t[1] - y)
                if d < near:
                    best, near = t, d
            self.hover = best
        self.area.queue_draw()
        return True

    def on_scroll(self, _w, ev):
        ok, _dx, dy = ev.get_scroll_deltas()
        if not ok:
            dy = -1 if ev.direction == Gdk.ScrollDirection.UP else 1 if ev.direction == Gdk.ScrollDirection.DOWN else 0
        self.fov = min(max(self.fov * (1.1 ** dy), 20), 120)
        self.dirty = True
        self.area.queue_draw()
        return True

    def on_key(self, _w, ev):
        key = Gdk.keyval_name(ev.keyval)
        moves = {"Left": (-15, 0), "Right": (15, 0), "Up": (0, 10), "Down": (0, -10)}
        if key in moves:
            self.yaw = (self.yaw + moves[key][0]) % 360
            self.pitch = min(max(self.pitch + moves[key][1], -10), 90)
            self.dirty = True
        elif key in ("plus", "equal", "KP_Add"):
            self.fov = max(self.fov / 1.15, 20)
            self.dirty = True
        elif key in ("minus", "KP_Subtract"):
            self.fov = min(self.fov * 1.15, 120)
            self.dirty = True
        elif key in ("l", "L"):
            self.do("labels")
        elif key == "comma":
            self.do("back1")
        elif key == "period":
            self.do("fwd1")
        elif key in ("n", "N"):
            self.do("tonight")
        elif key in ("Escape", "BackSpace"):
            self.back()
        self.area.queue_draw()
        return True

    def do(self, action):
        if action == "back":
            self.back()
        elif action == "labels":
            self.labels = not self.labels
            self.dirty = True
        elif action == "back1":
            self.set_offset(self.offset - 1)
        elif action == "fwd1":
            self.set_offset(self.offset + 1)
        elif action == "tonight":
            self.set_offset(0)

    def back(self):
        subprocess.Popen([DASH, "back"])
        Gtk.main_quit()
        return True

    def on_tick(self):
        self.tick += 1
        if self.twinkle and not self.drag:
            self.area.queue_draw()
        return True


def rounded(ctx, x, y, w, h, r):
    ctx.new_sub_path()
    ctx.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    ctx.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    ctx.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    ctx.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    ctx.close_path()


PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "eww-sky.pid")

if __name__ == "__main__":
    # Pidfile: dash.sh closes us with it
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    win = SkyView(int(sys.argv[1]) if len(sys.argv) > 1 else 0)
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    try:
        Gtk.main()
    finally:
        try:
            with open(PIDFILE) as f:
                if f.read().strip() == str(os.getpid()):
                    os.remove(PIDFILE)
        except OSError:
            pass
