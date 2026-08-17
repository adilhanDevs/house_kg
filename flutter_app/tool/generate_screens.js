// Translate the rendered React tree (tree.json, produced by extract_tree.js)
// into the Flutter screens under lib/screens.
//
//   node tool/extract_tree.js && node tool/generate_screens.js
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.resolve(__dirname, '..');
const tree = JSON.parse(fs.readFileSync(path.join(__dirname, 'tree.json'), 'utf8'));

// ---------------------------------------------------------------- css helpers

// the colour the prototype's page hands the mockup for `currentColor`
const PAGE_COLOR = 'rgb(255,255,255)';

const TOKENS = { '--black-main-88': 'rgb(0,0,0)', '--fills-tertiary': 'rgba(120,120,128,0.12)', '--labels-secondary': 'rgba(60,60,67,0.6)' };

// fig-assets.css — the background rule behind each `fig-asset-*` class. Both
// bundles bring one; the two classes they share carry the same rule and the
// same bytes, so one map covers the lot.
const ASSET_CLASSES = (() => {
  const rules = {};
  for (const file of [
    path.join(ROOT, 'screens', 'fig-assets.css'),
    path.join(ROOT, 'screens', 'verify', 'fig-assets.css'),
  ]) {
    const css = fs.readFileSync(file, 'utf8');
    const re = /\.([\w-]+)\s*\{\s*background:\s*([^;]+);\s*\}/g;
    let m;
    while ((m = re.exec(css))) {
      const [, cls, rule] = m;
      if (rules[cls] && rules[cls] !== rule.trim()) throw new Error('asset class clash: ' + cls);
      rules[cls] = rule.trim();
    }
  }
  return rules;
})();

const usedAssets = new Set();

function num(v) {
  const n = Math.round(v * 1000) / 1000;
  return Number.isInteger(n) ? n.toFixed(1) : String(n);
}

function parseColor(c) {
  if (c == null) return null;
  c = String(c).trim();
  const t = /^var\(([^)]+)\)$/.exec(c);
  if (t) return parseColor(TOKENS[t[1].trim()]);
  let m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/.exec(c);
  if (!m) throw new Error('color? ' + c);
  const [r, g, b] = [m[1], m[2], m[3]].map(Number);
  const a = m[4] === undefined ? 1 : Number(m[4]);
  return { r, g, b, a };
}

function dartColor(c) {
  const p = typeof c === 'string' ? parseColor(c) : c;
  if (!p) return null;
  const h = (n) => Math.round(n).toString(16).padStart(2, '0');
  return `Color(0x${h(p.a * 255)}${h(p.r)}${h(p.g)}${h(p.b)})`;
}

function px(v) {
  if (v === undefined || v === null) return null;
  if (typeof v === 'number') return v;
  const m = /^(-?[\d.]+)px$/.exec(String(v));
  return m ? Number(m[1]) : null;
}

// "10px 10px 10px 10px" -> {t,r,b,l}
function parsePadding(p) {
  if (!p) return null;
  const v = String(p).trim().split(/\s+/).map((x) => parseFloat(x));
  const [t, r, b, l] = v.length === 4 ? v : v.length === 2 ? [v[0], v[1], v[0], v[1]] : [v[0], v[0], v[0], v[0]];
  return { t, r, b, l };
}

// "1px solid rgba(…)" per side -> {width, color} or null
function parseBorderSide(v) {
  if (!v) return null;
  const m = /^([\d.]+)px\s+\w+\s+(.+)$/.exec(String(v).trim());
  if (!m) throw new Error('border? ' + v);
  return { width: Number(m[1]), color: m[2].trim() };
}

// css `transform: matrix(a,b,c,d,e,f)` or `scale(x[, y])` -> a column-major
// Matrix4. Every transform in the mockup sits on `transform-origin: 0 0`, which
// is what Flutter's Transform does without an origin of its own.
function dartMatrix(t) {
  const nums = (s) => s.split(',').map((x) => Number(x.trim()));
  let m = /matrix\(([^)]+)\)/.exec(t);
  if (m) {
    const [a, b, c, d, e, f] = nums(m[1]);
    return `Matrix4(${[a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1].map(num).join(', ')})`;
  }
  m = /scale\(([^)]+)\)/.exec(t);
  if (m) {
    const [x, y = x] = nums(m[1]);
    return `Matrix4(${[x, 0, 0, 0, 0, y, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1].map(num).join(', ')})`;
  }
  throw new Error('transform? ' + t);
}

function checkTransformOrigin(o) {
  if (o === undefined) return;
  if (!/^(0|0px)(\s+(0|0px))?$/.test(String(o).trim())) throw new Error('transform-origin? ' + o);
}

// css `filter: drop-shadow(dx dy blur color) …`
function parseDropShadows(v) {
  const out = [];
  const re = /drop-shadow\(\s*(-?[\d.]+)px\s+(-?[\d.]+)px\s+([\d.]+)px\s+(rgba?\([^)]*\))\s*\)/g;
  let m;
  while ((m = re.exec(v))) {
    out.push({ dx: Number(m[1]), dy: Number(m[2]), blur: Number(m[3]), color: m[4] });
  }
  return out;
}

// box-shadow list -> {outer:[], inset:[]}
function parseShadows(s) {
  if (!s) return { outer: [], inset: [] };
  const parts = [];
  let depth = 0, cur = '';
  for (const ch of s) {
    if (ch === '(') depth++;
    if (ch === ')') depth--;
    if (ch === ',' && depth === 0) { parts.push(cur); cur = ''; } else cur += ch;
  }
  if (cur.trim()) parts.push(cur);
  const outer = [], inset = [];
  for (let raw of parts) {
    raw = raw.trim();
    const isInset = /^inset\s/.test(raw);
    if (isInset) raw = raw.replace(/^inset\s+/, '');
    const colorM = /(rgba?\([^)]*\))\s*$/.exec(raw);
    const color = colorM ? colorM[1] : 'rgb(0,0,0)';
    const nums = raw.slice(0, colorM ? colorM.index : raw.length).trim().split(/\s+/).map((x) => parseFloat(x));
    const [dx, dy, blur = 0, spread = 0] = nums;
    if (isInset) inset.push({ color, width: spread }); // only used as inset rings (0 0 0 Npx)
    else outer.push({ dx, dy, blur, spread, color });
  }
  return { outer, inset };
}

// css linear-gradient -> flutter LinearGradient (needs box size for angle math)
function parseGradient(g, w, h) {
  // linear-gradient(-1.014deg, rgba(..) 24.44%, rgba(..) 93.86%) | linear-gradient(c1, c2)
  const inner = g.slice(g.indexOf('(') + 1, g.lastIndexOf(')'));
  const parts = [];
  let depth = 0, cur = '';
  for (const ch of inner) {
    if (ch === '(') depth++;
    if (ch === ')') depth--;
    if (ch === ',' && depth === 0) { parts.push(cur.trim()); cur = ''; } else cur += ch;
  }
  if (cur.trim()) parts.push(cur.trim());
  let angle = 180; // css default: to bottom
  if (/deg\s*$/.test(parts[0])) angle = parseFloat(parts.shift());
  const stops = parts.map((p) => {
    const m = /^(.*?)(?:\s+([\d.]+)%)?$/.exec(p.trim());
    return { color: m[1].trim(), pos: m[2] === undefined ? null : Number(m[2]) / 100 };
  });
  stops.forEach((s, i) => { if (s.pos === null) s.pos = i / (stops.length - 1); });
  // css gradient line: direction (sin a, -cos a) with y down, length |W sin a| + |H cos a|
  const a = (angle * Math.PI) / 180;
  const dx = Math.sin(a), dy = -Math.cos(a);
  const W = w || 1, H = h || 1;
  const L = Math.abs(W * Math.sin(a)) + Math.abs(H * Math.cos(a));
  const cx = W / 2, cy = H / 2;
  const bx = cx - (dx * L) / 2, by = cy - (dy * L) / 2;
  const ex = cx + (dx * L) / 2, ey = cy + (dy * L) / 2;
  const al = (x, y) => `Alignment(${num((x / W) * 2 - 1)}, ${num((y / H) * 2 - 1)})`;
  return `LinearGradient(begin: ${al(bx, by)}, end: ${al(ex, ey)}, colors: [${stops
    .map((s) => dartColor(s.color))
    .join(', ')}], stops: [${stops.map((s) => num(s.pos)).join(', ')}])`;
}

// "url(…) center / cover no-repeat" or "url(…) X% Y% / W% H% no-repeat",
// optionally preceded by gradient layers
function parseBackground(bg, w, h) {
  const res = { image: null, x: 0.5, y: 0.5, wFactor: null, hFactor: null, gradients: [] };
  const urlM = /url\(([^)]+)\)\s*([^,]*)/.exec(bg);
  if (urlM) {
    res.image = urlM[1].replace(/^.*\//, '').replace(/["']/g, '');
    usedAssets.add(res.image);
    const pct = /([\d.]+)%\s+([\d.]+)%\s*\/\s*(-?[\d.]+)%\s+(-?[\d.]+)%/.exec(urlM[2]);
    if (pct) {
      // a negative background-size is not valid css, so the browser throws the
      // whole shorthand away and the element ends up with no background at all
      // — one asset in the mockup is exported that way, and the prototype shows
      // it as nothing. Do the same instead of painting something it never shows.
      if (Number(pct[3]) < 0 || Number(pct[4]) < 0) {
        usedAssets.delete(res.image);
        res.image = null;
        return res;
      }
      res.x = Number(pct[1]) / 100;
      res.y = Number(pct[2]) / 100;
      res.wFactor = Number(pct[3]) / 100;
      res.hFactor = Number(pct[4]) / 100;
    }
  }
  const gm = bg.match(/linear-gradient\([^()]*(?:\([^()]*\)[^()]*)*\)/g) || [];
  for (const g of gm) res.gradients.push(parseGradient(g, w, h));
  return res;
}

function emitBackground(bg, args) {
  if (bg.image) {
    const pos = bg.wFactor === null
      ? ''
      : `, x: ${num(bg.x)}, y: ${num(bg.y)}, wFactor: ${num(bg.wFactor)}, hFactor: ${num(bg.hFactor)}`;
    args.push(`bgImage: const FigBgImage('assets/figma/${bg.image}'${pos})`);
  }
  if (bg.gradients.length) args.push(`overlays: const [${bg.gradients.join(', ')}]`);
}

// ---------------------------------------------------------------- code buffer

class Buf {
  constructor() { this.s = ''; }
  line(indent, text) { this.s += '  '.repeat(indent) + text + '\n'; }
}

function dartString(s) {
  return "'" + s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n').replace(/\r/g, '') + "'";
}

// ---------------------------------------------------------------- svg

const pathIds = new Map();
function pathConst(d) {
  if (!pathIds.has(d)) pathIds.set(d, '_p' + pathIds.size);
  return pathIds.get(d);
}

function emitSvg(node, buf, ind, inherited, ctx) {
  const st = node.props.style || {};
  const vb = String(node.props.viewBox).trim().split(/\s+/).map(Number);
  let w = px(st.width) ?? px(node.props.width) ?? resolvedWidth(node, ctx);
  let h = px(st.height) ?? px(node.props.height) ?? resolvedHeight(node, ctx);
  // an svg with only one side set takes the other from the viewBox ratio
  if (w === null) w = h === null ? null : (h * vb[2]) / vb[3];
  if (h === null) h = (w * vb[3]) / vb[2];
  if (w === null) throw new Error('svg with no resolvable size: ' + node.props.viewBox);
  // `currentColor` with nothing to inherit is the css initial colour
  const color = st.color ? String(st.color) : inherited || 'rgb(0,0,0)';
  const shapes = [];
  for (const c of node.children || []) {
    if (!c || !c.tag) continue;
    const p = c.props;
    const resolve = (v) => (v === 'currentColor' ? color : v);
    if (c.tag === 'path') {
      const fill = p.fill && p.fill !== 'none' ? dartColor(resolve(p.fill)) : null;
      const stroke = p.stroke && p.stroke !== 'none' ? dartColor(resolve(p.stroke)) : null;
      const args = [`d: ${pathConst(p.d)}`];
      if (fill) args.push(`fill: ${fill}`);
      if (p.fillRule === 'evenodd') args.push('evenOdd: true');
      if (stroke) args.push(`stroke: ${stroke}`, `strokeWidth: ${num(Number(p.strokeWidth || 1))}`);
      if (p.strokeLinecap === 'round') args.push('roundCap: true');
      if (p.strokeLinejoin === 'round') args.push('roundJoin: true');
      shapes.push(`FigShape(${args.join(', ')})`);
    } else if (c.tag === 'circle') {
      const fill = p.fill && p.fill !== 'none' ? dartColor(resolve(p.fill)) : null;
      const stroke = p.stroke && p.stroke !== 'none' ? dartColor(resolve(p.stroke)) : null;
      const args = [`cx: ${num(Number(p.cx))}`, `cy: ${num(Number(p.cy))}`, `r: ${num(Number(p.r))}`];
      if (fill) args.push(`fill: ${fill}`);
      if (stroke) args.push(`stroke: ${stroke}`, `strokeWidth: ${num(Number(p.strokeWidth || 1))}`);
      shapes.push(`FigShape(${args.join(', ')})`);
    }
  }
  const drops = st.filter ? parseDropShadows(st.filter) : [];
  if (drops.length) {
    shapes.dropShadows = `dropShadows: const [${drops
      .map((d) => `BoxShadow(color: ${dartColor(d.color)}, offset: Offset(${num(d.dx)}, ${num(d.dy)}), blurRadius: ${num(d.blur)})`)
      .join(', ')}],`;
  }
  const op = st.opacity !== undefined ? st.opacity : null;
  if (op !== null) { buf.line(ind, `Opacity(`); buf.line(ind + 1, `opacity: ${num(op)},`); buf.line(ind + 1, `child: FigSvg(`); }
  else buf.line(ind, `FigSvg(`);
  const i2 = op !== null ? ind + 2 : ind + 1;
  buf.line(i2, `width: ${num(w)}, height: ${num(h)},`);
  buf.line(i2, `vbLeft: ${num(vb[0])}, vbTop: ${num(vb[1])}, vbWidth: ${num(vb[2])}, vbHeight: ${num(vb[3])},`);
  buf.line(i2, `shapes: const [${shapes.join(', ')}],`);
  if (shapes.dropShadows) buf.line(i2, shapes.dropShadows);
  if (op !== null) { buf.line(ind + 1, `),`); buf.line(ind, `)`); }
  else buf.line(ind, `)`);
}

// ---------------------------------------------------------------- text

const FAMILY = { 'SF Pro Text': 'FigFont.text', 'SF Pro Display': 'FigFont.display', 'SF Pro': 'FigFont.pro' };

function familyOf(ff) {
  if (!ff) return null;
  const first = ff.split(',')[0].replace(/"/g, '').trim();
  return FAMILY[first] || null;
}

function textStyle(st, inheritedColor, parentSize) {
  const size = st.fontSize !== undefined
    ? (typeof st.fontSize === 'number' ? st.fontSize : parseFloat(st.fontSize) * parentSize) // "0.72em"
    : parentSize;
  const args = [`fontSize: ${num(size)}`];
  const fam = familyOf(st.fontFamily);
  if (fam) args.push(`family: ${fam}`);
  if (st.fontWeight) args.push(`weight: ${st.fontWeight}`);
  if (st.lineHeight) {
    const lh = String(st.lineHeight);
    if (lh.endsWith('%')) args.push(`height: ${num(parseFloat(lh) / 100)}`);
    else args.push(`height: ${num(parseFloat(lh) / size)}`);
  }
  if (st.letterSpacing) {
    const ls = String(st.letterSpacing);
    const v = ls.endsWith('em') ? parseFloat(ls) * size : parseFloat(ls);
    args.push(`letterSpacing: ${num(v)}`);
  }
  const col = st.color !== undefined ? st.color : inheritedColor;
  if (col) args.push(`color: const ${dartColor(col)}`);
  return { code: `figStyle(${args.join(', ')})`, size };
}

// build inline spans for a <span> that holds text
function emitSpans(node, buf, ind, inheritedColor, parentSize) {
  const st = node.props.style || {};
  const { code, size } = textStyle(st, inheritedColor, parentSize);
  const kids = node.children || [];
  const simple = kids.length === 1 && typeof kids[0] === 'string';
  if (simple) {
    buf.line(ind, `TextSpan(text: ${dartString(kids[0])}, style: ${code}),`);
    return;
  }
  buf.line(ind, `TextSpan(style: ${code}, children: [`);
  for (const c of kids) {
    if (typeof c === 'string') { buf.line(ind + 1, `TextSpan(text: ${dartString(c)}),`); continue; }
    if (c.tag === 'span') {
      const cs = c.props.style || {};
      if (cs.verticalAlign === 'super') {
        const sub = textStyle(cs, st.color !== undefined ? st.color : inheritedColor, size);
        const txt = (c.children || []).filter((x) => typeof x === 'string').join('');
        buf.line(ind + 1, `figSuper(${dartString(txt)}, ${sub.code}, ${num(size)}),`);
      } else {
        emitSpans(c, buf, ind + 1, st.color !== undefined ? st.color : inheritedColor, size);
      }
    }
  }
  buf.line(ind, `]),`);
}

function emitText(node, buf, ind, inheritedColor, ctx) {
  const st = node.props.style || {};
  const w = resolvedWidth(node, ctx), h = resolvedHeight(node, ctx);
  const ws = st.whiteSpace;
  const ellipsis = st.textOverflow === 'ellipsis';
  const args = [];
  if (st.textAlign === 'center') args.push('align: TextAlign.center');
  if (ws === 'nowrap') args.push('noWrap: true');
  if (ellipsis) args.push('ellipsis: true');
  if (w !== null) args.push(`width: ${num(w)}`);
  if (h !== null) args.push(`height: ${num(h)}`);
  if (st.opacity !== undefined) args.push(`opacity: ${num(st.opacity)}`);
  buf.line(ind, `FigText(`);
  for (const a of args) buf.line(ind + 1, a + ',');
  buf.line(ind + 1, `span: `);
  const sub = new Buf();
  emitSpans(node, sub, 0, inheritedColor, 15);
  const body = sub.s.trimEnd().replace(/,$/, '');
  body.split('\n').forEach((l, i) => buf.line(ind + 2, l));
  buf.line(ind + 1, ',');
  buf.line(ind, `)`);
}

// ---------------------------------------------------------------- box / layout

// resolved width of a node given the layout context (css `align-self: stretch`
// in a column resolves against the parent's content box)
function resolvedWidth(node, ctx) {
  const st = node.props.style || {};
  const w = px(st.width);
  if (w !== null) return w;
  if (st.position === 'absolute' || !ctx || !ctx.flex) return null;
  if (ctx.dir === 'column' && (st.alignSelf === 'stretch' || ctx.align === 'stretch')) return ctx.contentWidth;
  return null;
}

function resolvedHeight(node, ctx) {
  const st = node.props.style || {};
  const h = px(st.height);
  if (h !== null) return h;
  if (st.position === 'absolute' || !ctx || !ctx.flex) return null;
  if (ctx.dir === 'row' && (st.alignSelf === 'stretch' || ctx.align === 'stretch')) return ctx.contentHeight;
  return null;
}

function emitNode(node, buf, ind, ctx, inheritedColor) {
  if (typeof node === 'string') return;
  // tab-bar hooks: the prototype recolours each cell and makes it clickable
  if (node.__tint || node.__tabCell !== undefined) {
    const inner = new Buf();
    const bare = { ...node };
    const tint = bare.__tint;
    const cell = bare.__tabCell;
    delete bare.__tint;
    delete bare.__tabCell;
    emitNode(bare, inner, 0, ctx, inheritedColor);
    let lines = inner.s.trimEnd().split('\n');
    if (tint) {
      const w = new Buf();
      w.line(0, 'FigTint(');
      w.line(1, `color: _color(${tint.cell}, const ${dartColor(tint.base)}),`);
      if (tint.weight) w.line(1, `weight: _weight(${tint.cell}),`);
      w.line(1, 'child: ' + lines[0]);
      lines.slice(1).forEach((l) => w.line(1, l));
      w.line(1, ',');
      w.line(0, ')');
      lines = w.s.trimEnd().split('\n');
    }
    if (cell !== undefined) {
      const w = new Buf();
      w.line(0, `_tab(${cell},`);
      lines.forEach((l) => w.line(1, l));
      w.line(0, ')');
      lines = w.s.trimEnd().split('\n');
    }
    lines.forEach((l) => buf.line(ind, l));
    return;
  }
  // `transform` does not take part in layout, so it just wraps whatever the
  // node renders to (transform-origin is always the top-left here)
  const st0 = node.props.style || {};
  if (st0.transform) {
    checkTransformOrigin(st0.transformOrigin);
    const inner = new Buf();
    const bare = { ...node, props: { ...node.props, style: { ...st0 } } };
    delete bare.props.style.transform;
    delete bare.props.style.transformOrigin;
    emitNode(bare, inner, 0, ctx, inheritedColor);
    const lines = inner.s.trimEnd().split('\n');
    buf.line(ind, 'Transform(');
    buf.line(ind + 1, `transform: ${dartMatrix(st0.transform)},`);
    buf.line(ind + 1, 'child: ' + lines[0]);
    lines.slice(1).forEach((l) => buf.line(ind + 1, l));
    buf.line(ind + 1, ',');
    buf.line(ind, ')');
    return;
  }
  if (node.tag === 'svg') return emitSvg(node, buf, ind, inheritedColor, ctx);

  const st = node.props.style || {};
  // a <span> is a text run unless it only wraps a block (the inline icons do)
  const inlineContent = (node.children || []).some((c) => typeof c === 'string' || c.tag === 'span');
  if (node.tag === 'span' && inlineContent) return emitText(node, buf, ind, inheritedColor, ctx);

  const color = st.color !== undefined ? String(st.color) : inheritedColor;
  // a css border sits outside the content box and shifts the children in,
  // so fold it into the box size and the padding
  const bd = {
    t: parseBorderSide(st.borderTop),
    r: parseBorderSide(st.borderRight),
    b: parseBorderSide(st.borderBottom),
    l: parseBorderSide(st.borderLeft),
  };
  const hasBorder = bd.t || bd.r || bd.b || bd.l;
  const bw = (side) => (bd[side] ? bd[side].width : 0);
  let width = resolvedWidth(node, ctx);
  let height = resolvedHeight(node, ctx);
  let pad = parsePadding(st.padding);
  if (hasBorder) {
    if (width !== null) width += bw('l') + bw('r');
    if (height !== null) height += bw('t') + bw('b');
    pad = pad
      ? { t: pad.t + bw('t'), r: pad.r + bw('r'), b: pad.b + bw('b'), l: pad.l + bw('l') }
      : { t: bw('t'), r: bw('r'), b: bw('b'), l: bw('l') };
  }
  const isFlex = st.display === 'flex';
  const isGrid = st.display === 'grid';
  const kids = (node.children || []).filter((c) => c && c.tag);

  const contentWidth = width === null ? null : width - (pad ? pad.l + pad.r : 0);
  const contentHeight = height === null ? null : height - (pad ? pad.t + pad.b : 0);
  const childCtx = {
    flex: isFlex,
    dir: isFlex ? st.flexDirection || 'row' : 'column',
    align: st.alignItems || 'stretch',
    contentWidth,
    contentHeight,
  };

  // ---- children widget
  const inner = new Buf();
  if (isFlex) {
    // an absolutely positioned child is out of the flex flow: it neither takes
    // room between the others nor is spaced by `space-between`, it just sits at
    // its own left/top inside the box (the reels «REELS | 01:04» divider).
    const absKids = kids.filter((k) => (k.props.style || {}).position === 'absolute');
    const flexKids = absKids.length ? kids.filter((k) => !absKids.includes(k)) : kids;
    const dir = st.flexDirection === 'column' ? 'Column' : 'Row';
    const args = [];
    args.push('mainAxisSize: MainAxisSize.min');
    if (st.justifyContent === 'center') args.push('mainAxisAlignment: MainAxisAlignment.center');
    else if (st.justifyContent === 'space-between') args.push('mainAxisAlignment: MainAxisAlignment.spaceBetween');
    const ai = st.alignItems;
    args.push(
      'crossAxisAlignment: ' +
        (ai === 'center' ? 'CrossAxisAlignment.center' : ai === 'flex-start' ? 'CrossAxisAlignment.start' : 'CrossAxisAlignment.start')
    );
    const gap = typeof st.gap === 'number' ? st.gap : st.gap ? parseFloat(st.gap) : 0;
    if (gap) args.push(`spacing: ${num(gap)}`);
    inner.line(0, `${dir}(`);
    for (const a of args) inner.line(1, a + ',');
    const spread = st.justifyContent === 'space-between';
    const grows = flexKids.some((k) => (k.props.style || {}).flexGrow === 1);
    const freeMain = !spread && !grows;
    inner.line(1, 'children: [');
    for (const k of flexKids) {
      const ks = k.props.style || {};
      const grow = ks.flexGrow === 1;
      const sub = new Buf();
      emitNode(k, sub, 0, childCtx, color);
      const lines = sub.s.trimEnd().split('\n');
      if (grow) {
        inner.line(2, 'Expanded(');
        inner.line(3, 'child: ' + lines[0]);
        lines.slice(1).forEach((l) => inner.line(3, l));
        inner.line(2, '),');
      } else {
        lines.forEach((l, i) => inner.line(2, l + (i === lines.length - 1 ? ',' : '')));
      }
    }
    inner.line(1, '],');
    inner.line(0, ')');
    // css lets flex content overflow a fixed-size box; flutter would clamp it,
    // so hand the flex an unbounded vertical axis and align it back into place.
    // (skipped for space-between, whose spacing needs the fixed main axis)
    const freeCross = !(dir === 'Column'); // widening a column would stop text wrapping
    const freeWidth = dir === 'Column' ? freeCross : freeMain;
    const freeHeight = dir === 'Column' ? freeMain : freeCross;
    if (freeWidth || freeHeight) {
      const y = dir === 'Column'
        ? (st.justifyContent === 'center' ? 0 : -1)
        : (st.alignItems === 'center' ? 0 : -1);
      const x = dir === 'Column'
        ? (st.alignItems === 'center' ? 0 : -1)
        : (st.justifyContent === 'center' ? 0 : -1);
      const wrapped = new Buf();
      wrapped.line(0, 'FigOverflow(');
      if (freeWidth) wrapped.line(1, 'freeWidth: true,');
      if (!freeHeight) wrapped.line(1, 'freeHeight: false,');
      wrapped.line(1, `alignment: const Alignment(${num(x)}, ${num(y)}),`);
      const lines = inner.s.trimEnd().split('\n');
      wrapped.line(1, 'child: ' + lines[0]);
      lines.slice(1).forEach((l) => wrapped.line(1, l));
      wrapped.line(1, ',');
      wrapped.line(0, ')');
      inner.s = wrapped.s;
    }
    if (absKids.length) {
      const stacked = new Buf();
      stacked.line(0, 'Stack(');
      stacked.line(1, 'clipBehavior: Clip.none,');
      stacked.line(1, 'children: [');
      const lines = inner.s.trimEnd().split('\n');
      lines.forEach((l, i) => stacked.line(2, l + (i === lines.length - 1 ? ',' : '')));
      for (const k of absKids) {
        const ks = k.props.style || {};
        const sub = new Buf();
        emitNode(k, sub, 0, childCtx, color);
        const kl = sub.s.trimEnd().split('\n');
        stacked.line(2, 'Positioned(');
        stacked.line(3, `left: ${num(px(ks.left) ?? 0)}, top: ${num(px(ks.top) ?? 0)},`);
        stacked.line(3, 'child: ' + kl[0]);
        kl.slice(1).forEach((x) => stacked.line(3, x));
        stacked.line(2, '),');
      }
      stacked.line(1, '],');
      stacked.line(0, ')');
      inner.s = stacked.s;
    }
  } else if (kids.length) {
    // stack of absolutely positioned children (grid single-cell behaves the same)
    inner.line(0, 'Stack(');
    inner.line(1, 'clipBehavior: Clip.none,');
    inner.line(1, 'children: [');
    for (const k of kids) {
      const ks = k.props.style || {};
      const sub = new Buf();
      emitNode(k, sub, 0, childCtx, color);
      const lines = sub.s.trimEnd().split('\n');
      const l = isGrid ? 0 : px(ks.left) ?? 0;
      const t = (isGrid ? 0 : px(ks.top) ?? 0) + (px(ks.marginTop) ?? 0);
      const centred = isGrid && ks.justifySelf === 'center';
      inner.line(2, `Positioned(`);
      // a grid track here is 1px wide, so an item just sits at the content
      // box origin — unless it asks to be centred across the track
      inner.line(3, centred ? `left: 0.0, right: 0.0, top: ${num(t)},` : `left: ${num(l)}, top: ${num(t)},`);
      inner.line(3, 'child: ' + (centred ? 'Align(' : lines[0]));
      if (centred) {
        inner.line(4, 'child: ' + lines[0]);
        lines.slice(1).forEach((x) => inner.line(4, x));
        inner.line(4, ',');
        inner.line(3, ')');
      } else {
        lines.slice(1).forEach((x) => inner.line(3, x));
      }
      inner.line(2, '),');
    }
    inner.line(1, '],');
    inner.line(0, ')');
  }

  // ---- box decoration
  const args = [];
  if (width !== null) args.push(`width: ${num(width)}`);
  if (height !== null) args.push(`height: ${num(height)}`);
  const bgColor = st.backgroundColor ? dartColor(st.backgroundColor) : null;
  if (bgColor) args.push(`color: const ${bgColor}`);
  if (st.borderRadius !== undefined) {
    const r = st.borderRadius;
    // `50%` rounds a square into a circle; `32px 32px 0 0` rounds per corner,
    // clockwise from the top left — the bottom sheets round only their top
    if (r === '50%') args.push(`radius: ${num((width ?? height ?? 0) / 2)}`);
    else if (typeof r === 'string' && /\s/.test(r.trim())) {
      const parts = r.trim().split(/\s+/).map((v) => {
        const n = px(v) ?? Number(v);
        if (!Number.isFinite(n)) throw new Error('border-radius? ' + r);
        return n;
      });
      // css fills the missing corners the same way it fills padding
      const [tl, tr = tl, br = tl, bl = tr] = parts;
      args.push(`corners: const [${[tl, tr, br, bl].map(num).join(', ')}]`);
    } else args.push(`radius: ${num(Number(r))}`);
  }
  if (st.overflow === 'hidden') args.push('clip: true');
  if (st.opacity !== undefined) args.push(`opacity: ${num(st.opacity)}`);
  if (st.backdropFilter) {
    const b = parseFloat(/blur\(([\d.]+)px\)/.exec(st.backdropFilter)[1]);
    args.push(`blur: ${num(b / 2)}`);
  }
  if (pad) args.push(`padding: const EdgeInsets.fromLTRB(${num(pad.l)}, ${num(pad.t)}, ${num(pad.r)}, ${num(pad.b)})`);

  const sh = parseShadows(st.boxShadow);
  if (sh.outer.length) {
    args.push(
      `shadows: const [${sh.outer
        .map((s) => `BoxShadow(color: ${dartColor(s.color)}, offset: Offset(${num(s.dx)}, ${num(s.dy)}), blurRadius: ${num(s.blur)}, spreadRadius: ${num(s.spread)})`)
        .join(', ')}]`
    );
  }
  if (sh.inset.length) {
    args.push(`insets: const [${sh.inset.map((s) => `FigInset(${dartColor(s.color)}, ${num(s.width)})`).join(', ')}]`);
  }
  if (hasBorder) {
    const side = (k) => (bd[k] ? `BorderSide(color: ${dartColor(bd[k].color)}, width: ${num(bd[k].width)})` : 'BorderSide.none');
    args.push(`border: const Border(top: ${side('t')}, right: ${side('r')}, bottom: ${side('b')}, left: ${side('l')})`);
  }

  // background image / gradient, either inline or via a fig-asset-* class
  const cls = node.props.className && node.props.className.trim();
  if (cls && ASSET_CLASSES[cls]) emitBackground(parseBackground(ASSET_CLASSES[cls], width, height), args);
  if (st.background) emitBackground(parseBackground(st.background, width, height), args);

  buf.line(ind, 'FigBox(');
  for (const a of args) buf.line(ind + 1, a + ',');
  if (inner.s) {
    const lines = inner.s.trimEnd().split('\n');
    buf.line(ind + 1, 'child: ' + lines[0]);
    lines.slice(1).forEach((l) => buf.line(ind + 1, l));
    buf.line(ind + 1, ',');
  }
  buf.line(ind, ')');
}

// ---------------------------------------------------------------- tab bar
//
// The prototype does not use the tab bar the way the mockup draws it: it
// swaps the duplicated fourth tab for a heart labelled «Избранное», recolours
// whichever tab matches the current screen, makes every cell clickable, and
// injects the whole bar onto the two screens that lack it (`_ensureNav`,
// `_styleTabs`, `_heartTab` in the html). So it comes out of the screens and
// becomes one widget the shell places instead.

const TAB_ACCENT = 'rgb(234,129,46)';
const TAB_IDLE = 'rgb(172,172,176)';
// the heart the prototype substitutes for the fourth tab's icon
const HEART_PATH =
  'M12 20.25c-.28 0-.55-.1-.76-.28C6.79 16.2 3.75 13.53 3.75 10.1c0-2.6 2-4.6 4.53-4.6 '
  + '1.44 0 2.77.67 3.72 1.79.95-1.12 2.28-1.79 3.72-1.79 2.53 0 4.53 2 4.53 4.6 0 3.43-3.04 '
  + '6.1-7.49 9.87-.21.18-.48.28-.76.28Z';

function textOf(n) {
  if (typeof n === 'string') return n;
  if (!n || !n.tag) return '';
  return (n.children || []).map(textOf).join('');
}

// the root-level child holding the "Главное · Поиск · …" row, if the screen has one
function findTabBar(root) {
  for (const [i, child] of (root.children || []).entries()) {
    let row = null;
    (function walk(n) {
      if (!n || !n.tag) return;
      const kids = (n.children || []).filter((c) => c && c.tag);
      if (kids.length === 5 && textOf(n).replace(/\s+/g, '').startsWith('ГлавноеПоиск')) row = n;
      kids.forEach(walk);
    })(child);
    if (row) return { index: i, holder: child, row };
  }
  return null;
}

// which cell this screen's mockup draws in the accent colour; the bar itself is
// emitted once, from the first screen that has one, so the rest carry the index
function mockupTabOf(row) {
  const cells = (row.children || []).filter((c) => c && c.tag);
  for (const [i, cell] of cells.entries()) {
    let hit = false;
    (function walk(n) {
      if (hit || !n || !n.tag) return;
      const c = (n.props.style || {}).color;
      if (c && (c === TAB_ACCENT || /rgb\(255,\s*39,\s*39\)/.test(c))) { hit = true; return; }
      (n.children || []).forEach(walk);
    })(cell);
    if (hit) return i;
  }
  return null;
}

function firstVisibleSvgColor(node) {
  let color = null;
  (function walk(n) {
    if (color || !n || !n.tag) return;
    const st = n.props.style || {};
    if (n.tag === 'svg' && st.opacity !== 0 && st.color) { color = st.color; return; }
    (n.children || []).forEach(walk);
  })(node);
  return color;
}

// annotate the cells so emitNode can wrap them, and swap in the heart
function prepareTabBar(bar) {
  const cells = bar.row.children.filter((c) => c && c.tag);
  const rowIconColor = firstVisibleSvgColor(cells[0]);
  cells.forEach((cell, i) => {
    const [holder, label] = cell.children.filter((c) => c && c.tag);
    cell.__tabCell = i;
    if (i === HEART_TAB) {
      holder.props.style = { ...holder.props.style, overflow: 'visible' };
      holder.children = [{
        tag: 'svg',
        props: {
          width: 24, height: 24, viewBox: '0 0 24 24', fill: 'none',
          style: { position: 'absolute', left: 0, top: 0, width: 24, height: 24 },
        },
        children: [{
          tag: 'path',
          props: { d: HEART_PATH, fill: 'none', stroke: 'currentColor', strokeWidth: 1.7, strokeLinejoin: 'round' },
          children: [],
        }],
      }];
      label.children = ['Избранное'];
    }
    holder.__tint = { cell: i, base: (i === HEART_TAB ? rowIconColor : firstVisibleSvgColor(holder)) || TAB_IDLE };
    label.__tint = { cell: i, base: (label.props.style || {}).color || TAB_IDLE, weight: true };
  });
}

const HEART_TAB = 3;

function emitTabBar(bar) {
  pathIds.clear();
  prepareTabBar(bar);
  // emit the bar itself, not the mockup's clipping holder: the prototype pins
  // the bare bar to the viewport on the screens that lack one, and the shell
  // re-applies the holder's clip where the mockup does draw it
  const inner = bar.holder.children.filter((c) => c && c.tag)[0];
  const holder = bar.holder.props.style || {};
  const body = new Buf();
  emitNode(inner, body, 2, null, null);

  const consts = [...pathIds.entries()]
    .map(([d, id]) => `const String ${id} =\n    ${dartString(d)};`)
    .join('\n');

  return `// GENERATED from screens/Components.bundle.js — the mockup's tab bar,\n`
    + `// restyled the way the prototype does at runtime.\n`
    + `// Do not edit by hand; regenerate with tool/generate_screens.js.\n`
    + `import 'package:flutter/material.dart';\n\nimport 'fig.dart';\n\n`
    + `/// The bottom tab bar: Главное · Поиск · История · Избранное · Профиль.\n`
    + `class FigTabBar extends StatelessWidget {\n`
    + `  const FigTabBar({super.key, this.active, this.mockupTab, this.onTap});\n\n`
    + `  /// Which tab the prototype highlights (\`SCREEN_TAB\`), or null where it\n`
    + `  /// leaves the mockup's own colours alone.\n`
    + `  final int? active;\n\n`
    + `  /// Which tab the mockup draws highlighted on the screen the bar is on.\n`
    + `  /// The bar is drawn once, from the catalog screen, so screens whose\n`
    + `  /// mockup marks another tab pass it here — colour only, no bolder label,\n`
    + `  /// exactly as the mockup has it. Ignored once [active] is set.\n`
    + `  final int? mockupTab;\n\n`
    + `  final void Function(int index)? onTap;\n\n`
    + `  /// The box the mockup clips the bar to where it draws it itself.\n`
    + `  static const double clipWidth = ${num(px(holder.width))};\n`
    + `  static const double clipHeight = ${num(px(holder.height))};\n\n`
    + `  static const Color _accent = ${dartColor(TAB_ACCENT)};\n`
    + `  static const Color _idle = ${dartColor(TAB_IDLE)};\n\n`
    + `  // the two colours the mockup uses to mark a tab as selected\n`
    + `  static bool _isSelected(Color base) {\n`
    + `    final rgb = base.toARGB32() & 0xFFFFFF;\n`
    + `    return rgb == 0xEA812E || rgb == 0xFF2727;\n`
    + `  }\n\n`
    + `  Color _color(int cell, Color base) {\n`
    + `    if (active == null) {\n`
    + `      if (mockupTab == null) return base;\n`
    + `      if (mockupTab == cell) return _accent;\n`
    + `      return _isSelected(base) ? _idle : base;\n`
    + `    }\n`
    + `    if (active == cell) return _accent;\n`
    + `    return _isSelected(base) ? _idle : base;\n`
    + `  }\n\n`
    + `  int? _weight(int cell) => active == cell ? 600 : null;\n\n`
    + `  Widget _tab(int index, Widget child) => GestureDetector(\n`
    + `        behavior: HitTestBehavior.opaque,\n`
    + `        onTap: onTap == null ? null : () => onTap!(index),\n`
    + `        child: child,\n`
    + `      );\n\n`
    + `  @override\n  Widget build(BuildContext context) {\n    return `
    + body.s.trimStart().trimEnd() + `;\n  }\n}\n\n` + consts + '\n';
}

// ---------------------------------------------------------------- screens

const SCREENS = [
  ['StartScreen', 'Screen01Splash', 'screen_01_splash', 'Сплэш'],
  ['StartScreen2', 'Screen02Onboarding1', 'screen_02_onboarding_1', 'Онбординг 1'],
  ['StartScreen3', 'Screen03Onboarding2', 'screen_03_onboarding_2', 'Онбординг 2'],
  ['StartScreen4', 'Screen04Onboarding3', 'screen_04_onboarding_3', 'Онбординг 3'],
  ['StartScreen5', 'Screen05Welcome', 'screen_05_welcome', 'Добро пожаловать'],
  ['StartScreen6', 'Screen06Code', 'screen_06_code', 'Код подтверждения'],
  ['StartScreen7', 'Screen07Welcome2', 'screen_07_welcome_2', 'Добро пожаловать · 2'],
  ['StartScreen8', 'Screen08Code2', 'screen_08_code_2', 'Код подтверждения · 2'],
  ['StartScreen9', 'Screen09Home', 'screen_09_home', 'Главная'],
  ['StartScreen10', 'Screen10Collection', 'screen_10_collection', 'Коллекция'],
  ['StartScreen11', 'Screen11Catalog', 'screen_11_catalog', 'Каталог'],
  ['StartScreen12', 'Screen12Filter', 'screen_12_filter', 'Фильтр'],
  ['StartScreen13', 'Screen13Screen573408', 'screen_13_screen_57_3408', 'Экран 57:3408'],
  ['StartScreen14', 'Screen14ProductCard', 'screen_14_product_card', 'Карточка товара'],
  ['StartScreen15', 'Screen15Profile', 'screen_15_profile', 'Ваш профиль'],
  ['StartScreen16', 'Screen16Liked', 'screen_16_liked', 'Вам понравилось'],
  ['StartScreen17', 'Screen17Notifications', 'screen_17_notifications', 'Уведомления'],
  ['StartScreen18', 'Screen18YourFilters', 'screen_18_your_filters', 'Ваши фильтры'],
  ['StartScreen19', 'Screen19ObjectFull', 'screen_19_object_full', 'Объект · полная'],
  ['StartScreen20', 'Screen20PhotoReview', 'screen_20_photo_review', 'Фотообзор'],
  ['Frame11133', 'Screen21Frame11133', 'screen_21_frame_11133', 'Frame 11133'],
  ['StartScreen21', 'Screen22Screen101475', 'screen_22_screen_10_1475', 'Экран 10:1475'],
  ['StartScreen22', 'Screen23Profile57506', 'screen_23_profile_57_506', 'Профиль 57:506'],
  ['StartScreen23', 'Screen24PhotoConfirm1', 'screen_24_photo_confirm_1', 'Фото подтверждение · 1'],
  ['StartScreen24', 'Screen25PhotoConfirm2', 'screen_25_photo_confirm_2', 'Фото подтверждение · 2'],
  ['StartScreen25', 'Screen26Screen631840', 'screen_26_screen_63_1840', 'Экран 63:1840'],
  ['StartScreen26', 'Screen27Screen641365', 'screen_27_screen_64_1365', 'Экран 64:1365'],
  ['StartScreen27', 'Screen28Screen632044', 'screen_28_screen_63_2044', 'Экран 63:2044'],
  ['StartScreen28', 'Screen29Screen64187', 'screen_29_screen_64_187', 'Экран 64:187'],
  ['StartScreen29', 'Screen30Screen64249', 'screen_30_screen_64_249', 'Экран 64:249'],
  ['StartScreen30', 'Screen31Screen155823', 'screen_31_screen_155_823', 'Экран 155:823'],
  ['StartScreen31', 'Screen32Screen155901', 'screen_32_screen_155_901', 'Экран 155:901'],
  ['StartScreen32', 'Screen33Screen155980', 'screen_33_screen_155_980', 'Экран 155:980'],
  ['StartScreen33', 'Screen34CatalogCreate', 'screen_34_catalog_create', 'Создание каталога'],
  ['StartScreen34', 'Screen35Screen1551329', 'screen_35_screen_155_1329', 'Экран 155:1329'],
  ['StartScreen35', 'Screen36Screen1551379', 'screen_36_screen_155_1379', 'Экран 155:1379'],
  ['StartScreen36', 'Screen37Screen1551429', 'screen_37_screen_155_1429', 'Экран 155:1429'],
  ['StartScreen37', 'Screen38ProProfile', 'screen_38_pro_profile', 'Профиль исполнителя'],
  ['StartScreen38', 'Screen39Screen1552155', 'screen_39_screen_155_2155', 'Экран 155:2155'],
  ['StartScreen39', 'Screen40Screen1552313', 'screen_40_screen_155_2313', 'Экран 155:2313'],
  // Frames of a strip, not screens of their own: the component lays them out in
  // a row and the prototype slides it sideways to show one (`shift` in the
  // html). The fifth field is the frame, the sixth the height the prototype
  // gives the strip where the frames themselves carry none (`.fig-group`).
  ['Frame48096303', 'Screen41Topup1', 'screen_41_topup_1', 'Пополнение · 1', 0, 812],
  ['Frame48096303', 'Screen42Topup2', 'screen_42_topup_2', 'Пополнение · 2', 1, 812],
  ['Frame48096303', 'Screen43Topup3', 'screen_43_topup_3', 'Пополнение · 3', 2, 812],
  ['Frame48096303', 'Screen44Topup4', 'screen_44_topup_4', 'Пополнение · 4', 3, 812],
  ['Frame48096303', 'Screen45Topup5', 'screen_45_topup_5', 'Пополнение · 5', 4, 812],
  ['Frame48096302', 'Screen46Ad1', 'screen_46_ad_1', 'Объявление · 1', 0],
  ['Frame48096302', 'Screen47Ad2', 'screen_47_ad_2', 'Объявление · 2', 1],
  ['Frame48096302', 'Screen48Ad3', 'screen_48_ad_3', 'Объявление · 3', 2],
  ['Frame48096302', 'Screen49Ad4', 'screen_49_ad_4', 'Объявление · 4', 3],
  ['Frame48096302', 'Screen50Ad5', 'screen_50_ad_5', 'Объявление · 5', 4],
  ['Frame48096302', 'Screen51Ad6', 'screen_51_ad_6', 'Объявление · 6', 5],
  ['Frame48096304', 'Screen52History1', 'screen_52_history_1', 'История трат · 1', 0, 812],
  ['Frame48096304', 'Screen53History2', 'screen_53_history_2', 'История трат · 2', 1, 812],
  ['Frame48096304', 'Screen54History3', 'screen_54_history_3', 'История трат · 3', 2, 812],
  ['Frame48096304', 'Screen55History4', 'screen_55_history_4', 'История трат · 4', 3, 812],
  // из screens/verify/Components.bundle.js — там же, где их берёт прототип
  ['PhotoVerify1', 'Screen56ProSignup', 'screen_56_pro_signup', 'Регистрация исполнителя'],
  ['PhotoVerify2', 'Screen57ProCode', 'screen_57_pro_code', 'Код · исполнитель'],
];

const dir = path.join(OUT, 'lib', 'screens');
fs.mkdirSync(dir, { recursive: true });

const meta = [];
let tabBarSource = null;
for (const [key, cls, file, title, frame, stripHeight] of SCREENS) {
  pathIds.clear();
  // one frame out of a strip: take that child, and give it the height the strip
  // is stretched to where the frame carries none (`align-self: stretch`)
  const root =
    frame === undefined
      ? tree[key]
      : (() => {
          const f = tree[key].children.filter((c) => c && c.tag)[frame];
          if (!f) throw new Error(`${key} has no frame ${frame}`);
          const style = Object.assign({}, f.props.style);
          if (style.height === undefined) style.height = stripHeight;
          // the strip itself hands its children a colour (the history strip is
          // black), and that inheritance has to survive lifting a frame out
          if (style.color === undefined && (tree[key].props.style || {}).color !== undefined) {
            style.color = tree[key].props.style.color;
          }
          delete style.alignSelf;
          delete style.flexShrink;
          return Object.assign({}, f, { props: Object.assign({}, f.props, { style }) });
        })();
  const st = root.props.style;

  // lift the tab bar out of the screen; the shell places it instead
  const bar = findTabBar(root);
  let tabBarAt = null;
  let mockupTab = null;
  if (bar) {
    const bs = bar.holder.props.style || {};
    tabBarAt = { left: px(bs.left) ?? 0, top: px(bs.top) ?? 0 };
    mockupTab = mockupTabOf(bar.row);
    root.children = root.children.filter((c) => c !== bar.holder);
    if (!tabBarSource) tabBarSource = bar;
  }

  const body = new Buf();
  // `currentColor` with nothing setting a colour resolves to the page's own,
  // and the prototype's page is white (`color:#fff` on its shell). That is what
  // the browser paints — the photo placeholders come out white on white, not
  // black — so the screens start from the same colour.
  emitNode(root, body, 2, null, PAGE_COLOR);

  const consts = [...pathIds.entries()]
    .map(([d, id]) => `const String ${id} =\n    ${dartString(d)};`)
    .join('\n');

  const src =
    `// GENERATED from screens/Components.bundle.js — figma node ${key}.\n` +
    `// Do not edit by hand; regenerate with tool/generate_screens.js.\n` +
    `import 'package:flutter/material.dart';\n\nimport '../fig/fig.dart';\n\n` +
    `/// ${title} — ${num(px(st.width))}×${num(px(st.height))}\n` +
    `class ${cls} extends StatelessWidget {\n` +
    `  const ${cls}({super.key});\n\n` +
    `  static const double designWidth = ${num(px(st.width))};\n` +
    `  static const double designHeight = ${num(px(st.height))};\n\n` +
    (tabBarAt
      ? `  /// Where the mockup draws the tab bar on this screen.\n`
        + `  static const Offset tabBarAt = Offset(${num(tabBarAt.left)}, ${num(tabBarAt.top)});\n\n`
        + (mockupTab === null
          ? ''
          : `  /// Which tab the mockup draws highlighted here.\n`
            + `  static const int mockupTab = ${mockupTab};\n\n`)
      : '') +
    `  @override\n  Widget build(BuildContext context) {\n    return ` +
    body.s.trimStart().trimEnd() +
    `;\n  }\n}\n\n` +
    consts +
    '\n';
  fs.writeFileSync(path.join(dir, file + '.dart'), src);
  meta.push({ cls, file, title, w: px(st.width), h: px(st.height), tabBarAt });
}

if (tabBarSource) {
  fs.writeFileSync(path.join(OUT, 'lib', 'fig', 'tab_bar.dart'), emitTabBar(tabBarSource));
}
console.log('tab bar on:', meta.filter((m) => m.tabBarAt).map((m) => m.cls).join(', '));

console.log('screens written:', meta.length);
console.log('assets:', [...usedAssets].join(', '));
