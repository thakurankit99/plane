import * as React from "react";

import type { ISvgIcons } from "../type";

// AadyaBoard Logo Lockup Component
export const PlaneLockup: React.FC<ISvgIcons & { theme?: "light" | "dark" }> = ({
  width = "auto",
  height = "20",
  className,
  theme,
}) => {
  // For dark theme/dark UI, use dark logo
  // For light theme/light UI, use white logo
  // Default to light theme (white logo) if theme is not provided
  const isDark = theme === "dark";

  return (
    <img
      src={isDark ? "/assets/plane-logos/aadya-logo-dark.svg" : "/assets/plane-logos/aadya-logo-white.svg"}
      alt="AadyaBoard"
      style={{ width, height }}
      className={className}
    />
  );
};
