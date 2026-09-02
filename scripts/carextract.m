// carextract.m — 用 CoreUI 私有 API 提取 .car 中的图片资产
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface CUINamedImage : NSObject
- (CGImageRef)image;
@end

@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (CUINamedImage *)imageWithName:(NSString *)name scaleFactor:(CGFloat)scale;
- (CUINamedImage *)iconImageWithName:(NSString *)name scaleFactor:(CGFloat)scale displayGamut:(NSInteger)gamut layoutDirection:(NSInteger)dir desiredSize:(CGSize)size;
- (BOOL)containsLookupForName:(NSString *)name;
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 3) { printf("usage: carextract <car> <outdir> [namelist]\n"); return 1; }
        NSString *carPath = [NSString stringWithUTF8String:argv[1]];
        NSString *outDir = [NSString stringWithUTF8String:argv[2]];
        [[NSFileManager defaultManager] createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:nil];

        NSError *err = nil;
        CUICatalog *catalog = [[CUICatalog alloc] initWithURL:[NSURL fileURLWithPath:carPath] error:&err];
        if (!catalog) { printf("ERROR init: %s\n", err.localizedDescription.UTF8String ?: "?"); return 1; }
        printf("catalog ok\n");

        int ok = 0, fail = 0;
        // 如果给了 namelist 就只提取列表内的,否则提取全部已知名字(从 assetutil 生成)
        NSMutableArray<NSString*> *names = [NSMutableArray array];
        NSMutableArray<NSNumber*> *scales = [NSMutableArray array];
        if (argc >= 4) {
            NSString *list = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[3]] encoding:NSUTF8StringEncoding error:nil];
            for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
                if (line.length < 3) continue;
                NSArray *parts = [line componentsSeparatedByString:@"\t"];
                if (parts.count != 2) continue;
                if ([parts[0] hasPrefix:@"ZZZZ"]) continue;
                [names addObject:parts[0]];
                [scales addObject:@([parts[1] doubleValue])];
            }
        }
        for (NSUInteger i = 0; i < names.count; i++) {
            NSString *name = names[i];
            CGFloat scale = scales[i].doubleValue;
            CUINamedImage *namedImage = [catalog imageWithName:name scaleFactor:scale];
            if (!namedImage) {
                namedImage = [catalog iconImageWithName:name scaleFactor:scale displayGamut:0 layoutDirection:0 desiredSize:CGSizeMake(0, 0)];
            }
            CGImageRef cg = [namedImage image];
            if (!cg) { fail++; continue; }
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
            NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if (!png) { fail++; continue; }
            NSString *safe = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
            NSString *fname = [NSString stringWithFormat:@"%@@%dx.png", safe, (int)scale];
            [png writeToFile:[outDir stringByAppendingFormat:@"/%@", fname] atomically:YES];
            ok++;
        }
        printf("OK:%d FAIL:%d\n", ok, fail);
    }
    return 0;
}
