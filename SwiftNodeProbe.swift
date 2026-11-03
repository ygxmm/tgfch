import UIKit

@objc(SwiftNodeProbe)
public class SwiftNodeProbe: NSObject {
    @objc public static func probeCurrentView(_ view: UIView) {
        var dumpResult = "=== 开始扫描 Swift 节点 ===\n"
        for subview in view.subviews {
            dumpResult += scanView(subview, depth: 0)
        }
        
        let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = (docPath as NSString).appendingPathComponent("SwiftNodes.txt")
        
        do {
            try dumpResult.write(toFile: filePath, atomically: true, encoding: .utf8)
            showAlert(message: "扫描完成！共找到所有 Swift 节点。\n请去沙盒查看 SwiftNodes.txt")
        } catch {
            showAlert(message: "写入失败: \(error)")
        }
    }
    
    private static func scanView(_ view: UIView, depth: Int) -> String {
        if depth > 10 { return "" }
        var result = ""
        let className = NSStringFromClass(type(of: view))
        let indent = String(repeating: "  ", count: depth)
        
        if className.contains("Node") || className.contains("Message") || className.contains("Item") {
            result += "\(indent)🔍 [View] \(className)\n"
            let mirror = Mirror(reflecting: view)
            for child in mirror.children {
                if let label = child.label {
                    let lower = label.lowercased()
                    if lower.contains("message") || lower.contains("media") || lower.contains("item") || lower.contains("node") {
                        let valueDesc = String(describing: child.value)
                        let truncated = valueDesc.count > 150 ? String(valueDesc.prefix(150)) + "..." : valueDesc
                        result += "\(indent)  ├─ \(label): \(type(of: child.value))\n"
                        result += "\(indent)  │   值: \(truncated)\n"
                    }
                }
            }
        }
        
        for sub in view.subviews {
            result += scanView(sub, depth: depth + 1)
        }
        return result
    }
    
    private static func showAlert(message: String) {
        DispatchQueue.main.async {
            let window = UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
            guard let rootVC = window?.rootViewController else { return }
            let alert = UIAlertController(title: "Swift 探针", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            topVC.present(alert, animated: true, completion: nil)
        }
    }
}
