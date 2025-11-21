"use client";

import { useTheme } from "next-themes";
import { PlaneLogo } from "@plane/propel/icons";

interface AadyaLogoProps {
  width?: string;
  height?: string;
  className?: string;
}

export const AadyaLogo: React.FC<AadyaLogoProps> = ({ width, height, className }) => {
  const { resolvedTheme } = useTheme();
  
  return (
    <PlaneLogo 
      width={width}
      height={height}
      className={className}
      theme={resolvedTheme === "dark" ? "dark" : "light"}
    />
  );
};
