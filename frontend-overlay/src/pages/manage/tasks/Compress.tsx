import { useManageTitle, useT } from "~/hooks"
import { VStack } from "@hope-ui/solid"
import { TypeTasks } from "~/pages/manage/tasks/Tasks"
import { getPath } from "~/pages/manage/tasks/helper"

const Compress = () => {
  const t = useT()
  useManageTitle("manage.sidemenu.compress")
  // Task name format from backend:
  // compress [/src/a /src/b] -> [/dst]/archive.zip
  const nameAnalyzer = {
    regex: /^compress \[(.*)] -> \[(.*)]\/(.*)$/,
    title: (matches: string[]) => matches[3] || "archive.zip",
    attrs: {
      [t(`tasks.attr.copy.src`)]: (matches: string[]) => matches[1] || "",
      [t(`tasks.attr.copy.dst`)]: (matches: string[]) =>
        getPath(matches[2] || "", matches[3] || ""),
    },
  }
  return (
    <VStack w="$full" alignItems="start" spacing="$4">
      <TypeTasks type="compress" canRetry nameAnalyzer={nameAnalyzer} />
    </VStack>
  )
}

export default Compress
