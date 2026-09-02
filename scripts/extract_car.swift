import Foundation
import AppKit

// CUICatalog 通过 dlopen 私有框架加载
let path = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let frameworkPath = "/System/Library/PrivateFrameworks/CoreUI.framework"
dlopen(frameworkPath, RTLD_NOW)

// 用 NSClassFromString 拿 CUICatalog
guard let catalogClass = NSClassFromString("CUICatalog") as? NSObject.Type else {
    print("ERROR: CUICatalog class not found"); exit(1)
}
let catalog = catalogClass.init()
let sel = NSSelectorFromString("initWithURL:error:")
let url = URL(fileURLWithPath: path) as NSURL
let errPtr = UnsafeMutablePointer<NSError?>.allocate(capacity: 1)
let _ = catalog.perform(sel, with: url, with: errPtr)
if let e = errPtr.pointee { print("ERROR: \(e)"); exit(1) }

// 遍历所有 renditions
let allKeysSel = NSSelectorFromString("allKeyNames")
var keys: [String] = []
if catalog.responds(to: allKeysSel) {
    let result = catalog.perform(allKeysSel)
    if let result = result, let arr = result.takeUnretainedValue() as? [String] { keys = arr }
}
print("renditions: \(keys.count)")
for key in keys {
    let renditionsSel = NSSelectorFromString("renditionsForKey:")
    let result = catalog.perform(renditionsSel, with: key)
    guard let result = result, let renditions = result.takeUnretainedValue() as? [AnyObject] else { continue }
    for (i, r) in renditions.enumerated() {
        let pixelFmtSel = NSSelectorFromString("pixelFormat")
        let unslicedSel = NSSelectorFromString("unslicedImage")
        if r.responds(to: unslicedSel) {
            let imgResult = r.perform(unslicedSel)
            if let imgResult = imgResult, let image = imgResult.takeUnretainedValue() as? NSImage {
                guard let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { continue }
                let safeKey = key.replacingOccurrences(of: "/", with: "_")
                let fname = renditions.count > 1 ? "\(safeKey)-\(i).png" : "\(safeKey).png"
                try png.write(to: URL(fileURLWithPath: "\(outDir)/\(fname)"))
            }
        }
    }
}
print("DONE")
