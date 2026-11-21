package data

import (
	"fmt"
	"os"

	"github.com/OpenListTeam/OpenList/v4/cmd/flags"
	"github.com/OpenListTeam/OpenList/v4/internal/db"
	"github.com/OpenListTeam/OpenList/v4/internal/model"
	"github.com/OpenListTeam/OpenList/v4/internal/op"
	"github.com/OpenListTeam/OpenList/v4/pkg/utils"
	"github.com/OpenListTeam/OpenList/v4/pkg/utils/random"
	"github.com/pkg/errors"
	"gorm.io/gorm"
)

func initUser() {
	initAdmin()
	initGuest()
}

func initAdmin() {
	_, err := op.GetAdmin()
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			// OpenList-CAS: 首次启动自动创建管理员，密码随机生成并打印到控制台。
			// 优先级：OPENLIST_ADMIN_PASSWORD 环境变量 > --dev 模式固定 "admin" > 随机密码。
			adminPassword := random.String(8)
			envpass := os.Getenv("OPENLIST_ADMIN_PASSWORD")
			if flags.Dev {
				adminPassword = "admin"
			} else if len(envpass) > 0 {
				adminPassword = envpass
			}
			// 不再 return，始终创建管理员（CAS 分支期望开箱即用）

			salt := random.String(16)
			admin := &model.User{
				Username: "admin",
				Salt:     salt,
				PwdHash:  model.TwoHashPwd(adminPassword, salt),
				Role:     model.ADMIN,
				BasePath: "/",
				Authn:    "[]",
				// 0(can see hidden) - 8(webdav read) & 12(can read archives) - 14(can share)
				Permission: 0x71FF,
			}
			if err := op.CreateUser(admin); err != nil {
				panic(err)
			} else {
				// DO NOT output the password to log file. Only output to console.
				// utils.Log.Infof("Successfully created the admin user and the initial password is: %s", adminPassword)
				fmt.Printf("Successfully created the admin user and the initial password is: %s\n", adminPassword)
			}
		} else {
			utils.Log.Fatalf("[init user] Failed to get admin user: %v", err)
		}
	}
}

func initGuest() {
	_, err := op.GetGuest()
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			salt := random.String(16)
			guest := &model.User{
				Username:   "guest",
				PwdHash:    model.TwoHashPwd("guest", salt),
				Salt:       salt,
				Role:       model.GUEST,
				BasePath:   "/",
				Permission: 0,
				Disabled:   true,
				Authn:      "[]",
			}
			if err := db.CreateUser(guest); err != nil {
				utils.Log.Fatalf("[init user] Failed to create guest user: %v", err)
			}
		} else {
			utils.Log.Fatalf("[init user] Failed to get guest user: %v", err)
		}
	}
}
