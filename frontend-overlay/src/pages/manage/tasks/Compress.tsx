import { useManageTitle } from "~/hooks"
import { VStack } from "@hope-ui/solid"
import { TypeTasks } from "~/pages/manage/tasks/Tasks"

const Compress = () => {
  useManageTitle("manage.sidemenu.compress")
  return (
    <VStack w="$full" alignItems="start" spacing="$4">
      <TypeTasks type="compress" canRetry />
    </VStack>
  )
}

export default Compress
