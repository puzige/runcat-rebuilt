# RunCat Rebuilt — RunCat Classic 12.8 保存与兼容性重建

RunCat 是 Takuto Nakamura（Kyome22）创作的经典 macOS 菜单栏 CPU
监控应用：猫的奔跑速度会随 CPU 占用率变化。Classic 12.8 已从 Mac App
Store 下架，因此本项目以作者公开的精简版代码为骨架，结合从本人合法下载的
Classic 12.8 应用中提取的留档资产，进行个人保存、行为考证与现代 macOS
兼容性重建。

本项目的目的：

- 保存一个能够从源码重复构建的 RunCat Classic 版本，避免应用下架后丢失；
- 尽可能复现 Classic 12.8 的界面、交互、动画节奏和系统信息展示；
- 记录资产提取、构建、签名和视觉对照过程，方便未来继续维护；
- 为本仓库维护版提供集中、公开的帮助与问题反馈入口。

本项目不是 RunCat 官方版本，不代表或冒充原作者，不用于商业发行，也不把
留档资产重新包装为第三方产品。所有与本维护版有关的问题请在本仓库反馈，
请勿联系原作者要求支持本项目。

## 项目链接

- GitHub：[puzige/runcat-rebuilt](https://github.com/puzige/runcat-rebuilt)
- 使用与构建帮助：[README](https://github.com/puzige/runcat-rebuilt#readme)
- 问题反馈：[GitHub Issues](https://github.com/puzige/runcat-rebuilt/issues)

- 代码：基于 Apache-2.0 开源项目 [Kyome22/menubar_runcat](https://github.com/Kyome22/menubar_runcat)
- 资产：从下架前的 App Store 完整版（v12.8.0）二进制中提取（提取流程见 `scripts/extract-assets.md`）
- 构建：纯 SwiftPM（`swift build`），只需 Command Line Tools，**不需要完整 Xcode**

## 当前功能（0.3.30）

- Classic 12.8 同尺寸菜单栏仪表盘（基础尺寸 292 × 440 pt，遇到较长的
  电源适配器或本地化文本时按原版横向扩展）：CPU / 内存曲线、存储条、
  电池与网络信息，以及原版尺寸的四按钮侧栏；Store 和尚未实现的
  Self-Made 入口隐藏，剩余按钮从顶部连续排列、未使用空间留在底部
- 菜单栏角色动画，帧率随 CPU 占用率变化；可反转速度、水平翻转、使用
  系统强调色、停止动画或每 10 分钟随机切换
- Classic 单列角色选择浮层，完整角色资产与原文本地化名称
- 490 × 472 pt 独立设置窗口（General / System Info）
- About、Help 和 Report an Issue 均指向本项目 GitHub，另有 Activity
  Monitor、退出和右键后备菜单
- 10 种语言的 Classic 原始界面文案

这仍是分阶段复刻，不宣称整个 Classic 已经完成。Runners Store、Self-Made
编辑器和完整 System Info Bar 尚未达到验收标准；逐项状态和证据见
[`docs/CLASSIC-PARITY.md`](docs/CLASSIC-PARITY.md)。

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
│   ├── runners/<角色>/        # 525 张 PNG：78 种动画角色 + 睡眠/商店占位资产
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
2. 手工组装 `RunCat.app`（二进制、Info.plist、完整角色帧、SystemInfoKit
   resource bundle、原始 `.lproj` 文案，并生成 `AppIcon.icns`）；
3. ad-hoc 签名（`codesign --force --sign -`，无需证书）。

日常开发也可以直接 `swift build && swift run`（注意：`swift run` 下
`Bundle.main` 不是 .app bundle，菜单栏动画帧会缺失，仅供编译调试用；
完整体验请用 `build.sh` 产物）。

## 验证

```bash
./scripts/verify.sh
```

该门禁会从源码重建、验证签名与所有关键资源，并在本机启动 5 秒仪表盘
预览来捕获运行期崩溃。单独运行
`RunCat.app/Contents/MacOS/RunCat --preview-dashboard` 可以在不点击菜单栏的
情况下打开与真实弹窗相同材质、相同尺寸的视觉回归预览。

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
