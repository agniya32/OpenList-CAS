import {
  Checkbox,
  createDisclosure,
  HStack,
  Input,
  Text,
  VStack,
} from "@hope-ui/solid"
import { useFetch, usePath, useRouter, useT } from "~/hooks"
import { bus, fsArchiveCompress, handleRespWithNotifySuccess } from "~/utils"
import { batch, createSignal, onCleanup, Show } from "solid-js"
import { ModalFolderChoose } from "~/components"
import { selectedObjs } from "~/store"
import { CreateFolderButton } from "./CopyMove"

export const Compress = () => {
  const t = useT()
  const { isOpen, onOpen, onClose } = createDisclosure()
  const [loading, ok] = useFetch(fsArchiveCompress)
  const { pathname } = useRouter()
  const { refresh } = usePath()
  const [overwrite, setOverwrite] = createSignal(false)
  const [perItem, setPerItem] = createSignal(true)
  const [srcPath, setSrcPath] = createSignal("")
  const [srcName, setSrcName] = createSignal<string[]>([])
  const [archiveName, setArchiveName] = createSignal("archive.zip")
  const handler = (name: string) => {
    if (name !== "compress") return
    const objs = selectedObjs()
    if (!objs.length) return
    const path = pathname()
    const multi = objs.length > 1
    const base =
      objs.length === 1
        ? objs[0].name.replace(/\.[^.]+$/, "") + ".zip"
        : "archive.zip"
    batch(() => {
      setSrcPath(path)
      setSrcName(objs.map((o) => o.name))
      setArchiveName(base.endsWith(".zip") ? base : base + ".zip")
      setOverwrite(false)
      // default: each selected folder/file -> own zip when multi-select
      setPerItem(multi || objs.some((o) => o.is_dir))
    })
    onOpen()
  }
  bus.on("tool", handler)
  onCleanup(() => bus.off("tool", handler))
  return (
    <ModalFolderChoose
      header={t("home.toolbar.choose_dst_folder")}
      opened={isOpen()}
      onClose={onClose}
      loading={loading()}
      defaultValue={srcPath}
      headerSlot={(handler) => <CreateFolderButton handler={handler} />}
      footerSlot={
        <VStack w="$full" spacing="$2" alignItems="flex-start">
          <Show when={!perItem()}>
            <HStack width="100%" spacing="$1">
              <Text size="sm" css={{ whiteSpace: "nowrap" }}>
                {t("home.toolbar.compress-name")}
              </Text>
              <Input
                value={archiveName()}
                onInput={(e: any) => setArchiveName(e.target.value as string)}
                size="sm"
                flexGrow="1"
              />
            </HStack>
          </Show>
          <Checkbox
            checked={perItem()}
            onChange={() => setPerItem(!perItem())}
          >
            {t("home.toolbar.compress-per-item")}
          </Checkbox>
          <Checkbox
            checked={overwrite()}
            onChange={() => setOverwrite(!overwrite())}
          >
            {t("home.conflict_policy.overwrite_existing")}
          </Checkbox>
        </VStack>
      }
      onSubmit={async (dst) => {
        let name = archiveName().trim() || "archive.zip"
        if (!name.toLowerCase().endsWith(".zip")) name += ".zip"
        const paths = srcName().map((n) =>
          srcPath() === "/" ? `/${n}` : `${srcPath()}/${n}`,
        )
        const resp = await ok(paths, dst, name, overwrite(), perItem())
        handleRespWithNotifySuccess(resp, () => {
          refresh()
          onClose()
        })
      }}
    />
  )
}
