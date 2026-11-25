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
  const [perItem, setPerItem] = createSignal(false)
  const [srcPath, setSrcPath] = createSignal("")
  const [srcName, setSrcName] = createSignal<string[]>([])
  const [selectedDirs, setSelectedDirs] = createSignal(0)
  const [archiveName, setArchiveName] = createSignal("archive.zip")

  const label = (key: string, fallback: string) => {
    const v = t(key)
    // hope/i18n often returns the key itself when missing
    if (!v || v === key || v.startsWith("home.toolbar.")) return fallback
    return v
  }

  const handler = (name: string) => {
    if (name !== "compress") return
    const objs = selectedObjs()
    if (!objs.length) return
    const path = pathname()
    const dirs = objs.filter((o) => o.is_dir).length
    const multi = objs.length > 1
    const base =
      objs.length === 1
        ? (objs[0].is_dir
            ? objs[0].name
            : objs[0].name.replace(/\.[^.]+$/, "")) + ".zip"
        : "archive.zip"
    batch(() => {
      setSrcPath(path)
      setSrcName(objs.map((o) => o.name))
      setSelectedDirs(dirs)
      setArchiveName(base.endsWith(".zip") ? base : base + ".zip")
      setOverwrite(false)
      // multi-select → default each item; single folder → default pack as one zip
      setPerItem(multi)
    })
    onOpen()
  }
  bus.on("tool", handler)
  onCleanup(() => bus.off("tool", handler))

  const perItemHint = () => {
    if (srcName().length > 1) {
      return label(
        "home.toolbar.compress-per-item",
        "每个选中的文件/文件夹单独打成 zip",
      )
    }
    if (selectedDirs() === 1 && srcName().length === 1) {
      return label(
        "home.toolbar.compress-per-child",
        "将该文件夹下每个子文件夹/文件单独打成 zip（需后端 per_item）",
      )
    }
    return label(
      "home.toolbar.compress-per-item",
      "每个选中的文件/文件夹单独打成 zip",
    )
  }

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
                {label("home.toolbar.compress-name", "压缩包名称：")}
              </Text>
              <Input
                value={archiveName()}
                onInput={(e: any) => setArchiveName(e.target.value as string)}
                size="sm"
                flexGrow="1"
              />
            </HStack>
          </Show>
          <Show when={perItem()}>
            <Text size="sm" color="$neutral10">
              {srcName().length > 1
                ? `将生成 ${srcName().length} 个 zip（按选中项命名）`
                : "将展开该文件夹，对其下每个子项各生成一个 zip"}
            </Text>
          </Show>
          <Checkbox
            checked={perItem()}
            onChange={() => setPerItem(!perItem())}
          >
            {perItemHint()}
          </Checkbox>
          <Checkbox
            checked={overwrite()}
            onChange={() => setOverwrite(!overwrite())}
          >
            {t("home.conflict_policy.overwrite_existing") || "覆盖现有文件"}
          </Checkbox>
        </VStack>
      }
      onSubmit={async (dst) => {
        let name = archiveName().trim() || "archive.zip"
        if (!name.toLowerCase().endsWith(".zip")) name += ".zip"
        const paths = srcName().map((n) =>
          srcPath() === "/" ? `/${n}` : `${srcPath()}/${n}`,
        )
        // single folder + perItem: ask backend to expand children (per_item on one dir)
        const resp = await ok(paths, dst, name, overwrite(), perItem())
        handleRespWithNotifySuccess(resp, () => {
          refresh()
          onClose()
        })
      }}
    />
  )
}
