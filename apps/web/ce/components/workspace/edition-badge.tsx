import { useState } from "react";
import { observer } from "mobx-react";
// ui
import { useTranslation } from "@plane/i18n";
import { Button } from "@plane/propel/button";
import { Tooltip } from "@plane/propel/tooltip";
// hooks
import { usePlatformOS } from "@/hooks/use-platform-os";
import packageJson from "package.json";
// local components
import { PaidPlanUpgradeModal } from "../license";

export const WorkspaceEditionBadge = observer(() => {
  // Component hidden - Community badge removed
  return null;
});
