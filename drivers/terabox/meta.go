package terabox

import (
	"github.com/OpenListTeam/OpenList/v4/internal/driver"
	"github.com/OpenListTeam/OpenList/v4/internal/op"
)

type Addition struct {
	driver.RootPath
	// Cookie: full browser cookie, or only the ndus value (auto-wrapped as ndus=...; lang=en).
	Cookie string `json:"cookie" required:"true" help:"Full Cookie from browser, or only the ndus token value"`
	//JsToken        string `json:"js_token" type:"string" required:"true"`
	DownloadAPI    string `json:"download_api" type:"select" options:"official,crack" default:"official" help:"official: /api/download with sign; crack: /api/filemetas dlink. Official falls back to crack on failure."`
	OrderBy        string `json:"order_by" type:"select" options:"name,time,size" default:"name"`
	OrderDirection string `json:"order_direction" type:"select" options:"asc,desc" default:"asc"`
	SnippetProxy   string `json:"snippet_proxy" help:"Cloudflare Snippet base URL, e.g. https://dl.oooo.ddns-ip.net (path /d/{base64url}). Terabox CDN may still require User-Agent/Cookie on the client."`
}

var config = driver.Config{
	Name:        "Terabox",
	DefaultRoot: "/",
}

func init() {
	op.RegisterDriver(func() driver.Driver {
		return &Terabox{}
	})
}
