#if os(iOS) || os(tvOS)
import UIKit
public typealias CacheImage = UIImage
#elseif os(watchOS)

#elseif os(OSX)
import AppKit
public typealias CacheImage = NSImage
#endif
