// Components.d.ts — the complete catalog of the 60 component(s) in
// Components.bundle.js. READ THIS FILE BEFORE USING THE BUNDLE: component
// names are derived from Figma layer names (sanitized to PascalCase,
// deduplicated) and may differ from what the design calls them — the
// "figma layer" comment above each interface maps them back.
// After the bundle <script> loads, every component is a window global
// (e.g. window.ArrowRight) and usable directly in JSX.
import * as React from 'react';

// figma layer: "Arrow Right" (node 57:65)
export interface ArrowRightProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Avatar" (node 57:95)
export interface AvatarProps {
  className?: string;
  style?: React.CSSProperties;
  size?: "l" | "m" | "s";
}

// figma layer: "Badge" (node 57:88)
export interface BadgeProps {
  className?: string;
  style?: React.CSSProperties;
  number?: string;
  type?: "number" | "empty" | "icon";
  icon?: React.ReactNode;
}

// figma layer: "Brand" (node 155:343)
export interface BrandProps {
  className?: string;
  style?: React.CSSProperties;
  property1?: "discover" | "master card" | "visa";
}

// figma layer: "Button/Next" (node 3:146)
export interface ButtonNextProps {
  className?: string;
  style?: React.CSSProperties;
  /** Text content; defaults to "Далее". */
  text1?: string;
}

// figma layer: "Button Primary" (node 57:39)
export interface ButtonPrimaryProps {
  className?: string;
  style?: React.CSSProperties;
  showText?: boolean;
  text?: string;
  showLeftIcon?: boolean;
  showRightIcon?: boolean;
  rightIcon?: React.ReactNode;
  leftIcon?: React.ReactNode;
}

// figma layer: "Check" (node 57:58)
export interface CheckProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Checkbox" (node 57:77)
export interface CheckboxProps {
  className?: string;
  style?: React.CSSProperties;
  size?: "lg" | "md" | "sm";
  selected?: boolean;
  /** Swappable nested instance; defaults to the design's. */
  icon1?: React.ReactNode;
}

// figma layer: "Frame" (node 3:270)
export interface FrameProps {
  className?: string;
  style?: React.CSSProperties;
  property1?: "default";
}

// figma layer: "Frame 11133" (node 57:1842)
export interface Frame11133Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Frame 48096302" (node 155:380)
export interface Frame48096302Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Frame 48096303" (node 155:1549)
export interface Frame48096303Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Frame 48096304" (node 155:1750)
export interface Frame48096304Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Frame 48096328" (node 155:1181)
export interface Frame48096328Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Heart Filled" (node 57:62)
export interface HeartFilledProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "List Item" (node 57:108)
export interface ListItemProps {
  className?: string;
  style?: React.CSSProperties;
  showTitle?: boolean;
  title?: string;
  visuals?: "none" | "icon" | "avatar";
  description?: string;
  showDescription?: boolean;
  leftIcon?: React.ReactNode;
  controls?: "icon" | "toggle" | "checkbox" | "badge" | "none";
  rightIcon?: React.ReactNode;
  /** Swappable nested instance; defaults to the design's. */
  icon1?: React.ReactNode;
  /** Swappable nested instance; defaults to the design's. */
  icon2?: React.ReactNode;
}

// figma layer: "Placeholder" (node 57:35)
export interface PlaceholderProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Progress Bar" (node 57:44)
export interface ProgressBarProps {
  className?: string;
  style?: React.CSSProperties;
  progress?: "0%" | "25%" | "50%" | "75%" | "100%";
}

// figma layer: "Screen Corners / Top Corners" (node 2:19)
export interface ScreenCornersTopCornersProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 2:47)
export interface StartScreenProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 10:1286)
export interface StartScreen10Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:866)
export interface StartScreen11Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:1169)
export interface StartScreen12Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:3408)
export interface StartScreen13Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:1400)
export interface StartScreen14Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 60:118)
export interface StartScreen15Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:227)
export interface StartScreen16Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 62:783)
export interface StartScreen17Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:1481)
export interface StartScreen18Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 9:891)
export interface StartScreen19Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 4:403)
export interface StartScreen2Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:1722)
export interface StartScreen20Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 10:1475)
export interface StartScreen21Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:506)
export interface StartScreen22Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:1001)
export interface StartScreen23Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:1161)
export interface StartScreen24Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:1840)
export interface StartScreen25Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 64:1365)
export interface StartScreen26Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:2044)
export interface StartScreen27Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 64:187)
export interface StartScreen28Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 64:249)
export interface StartScreen29Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 4:447)
export interface StartScreen3Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:823)
export interface StartScreen30Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:901)
export interface StartScreen31Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:980)
export interface StartScreen32Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:1007)
export interface StartScreen33Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:1329)
export interface StartScreen34Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:1379)
export interface StartScreen35Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:1429)
export interface StartScreen36Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:1944)
export interface StartScreen37Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:2155)
export interface StartScreen38Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 155:2313)
export interface StartScreen39Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 4:501)
export interface StartScreen4Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:282)
export interface StartScreen5Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:606)
export interface StartScreen6Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 63:557)
export interface StartScreen7Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 57:392)
export interface StartScreen8Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Start screen" (node 4:541)
export interface StartScreen9Props {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Subscription plans" (node 57:213)
export interface SubscriptionPlansProps {
  className?: string;
  style?: React.CSSProperties;
}

// figma layer: "Toggle" (node 57:71)
export interface ToggleProps {
  className?: string;
  style?: React.CSSProperties;
  state?: "off" | "on";
}

declare const ArrowRight: React.FC<ArrowRightProps>;
declare const Avatar: React.FC<AvatarProps>;
declare const Badge: React.FC<BadgeProps>;
declare const Brand: React.FC<BrandProps>;
declare const ButtonNext: React.FC<ButtonNextProps>;
declare const ButtonPrimary: React.FC<ButtonPrimaryProps>;
declare const Check: React.FC<CheckProps>;
declare const Checkbox: React.FC<CheckboxProps>;
declare const Frame: React.FC<FrameProps>;
declare const Frame11133: React.FC<Frame11133Props>;
declare const Frame48096302: React.FC<Frame48096302Props>;
declare const Frame48096303: React.FC<Frame48096303Props>;
declare const Frame48096304: React.FC<Frame48096304Props>;
declare const Frame48096328: React.FC<Frame48096328Props>;
declare const HeartFilled: React.FC<HeartFilledProps>;
declare const ListItem: React.FC<ListItemProps>;
declare const Placeholder: React.FC<PlaceholderProps>;
declare const ProgressBar: React.FC<ProgressBarProps>;
declare const ScreenCornersTopCorners: React.FC<ScreenCornersTopCornersProps>;
declare const StartScreen: React.FC<StartScreenProps>;
declare const StartScreen10: React.FC<StartScreen10Props>;
declare const StartScreen11: React.FC<StartScreen11Props>;
declare const StartScreen12: React.FC<StartScreen12Props>;
declare const StartScreen13: React.FC<StartScreen13Props>;
declare const StartScreen14: React.FC<StartScreen14Props>;
declare const StartScreen15: React.FC<StartScreen15Props>;
declare const StartScreen16: React.FC<StartScreen16Props>;
declare const StartScreen17: React.FC<StartScreen17Props>;
declare const StartScreen18: React.FC<StartScreen18Props>;
declare const StartScreen19: React.FC<StartScreen19Props>;
declare const StartScreen2: React.FC<StartScreen2Props>;
declare const StartScreen20: React.FC<StartScreen20Props>;
declare const StartScreen21: React.FC<StartScreen21Props>;
declare const StartScreen22: React.FC<StartScreen22Props>;
declare const StartScreen23: React.FC<StartScreen23Props>;
declare const StartScreen24: React.FC<StartScreen24Props>;
declare const StartScreen25: React.FC<StartScreen25Props>;
declare const StartScreen26: React.FC<StartScreen26Props>;
declare const StartScreen27: React.FC<StartScreen27Props>;
declare const StartScreen28: React.FC<StartScreen28Props>;
declare const StartScreen29: React.FC<StartScreen29Props>;
declare const StartScreen3: React.FC<StartScreen3Props>;
declare const StartScreen30: React.FC<StartScreen30Props>;
declare const StartScreen31: React.FC<StartScreen31Props>;
declare const StartScreen32: React.FC<StartScreen32Props>;
declare const StartScreen33: React.FC<StartScreen33Props>;
declare const StartScreen34: React.FC<StartScreen34Props>;
declare const StartScreen35: React.FC<StartScreen35Props>;
declare const StartScreen36: React.FC<StartScreen36Props>;
declare const StartScreen37: React.FC<StartScreen37Props>;
declare const StartScreen38: React.FC<StartScreen38Props>;
declare const StartScreen39: React.FC<StartScreen39Props>;
declare const StartScreen4: React.FC<StartScreen4Props>;
declare const StartScreen5: React.FC<StartScreen5Props>;
declare const StartScreen6: React.FC<StartScreen6Props>;
declare const StartScreen7: React.FC<StartScreen7Props>;
declare const StartScreen8: React.FC<StartScreen8Props>;
declare const StartScreen9: React.FC<StartScreen9Props>;
declare const SubscriptionPlans: React.FC<SubscriptionPlansProps>;
declare const Toggle: React.FC<ToggleProps>;
declare global {
  interface Window {
    ArrowRight: React.FC<ArrowRightProps>;
    Avatar: React.FC<AvatarProps>;
    Badge: React.FC<BadgeProps>;
    Brand: React.FC<BrandProps>;
    ButtonNext: React.FC<ButtonNextProps>;
    ButtonPrimary: React.FC<ButtonPrimaryProps>;
    Check: React.FC<CheckProps>;
    Checkbox: React.FC<CheckboxProps>;
    Frame: React.FC<FrameProps>;
    Frame11133: React.FC<Frame11133Props>;
    Frame48096302: React.FC<Frame48096302Props>;
    Frame48096303: React.FC<Frame48096303Props>;
    Frame48096304: React.FC<Frame48096304Props>;
    Frame48096328: React.FC<Frame48096328Props>;
    HeartFilled: React.FC<HeartFilledProps>;
    ListItem: React.FC<ListItemProps>;
    Placeholder: React.FC<PlaceholderProps>;
    ProgressBar: React.FC<ProgressBarProps>;
    ScreenCornersTopCorners: React.FC<ScreenCornersTopCornersProps>;
    StartScreen: React.FC<StartScreenProps>;
    StartScreen10: React.FC<StartScreen10Props>;
    StartScreen11: React.FC<StartScreen11Props>;
    StartScreen12: React.FC<StartScreen12Props>;
    StartScreen13: React.FC<StartScreen13Props>;
    StartScreen14: React.FC<StartScreen14Props>;
    StartScreen15: React.FC<StartScreen15Props>;
    StartScreen16: React.FC<StartScreen16Props>;
    StartScreen17: React.FC<StartScreen17Props>;
    StartScreen18: React.FC<StartScreen18Props>;
    StartScreen19: React.FC<StartScreen19Props>;
    StartScreen2: React.FC<StartScreen2Props>;
    StartScreen20: React.FC<StartScreen20Props>;
    StartScreen21: React.FC<StartScreen21Props>;
    StartScreen22: React.FC<StartScreen22Props>;
    StartScreen23: React.FC<StartScreen23Props>;
    StartScreen24: React.FC<StartScreen24Props>;
    StartScreen25: React.FC<StartScreen25Props>;
    StartScreen26: React.FC<StartScreen26Props>;
    StartScreen27: React.FC<StartScreen27Props>;
    StartScreen28: React.FC<StartScreen28Props>;
    StartScreen29: React.FC<StartScreen29Props>;
    StartScreen3: React.FC<StartScreen3Props>;
    StartScreen30: React.FC<StartScreen30Props>;
    StartScreen31: React.FC<StartScreen31Props>;
    StartScreen32: React.FC<StartScreen32Props>;
    StartScreen33: React.FC<StartScreen33Props>;
    StartScreen34: React.FC<StartScreen34Props>;
    StartScreen35: React.FC<StartScreen35Props>;
    StartScreen36: React.FC<StartScreen36Props>;
    StartScreen37: React.FC<StartScreen37Props>;
    StartScreen38: React.FC<StartScreen38Props>;
    StartScreen39: React.FC<StartScreen39Props>;
    StartScreen4: React.FC<StartScreen4Props>;
    StartScreen5: React.FC<StartScreen5Props>;
    StartScreen6: React.FC<StartScreen6Props>;
    StartScreen7: React.FC<StartScreen7Props>;
    StartScreen8: React.FC<StartScreen8Props>;
    StartScreen9: React.FC<StartScreen9Props>;
    SubscriptionPlans: React.FC<SubscriptionPlansProps>;
    Toggle: React.FC<ToggleProps>;
  }
}
