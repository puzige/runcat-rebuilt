# 资产提取流程记录

本文档记录 RunCat（com.kyome.RunCat）完整版 App Store 二进制中 `.car`
（asset catalog 编译产物）动画资产的提取流程。提取发生在 2026-09-02，
产物归档在本仓库 `assets/` 目录。

## 背景

RunCat 完整版的奔跑角色动画（猫、龙、鸟、寿司等 90+ 种）打包在

```
RunCat.app/Contents/Resources/Assets.car
```

`.car` 是 Xcode asset catalog 编译后的二进制格式，内部图片由 CoreUI
私有框架管理。常规 `assetutil` 只能查看清单，无法直接导出 PNG，所以
需要借助 CoreUI 的私有 API。

## 原始素材来源

| 来源 | 内容 |
| --- | --- |
| App Store 下载的 `RunCat.app`（v12.8.0，已从商店下架） | `Assets.car`、`AppIcon.icns`、Info.plist 等 |

## 第一步：生成资产清单（assetutil）

用 Xcode 自带的 `assetutil`（本机当时由 Command Line Tools 提供）列出
`.car` 内所有 rendition 的名字和缩放倍率：

```bash
xcrun assetutil --info RunCat.app/Contents/Resources/Assets.car \
    | jq -r 'select(.AssetType == "Image") | "\(.Name)\t\(.ScaleFactor)"' \
    | sort -u > asset_list.txt
```

得到 `asset_list.txt`（已留档于 `scripts/asset_list.txt`），每行格式为
`名字<TAB>倍率`，其中 `ZZZZPackedAsset-*` 开头的行是打包分组项，需过滤。
清单共 534 行，去除 3 行 ZZZZ 后为 531 个命名 rendition。

## 第二步：CoreUI 私有 API 提取

提供了两个等价实现（均已留档在本目录）：

### A. `carextract.m`（Objective-C，clang 编译）

直接声明 `CUICatalog` / `CUINamedImage` 的私有接口，用
`catalog imageWithName:scaleFactor:` 逐个取出 `CGImageRef` 并写 PNG：

```bash
clang -framework Foundation -framework AppKit carextract.m -o carextract
./carextract RunCat.app/Contents/Resources/Assets.car out-dir asset_list.txt
```

关键私有接口（不公开头文件，运行时由 CoreUI.framework 提供）：

```objc
@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (CUINamedImage *)imageWithName:(NSString *)name scaleFactor:(CGFloat)scale;
@end

@interface CUINamedImage : NSObject
- (CGImageRef)image;
@end
```

### B. `extract_car.swift`（Swift 动态派发）

不声明私有接口，改用 `dlopen` + `NSClassFromString` +
`perform(_:)` 动态调用 `allKeyNames` / `renditionsForKey:` /
`unslicedImage`，适合快速试验：

```bash
swift extract_car.swift RunCat.app/Contents/Resources/Assets.car out-dir
```

注意：`perform(_:)` 取回的对象需要 `takeUnretainedValue()`，且方法名
属于未文档化 API，随 macOS 版本可能变化（在 macOS 15.7 上验证可用）。

## 第三步：结果

- 输出 525 张 PNG（部分 rendition 导出失败属正常：`ZZZZ` 打包组、
  非 RNA 格式项等），命名 `名字@倍率x.png`，例如 `cat-page-0@1x.png`。
- 绝大多数资产只有 @1x；帧图尺寸如猫为 56x36 px。
- 覆盖 90+ 种奔跑角色，每个角色 page-0 到 page-4 五帧。
- 1024x1024 原版应用图标 `AppIcon-large.png` 从 App Icon rendition
  （`iconImageWithName:...`）导出。

## 本仓库如何使用这些资产

- `assets/runners/<角色>/` — 全量留档（不参与编译）。
- `Resources/Assets.xcassets/cat-page-*.imageset/` — 默认猫帧，替换
  骨架（menubar_runcat）的 `cat_page0-4`，供 Xcode 用户使用。
- `scripts/build.sh` — 将 `cat-page-0..4` 拷入 `.app` 的
  `Contents/Resources/`，运行时由 `AppDelegate` 直接读文件加载，
  绕开需要完整 Xcode 的 asset catalog 编译器。

## 版权提醒

`assets/` 与 `cat-page-*.png` 提取自已下架的 App Store 二进制，版权
归 Takuto Nakamura 所有，仅供个人保存与学习自用，不得单独再分发或
商用，详见仓库根目录 README.md。
