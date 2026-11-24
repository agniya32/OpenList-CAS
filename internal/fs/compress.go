package fs

import (
	"archive/zip"
	"context"
	"fmt"
	"io"
	"os"
	stdpath "path"
	"strings"
	"time"

	"github.com/OpenListTeam/OpenList/v4/internal/conf"
	"github.com/OpenListTeam/OpenList/v4/internal/driver"
	"github.com/OpenListTeam/OpenList/v4/internal/errs"
	"github.com/OpenListTeam/OpenList/v4/internal/model"
	"github.com/OpenListTeam/OpenList/v4/internal/op"
	"github.com/OpenListTeam/OpenList/v4/internal/stream"
	"github.com/OpenListTeam/OpenList/v4/internal/task"
	"github.com/OpenListTeam/OpenList/v4/internal/task_group"
	"github.com/OpenListTeam/OpenList/v4/pkg/utils"
	"github.com/OpenListTeam/tache"
	"github.com/pkg/errors"
)

// CompressUploadTask packs remote files/folders into a zip on the OpenList host,
// then uploads the archive to a destination directory (same or another storage).
// Typical use: OneDrive/SharePoint paths → zip → same SharePoint folder.
type CompressUploadTask struct {
	task.TaskExtension
	SrcPaths    []string
	DstDirPath  string
	ArchiveName string
	Overwrite   bool

	status   string
	tmpZip   string
	finalized bool
}

func (t *CompressUploadTask) GetName() string {
	return fmt.Sprintf("compress %v -> [%s]/%s", t.SrcPaths, t.DstDirPath, t.ArchiveName)
}

func (t *CompressUploadTask) GetStatus() string {
	return t.status
}

func (t *CompressUploadTask) Run() error {
	t.ClearEndTime()
	t.SetStartTime(time.Now())
	defer func() { t.SetEndTime(time.Now()) }()
	defer t.cleanup()

	if len(t.SrcPaths) == 0 {
		return errors.New("no source paths")
	}
	name := strings.TrimSpace(t.ArchiveName)
	if name == "" {
		name = "archive.zip"
	}
	if !strings.HasSuffix(strings.ToLower(name), ".zip") {
		name += ".zip"
	}
	t.ArchiveName = name

	dstStorage, dstDirActual, err := op.GetStorageAndActualPath(t.DstDirPath)
	if err != nil {
		return errors.WithMessage(err, "failed get dst storage")
	}
	if dstStorage.Config().NoUpload {
		return errors.WithStack(errs.UploadNotSupported)
	}
	if !t.Overwrite {
		if res, _ := op.Get(t.Ctx(), dstStorage, stdpath.Join(dstDirActual, name)); res != nil {
			return errs.ObjectAlreadyExists
		}
	}

	tmp, err := os.CreateTemp(conf.Conf.TempDir, "compress-*.zip")
	if err != nil {
		return err
	}
	t.tmpZip = tmp.Name()
	_ = tmp.Close()

	t.status = "compressing"
	if err := t.buildZip(t.Ctx(), t.tmpZip); err != nil {
		return err
	}

	info, err := os.Stat(t.tmpZip)
	if err != nil {
		return err
	}
	t.SetTotalBytes(info.Size())

	file, err := os.Open(t.tmpZip)
	if err != nil {
		return err
	}
	fs := &stream.FileStream{
		Obj: &model.Object{
			Name:     name,
			Size:     info.Size(),
			Modified: time.Now(),
		},
		Mimetype: "application/zip",
		Reader:   file,
	}
	fs.Closers.Add(file)

	t.status = "uploading"
	groupID := stdpath.Join(dstStorage.GetStorage().MountPath, dstDirActual)
	task_group.TransferCoordinator.AddTask(groupID, nil)
	err = op.Put(context.WithValue(t.Ctx(), conf.SkipHookKey, struct{}{}), dstStorage, dstDirActual, fs, t.SetProgress)
	task_group.TransferCoordinator.Done(context.WithoutCancel(t.Ctx()), groupID, err == nil)
	return err
}

func (t *CompressUploadTask) buildZip(ctx context.Context, zipPath string) error {
	f, err := os.Create(zipPath)
	if err != nil {
		return err
	}
	zw := zip.NewWriter(f)
	defer func() {
		_ = zw.Close()
		_ = f.Close()
	}()

	var totalFiles int
	for _, srcPath := range t.SrcPaths {
		srcPath = utils.FixAndCleanPath(srcPath)
		storage, actual, err := op.GetStorageAndActualPath(srcPath)
		if err != nil {
			return errors.WithMessagef(err, "src %s", srcPath)
		}
		obj, err := op.Get(ctx, storage, actual)
		if err != nil {
			return errors.WithMessagef(err, "get %s", srcPath)
		}
		rootName := obj.GetName()
		if obj.IsDir() {
			n, err := t.addDir(ctx, zw, storage, actual, rootName+"/")
			if err != nil {
				return err
			}
			totalFiles += n
		} else {
			if err := t.addFile(ctx, zw, storage, actual, rootName); err != nil {
				return err
			}
			totalFiles++
		}
	}
	if totalFiles == 0 {
		return errors.New("no files to compress")
	}
	return nil
}

func (t *CompressUploadTask) addDir(ctx context.Context, zw *zip.Writer, storage driver.Driver, dirPath, prefix string) (int, error) {
	if utils.IsCanceled(ctx) {
		return 0, ctx.Err()
	}
	objs, err := op.List(ctx, storage, dirPath, model.ListArgs{})
	if err != nil {
		return 0, errors.WithMessagef(err, "list %s", dirPath)
	}
	count := 0
	for _, obj := range objs {
		name := obj.GetName()
		child := stdpath.Join(dirPath, name)
		entry := prefix + name
		if obj.IsDir() {
			n, err := t.addDir(ctx, zw, storage, child, entry+"/")
			if err != nil {
				return count, err
			}
			count += n
			continue
		}
		if err := t.addFile(ctx, zw, storage, child, entry); err != nil {
			return count, err
		}
		count++
	}
	return count, nil
}

func (t *CompressUploadTask) addFile(ctx context.Context, zw *zip.Writer, storage driver.Driver, filePath, entryName string) error {
	if utils.IsCanceled(ctx) {
		return ctx.Err()
	}
	t.status = "compressing " + entryName
	link, obj, err := op.Link(ctx, storage, filePath, model.LinkArgs{})
	if err != nil {
		return errors.WithMessagef(err, "link %s", filePath)
	}
	ss, err := stream.NewSeekableStream(&stream.FileStream{
		Obj: obj,
		Ctx: ctx,
	}, link)
	if err != nil {
		_ = link.Close()
		return errors.WithMessagef(err, "stream %s", filePath)
	}
	defer func() { _ = ss.Close() }()

	hdr := &zip.FileHeader{
		Name:     entryName,
		Method:   zip.Deflate,
		Modified: obj.ModTime(),
	}
	w, err := zw.CreateHeader(hdr)
	if err != nil {
		return err
	}
	_, err = utils.CopyWithBuffer(w, ss)
	return err
}

func (t *CompressUploadTask) cleanup() {
	if t.finalized {
		return
	}
	t.finalized = true
	if t.tmpZip != "" {
		_ = os.Remove(t.tmpZip)
	}
}

func (t *CompressUploadTask) Cancel() {
	t.TaskExtension.Cancel()
	if !conf.Conf.Tasks.AllowRetryCanceled {
		t.cleanup()
	}
}

var CompressUploadTaskManager *tache.Manager[*CompressUploadTask]

// ArchiveCompress creates a background task that zips sources and uploads to dstDirPath.
func ArchiveCompress(ctx context.Context, srcPaths []string, dstDirPath, archiveName string, overwrite bool) (task.TaskExtensionInfo, error) {
	if len(srcPaths) == 0 {
		return nil, errors.New("no source paths")
	}
	dstDirPath = utils.FixAndCleanPath(dstDirPath)
	clean := make([]string, 0, len(srcPaths))
	for _, p := range srcPaths {
		p = utils.FixAndCleanPath(p)
		if p != "" && p != "/" {
			clean = append(clean, p)
		}
	}
	if len(clean) == 0 {
		return nil, errors.New("no valid source paths")
	}

	tsk := &CompressUploadTask{
		SrcPaths:    clean,
		DstDirPath:  dstDirPath,
		ArchiveName: archiveName,
		Overwrite:   overwrite,
	}
	if ctx.Value(conf.NoTaskKey) != nil {
		tsk.Base.SetCtx(ctx)
		return nil, tsk.Run()
	}
	tsk.Creator, _ = ctx.Value(conf.UserKey).(*model.User)
	tsk.ApiUrl = conf.GetApiUrl(ctx)
	CompressUploadTaskManager.Add(tsk)
	return tsk, nil
}
