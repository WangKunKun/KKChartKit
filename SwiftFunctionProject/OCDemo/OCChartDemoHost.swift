import SwiftUI

/// SwiftUI 包装 OC 版图表 demo。
///
/// 用 `NSClassFromString` 运行时创建 OC 的 `OCChartDemoViewController`——
/// Swift 不编译期依赖 OC 类，**无需 OC bridging header、不改 pbxproj**。
/// Swift ↔ OC 双向：Swift 这里只创建并展示 VC；VC 内部用 OC 桥接 + Swift-Swift.h 跑图表。
struct OCChartDemoHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let className = "OCChartDemoViewController"
        if let cls = NSClassFromString(className) as? UIViewController.Type {
            return cls.init()
        }
        // 兜底：OC 类未找到（多因 Swift-Swift.h 未生成 / 混编未启用）
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "OCChartDemoViewController 未找到\n（检查 Swift↔OC 混编配置）"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
        ])
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
