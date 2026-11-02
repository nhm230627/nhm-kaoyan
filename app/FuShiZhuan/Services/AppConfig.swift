//  AppConfig.swift —— 运行时配置                                       // 文件说明
//  BFF 地址、请求令牌、设备标识都从这里取，页面不许自己拼             // 使用约束
//  真机必须改成局域网 IP 或公网 HTTPS，127.0.0.1 只有模拟器能连        // 部署提醒

import Foundation                                                     // 基础库

enum AppConfig {                                                      // 全局配置
    /// BFF 服务地址。优先级：Info.plist 的 BFFBaseURL > 代码默认值
    static var bffBaseURL: URL {                                      // 服务基地址
        if let raw = Bundle.main.object(forInfoDictionaryKey: "BFFBaseURL") as? String, // 读配置
           let url = URL(string: raw) {                               // 能转成 URL
            return url                                                // 用配置值
        }                                                             // 分支结束
        return URL(string: "http://127.0.0.1:4318")!                  // 默认本机调试地址
    }                                                                 // 属性结束

    /// 客户端令牌，必须与 BFF 的 SERVICE_TOKEN 一致
    static var serviceToken: String {                                 // 请求令牌
        (Bundle.main.object(forInfoDictionaryKey: "BFFServiceToken") as? String) ?? "dev-token-change-me" // 缺省用开发令牌
    }                                                                 // 属性结束

    /// 设备唯一标识。首次生成后持久化，用于服务端限流
    static var deviceID: String {                                     // 设备标识
        let key = "app.device.id"                                     // 存储键
        if let saved = UserDefaults.standard.string(forKey: key) {     // 已有值
            return saved                                              // 直接用
        }                                                             // 分支结束
        let fresh = UUID().uuidString                                 // 生成新标识
        UserDefaults.standard.set(fresh, forKey: key)                 // 存起来
        return fresh                                                  // 返回
    }                                                                 // 属性结束

    /// 单次请求超时（秒）
    static let requestTimeout: TimeInterval = 60                      // 与 BFF 的 TIMEOUT_MS 对齐

    /// 是否走本地 Mock。true = 不联网、不烧额度，只验界面与状态机
    /// 开关在 Info.plist 的 UseMockService；换真机演示前记得改回 false
    static var useMockService: Bool {                                 // 服务实现开关
        (Bundle.main.object(forInfoDictionaryKey: "UseMockService") as? Bool) ?? false // 缺省走真实服务
    }                                                                 // 属性结束
}                                                                     // AppConfig 结束
