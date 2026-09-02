# RunCat Rebuilt — 保存/重建项目

> **项目定位**：RunCat（`com.kyome.RunCat`）是一款经典的 macOS 菜单栏
> CPU 监控应用（猫随 CPU 占用率奔跑），作者 Takuto Nakamura。该应用已从
> Mac App Store **下架**。本项目是它的**保存/重建仓库**：基于作者开源的
> 精简版骨架 + 从原 App Store 包提取的完整资产，重建一个**未来随时可编译**的版本，
> 防止资产与构建知识随时间丢失。

- 代码：基于 Apache-2.0 开源项目 [Kyome22/menubar_runcat](https://github.com/Kyome22/menubar_runcat)
- 资产：从下架前的 App Store 完整版（v12.8.0）二进制中提取（提取流程见 `scripts/extract-assets.md`）
- 构建：纯 SwiftPM（`swift build`），只需 Command Line Tools，**不需要完整 Xcode**

## 功能

- 菜单栏猫奔跑动画，帧率随 CPU 占用率变化（占用越高跑得越快）
- 菜单可切换显示 CPU 占用百分比（默认显示）
- About 面板、登录项设置指引（手动到 系统设置 → 通用 → 登录项 添加）、退出
- 使用完整版 App Store 资产的猫帧（56x36 @1x）与原版应用图标
- 中英文本地化菜单文案

## 仓库结构

```
runcat-rebuilt/
├── Package.swift              # SwiftPM 清单（tools 5.9，即 Swift 5 语言模式，规避 Swift 6 严格并发）
├── Sources/RunCat/
│   ├── main.swift             # 入口（基于骨架）
│   ├── AppDelegate.swift      # NSStatusItem 帧动画 + 菜单（基于骨架，有修改）
│   └── CPU.swift              # mach_host 采样 CPU 占用率（基于骨架）
├── Resources/
│   ├── Assets.xcassets/       # 骨架 xcassets：猫帧已替换为完整版 cat-page-0..4，图标已替换为原版图标
│   ├── Info.plist             # .app 的 Info.plist（build.sh 直接拷贝）
│   ├── RunCat.entitlements    # 骨架沙盒 entitlements（留档参考，本地构建未签名使用）
│   └── *.lproj/               # 菜单文案（en / zh-Hans）
├── scripts/
│   ├── build.sh               # swift build + 手工组装 RunCat.app
│   ├── extract-assets.md      # 资产提取流程文档（CoreUI 私有 API）
│   ├── carextract.m           # 提取工具：ObjC 版（clang 编译）
│   ├── extract_car.swift      # 提取工具：Swift 动态派发版
│   └── asset_list.txt         # Assets.car 的 rendition 清单留档
├── assets/
│   ├── runners/<角色>/        # 525 张 PNG 全量留档，90+ 种角色 × 5 帧（page-0..4@1x）
│   └── icons/                 # 原版应用图标（AppIcon-large.png 为 1024x1024）
├── LICENSE                    # Apache-2.0（注明代码基于 menubar_runcat）
└── README.md
```

## 构建与运行

系统要求：macOS 10.14+，Xcode Command Line Tools（`xcode-select --install`）。

```bash
./scripts/build.sh        # swift build -c release 并组装 RunCat.app
open RunCat.app           # 运行（也可以拖进「应用程序」文件夹）
```

`build.sh` 会：

1. `swift build -c release` 编译 SPM 可执行文件；
2. 手工组装 `RunCat.app`（二进制、Info.plist、5 张猫帧 PNG、
   用 `sips`/`iconutil` 从原版 1024px 图标生成 `AppIcon.icns`、`.lproj` 文案）；
3. ad-hoc 签名（`codesign --force --sign -`，无需证书）。

日常开发也可以直接 `swift build && swift run`（注意：`swift run` 下
`Bundle.main` 不是 .app bundle，菜单栏动画帧会缺失，仅供编译调试用；
完整体验请用 `build.sh` 产物）。

## 换角色（可选）

默认角色是猫。`assets/runners/` 下有全部 90+ 种角色（如 `dragon`、
`otter`、`rocket` 等）。想换角色时，把 `assets/runners/<角色>/page-0..4@1x.png`
拷贝替换 `Resources/Assets.xcassets/cat-page-*.imageset/` 里的对应文件
（重命名为 `cat-page-N@1x.png`）后重新 `build.sh` 即可。

## 版权与使用边界（重要）

- **代码**：基于 Takuto Nakamura 的 Apache-2.0 开源项目
  [menubar_runcat](https://github.com/Kyome22/menubar_runcat)，按许可证
  要求以同样的许可证再分发，修改已在源文件头部注明。
- **资产**：`assets/` 与 `Resources/Assets.xcassets/` 中的动画帧、应用图标
  **提取自已下架的 App Store 二进制**，版权归 **Takuto Nakamura** 所有。
  这部分资产**仅供个人保存与学习自用**：
  - 不得单独再分发、上传到其他应用商店或用于商业用途；
  - 不得基于其构建分发给第三方的产品；
  - 若作者重新上架 RunCat，或作者提出要求，应立即删除相关资产。
- 本仓库整体不应被视为 RunCat 的替代分发渠道，而是作者开源代码 +
  个人留档资产的重建演示。

## 致谢

感谢 **Takuto Nakamura（Kyome22）** 创作了 RunCat 并将精简版以
Apache-2.0 开源。如果喜欢这个应用，请支持作者的其他作品
（[App Store @Kyome22](https://apps.apple.com/developer/kyome22/id1066110825)）。
