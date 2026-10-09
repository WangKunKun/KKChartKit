import Foundation

/// 适配器拥有目标库依赖，业务模型不反向依赖适配器。Output 可以是原生配置或其他库的选项。
/// 实现必须先校验，并对不支持的语义报错；禁止静默丢字段或改成另一种坐标/堆叠规则。
public protocol ChartAdapter {
    /// 当前默认轴系描述；后续饼图/热力图可使用自己的强类型输入，避免塞入无关字段。
    associatedtype Input = ChartSpecification
    associatedtype Output
    var backendIdentifier: String { get }
    /// 包含通用输入问题和当前目标的能力问题；只读，不修改模型。
    func diagnostics(for specification: Input) -> [ChartSpecificationIssue]
    /// 成功返回目标配置；失败抛出带路径的错误。线程要求由具体适配器声明。
    func makeConfiguration(from specification: Input) throws -> Output
}

/// 可定位的问题，不通过日志、Bool 或任意底层错误码传递。
public struct ChartSpecificationIssue: Codable, Equatable, Sendable {
    /// invalidInput 表示模型无效；unsupportedCapability 表示模型有效但该后端不支持。
    public enum Code: String, Codable, Sendable { case invalidInput, unsupportedVersion, unsupportedCapability }
    public let code: Code
    public let path: String
    public let message: String
    /// path 使用 series[0].samples[1].value 等业务模型路径。
    public init(code: Code, path: String, message: String) {
        self.code = code; self.path = path; self.message = message
    }
}

/// Swift 抛错和 OC NSError 使用同一份诊断；userInfo["issues"] 包含所有路径与原因。
public struct ChartSpecificationError: Error, LocalizedError, CustomNSError, Sendable {
    public let issues: [ChartSpecificationIssue]
    public let backendIdentifier: String?
    public static var errorDomain: String { "HYMCharts.Specification" }
    public var errorCode: Int { 1 }
    public var errorDescription: String? { issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n") }
    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [NSLocalizedDescriptionKey: errorDescription ?? "Invalid chart specification",
            "issues": issues.map { ["code": $0.code.rawValue, "path": $0.path, "message": $0.message] }]
        if let backendIdentifier { info["backendIdentifier"] = backendIdentifier }
        return info
    }
    /// 适配器可附加 backendIdentifier，区分输入错误与具体引擎的限制。
    public init(issues: [ChartSpecificationIssue], backendIdentifier: String? = nil) {
        self.issues = issues; self.backendIdentifier = backendIdentifier
    }
}
