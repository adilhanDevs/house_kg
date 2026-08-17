// Components.d.ts — the complete catalog of the 3 component(s) in
// Components.bundle.js. READ THIS FILE BEFORE USING THE BUNDLE: component
// names are derived from Figma layer names (sanitized to PascalCase,
// deduplicated) and may differ from what the design calls them — the
// "figma layer" comment above each interface maps them back.
// After the bundle <script> loads, every component is a window global
// (e.g. window.ScreenCornersTopCorners) and usable directly in JSX.
import * as React from 'react';

// figma layer: "Screen Corners / Top Corners" (node 2:19)
export interface ScreenCornersTopCornersProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:812)
export interface StartScreenProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:855)
export interface StartScreen2Props {
  className?: string;
  style?: React.CSSProperties;
}

declare const ScreenCornersTopCorners: React.FC<ScreenCornersTopCornersProps>;
declare const StartScreen: React.FC<StartScreenProps>;
declare const StartScreen2: React.FC<StartScreen2Props>;
declare global {
  interface Window {
    ScreenCornersTopCorners: React.FC<ScreenCornersTopCornersProps>;
    StartScreen: React.FC<StartScreenProps>;
    StartScreen2: React.FC<StartScreen2Props>;
  }
}
