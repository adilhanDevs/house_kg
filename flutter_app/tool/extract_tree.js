// Render the Figma-materialized React bundle into a plain JSON tree.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// the html prototype lives one directory up from the flutter project
const ROOT = path.resolve(__dirname, '..', '..');
const BUNDLE = path.join(ROOT, 'screens', 'Components.bundle.js');
// the contractor registration comes from its own bundle, as it does in the html
const VERIFY_BUNDLE = path.join(ROOT, 'screens', 'verify', 'Components.bundle.js');

function flatten(arr, out = []) {
  for (const c of arr) {
    if (c === null || c === undefined || c === false || c === true) continue;
    if (Array.isArray(c)) flatten(c, out);
    else out.push(c);
  }
  return out;
}

const React = {
  createElement(type, props, ...children) {
    const kids = flatten(children);
    const p = Object.assign({}, props || {});
    if (typeof type === 'function') {
      if (kids.length) p.children = kids.length === 1 ? kids[0] : kids;
      const rendered = type(p);
      return rendered;
    }
    delete p.children;
    return { tag: type, props: p, children: kids };
  },
};

function run(file) {
  const sandbox = { React, window: {}, console };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(file, 'utf8'), sandbox, { filename: path.basename(file) });
  return sandbox;
}

const sandbox = run(BUNDLE);
const verify = run(VERIFY_BUNDLE);

const NAMES = ['StartScreen', 'StartScreen2', 'StartScreen3', 'StartScreen4', 'StartScreen5',
  'StartScreen6', 'StartScreen7', 'StartScreen8', 'StartScreen9', 'StartScreen10',
  'StartScreen11', 'StartScreen12', 'StartScreen13', 'StartScreen14', 'StartScreen15',
  'StartScreen16', 'StartScreen17', 'StartScreen18', 'StartScreen19', 'StartScreen20',
  'Frame11133', 'StartScreen21', 'StartScreen22', 'StartScreen23', 'StartScreen24',
  'StartScreen25', 'StartScreen26', 'StartScreen27', 'StartScreen28', 'StartScreen29',
  'StartScreen30', 'StartScreen31', 'StartScreen32', 'StartScreen33', 'StartScreen34',
  'StartScreen35', 'StartScreen36', 'StartScreen37', 'StartScreen38', 'StartScreen39',
  // ленты кадров: прототип показывает по одному кадру, сдвигая ленту влево
  // (`shift` в html). Пополнение — 5 кадров, объявление — 6, история трат — 4.
  'Frame48096303', 'Frame48096302', 'Frame48096304'];

// screens/verify/Components.bundle.js — регистрация исполнителя
const VERIFY_NAMES = ['PhotoVerify1', 'PhotoVerify2'];

const out = {};
for (const [names, scope] of [[NAMES, sandbox], [VERIFY_NAMES, verify]]) {
  for (const n of names) {
    const C = scope.window[n];
    if (!C) throw new Error('missing ' + n);
    out[n] = C({});
  }
}
const dest = process.argv[2] || path.join(__dirname, 'tree.json');
fs.writeFileSync(dest, JSON.stringify(out, null, 1));

// ---- survey ----
const styleKeys = new Map();
const tags = new Map();
const attrs = new Map();
const classes = new Set();
function walk(node) {
  if (typeof node === 'string' || typeof node === 'number') return;
  if (!node || !node.tag) return;
  tags.set(node.tag, (tags.get(node.tag) || 0) + 1);
  for (const [k, v] of Object.entries(node.props)) {
    if (k === 'style') {
      for (const sk of Object.keys(v || {})) styleKeys.set(sk, (styleKeys.get(sk) || 0) + 1);
    } else {
      attrs.set(node.tag + '.' + k, (attrs.get(node.tag + '.' + k) || 0) + 1);
      if (k === 'className' && typeof v === 'string') v.split(/\s+/).forEach(c => c && classes.add(c));
    }
  }
  (node.children || []).forEach(walk);
}
Object.values(out).forEach(walk);
const rep = {
  tags: [...tags.entries()].sort((a, b) => b[1] - a[1]),
  styleKeys: [...styleKeys.entries()].sort((a, b) => b[1] - a[1]),
  attrs: [...attrs.entries()].sort((a, b) => b[1] - a[1]),
  classes: [...classes],
};
fs.writeFileSync(dest.replace(/\.json$/, '.survey.json'), JSON.stringify(rep, null, 1));
console.log(JSON.stringify(rep, null, 1));
