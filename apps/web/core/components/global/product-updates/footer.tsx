import { USER_TRACKER_ELEMENTS } from "@plane/constants";
import { useTranslation } from "@plane/i18n";
// ui
import { getButtonStyling } from "@plane/propel/button";
import { PlaneLogo } from "@plane/propel/icons";
// helpers
import { cn } from "@plane/utils";

export const ProductUpdatesFooter = () => {
  const { t } = useTranslation();
  return (
    <div className="flex items-center justify-between flex-shrink-0 gap-4 m-6 mb-4">
      <div className="flex items-center gap-2">
        <a
          href="mailto:aadyatechnovates@gmail.com"
          target="_blank"
          className="text-sm text-custom-text-200 hover:text-custom-text-100 hover:underline underline-offset-1 outline-none"
        >
          {t("support")}
        </a>
      </div>
      <div className="flex gap-1.5 items-center text-sm text-custom-text-200">
        <PlaneLogo className="h-4 w-auto text-custom-text-100" />
        AadyaBoard
      </div>
    </div>
  );
};
