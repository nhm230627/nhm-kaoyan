//  AppError.swift —— 全局错误语义                                    // 文件说明
//  统一在这里定义，禁止各模块自造文案                                  // 使用约束

import Foundation  // 引入基础库

enum AppError: Error, Equatable {  // 错误类型枚举
    case network(String)  // 网络失败，带细节
    case timeout  // 请求超时
    case unauthorized  // 未登录 / 权益不足
    case quotaExceeded  // 今日次数用完
    case aiUnavailable(String)  // AI 服务不可用
    case speechDenied  // 麦克风权限被拒
    case speechUnavailable(String)  // 语音识别不可用
    case dataCorrupted(String)  // 本地数据损坏

    var title: String {  // 一句话说清发生了什么
        switch self {  // 按类型分支
        case .network: "网络连接失败"  // 网络
        case .timeout: "请求超时"  // 超时
        case .unauthorized: "需要登录"  // 鉴权
        case .quotaExceeded: "今日次数已用完"  // 额度
        case .aiUnavailable: "AI 服务暂时不可用"  // AI
        case .speechDenied: "麦克风权限未开启"  // 权限
        case .speechUnavailable: "语音识别不可用"  // 语音
        case .dataCorrupted: "本地数据读取失败"  // 数据
        }  // switch 结束
    }  // title 结束

    var action: String {  // 下一步具体动作
        switch self {  // 按类型分支
        case .network: "检查网络后点「重试」"  // 网络
        case .timeout: "点「重试」；持续超时请换网络"  // 超时
        case .unauthorized: "去「我的」页登录后重试"  // 鉴权
        case .quotaExceeded: "明天再来，或开通会员增加次数"  // 额度
        case .aiUnavailable: "点「重试」，连续两次失败请稍后再来"  // AI
        case .speechDenied: "去「设置 → 复试专 → 麦克风」打开权限"  // 权限
        case .speechUnavailable: "改用键盘输入，本次作答不受影响"  // 语音
        case .dataCorrupted: "点「重置本地数据」，会清空学习记录"  // 数据
        }  // switch 结束
    }  // action 结束

    var canDegrade: Bool {  // 能否降级继续
        switch self {  // 按类型分支
        case .speechDenied, .speechUnavailable: true  // 语音可改打字
        default: false  // 其它不可降级
        }  // switch 结束
    }  // canDegrade 结束

    /// 能否用本地粗评顶上。
    /// 只有「连不上 / 超时 / 模型挂了」才允许——额度用完、未登录这类是用户自己该知道的事实，不许用假分数盖住
    var allowsLocalFallback: Bool {  // 能否离线兜底
        switch self {  // 按类型分支
        case .network, .timeout, .aiUnavailable: true  // 服务侧问题，允许离线算
        case .unauthorized, .quotaExceeded, .speechDenied, .speechUnavailable, .dataCorrupted: false // 必须让用户看见
        }  // switch 结束
    }  // allowsLocalFallback 结束
}  // AppError 结束
