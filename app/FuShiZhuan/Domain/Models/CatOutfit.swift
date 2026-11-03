//  CatOutfit.swift —— 猫的换装数据模型                                // 文件说明
//  设计原则：**配件是数据，不是代码**。加一件新衣服只改 Resources/outfits.json，
//  不用改 Swift；几何形状由 slot 决定，颜色/名称/解锁条件全由 JSON 给。      // 可扩展约束
//  形象固定为「猫」——这是产品设定，不做多物种。                            // 产品约束

import Foundation  // 基础库
import UIKit  // 颜色

// MARK: - 槽位                                                        // 分节：槽位

enum OutfitSlot: String, Codable, CaseIterable, Identifiable {  // 可穿戴部位
    case fur  // 毛色（不算配件，但同样可换）
    case hat  // 头部
    case face  // 脸部（眼镜）
    case neck  // 颈部（围巾/项圈）
    case back  // 背部（披风/背包）

    var id: String { rawValue }  // 用原始值当 id

    var title: String {  // 分类名
        switch self {  // 按部位分支
        case .fur: "毛色"  // 毛色
        case .hat: "头顶"  // 帽子
        case .face: "脸部"  // 眼镜
        case .neck: "颈部"  // 围巾项圈
        case .back: "背上"  // 披风背包
        }  // 分支结束
    }  // title 结束
}  // OutfitSlot 结束

// MARK: - 配件                                                        // 分节：配件

struct OutfitItem: Codable, Identifiable, Equatable {  // 一件配件
    let id: String  // 唯一 id，如 "hat.graduate"
    let slot: OutfitSlot  // 装在哪个部位
    let name: String  // 显示名
    let detail: String  // 一句说明
    let hex: String  // 主色
    let accentHex: String?  // 点缀色，没有就用主色
    let minGrowth: Int  // 解锁所需成长值，0 表示一开始就有

    var accent: String { accentHex ?? hex }  // 点缀色兜底
}  // OutfitItem 结束

// MARK: - 目录                                                        // 分节：目录

struct OutfitCatalog: Codable {  // 配件总表
    struct Meta: Codable {  // 元信息
        let version: String  // 版本
        let note: String  // 备注
    }  // Meta 结束
    let meta: Meta  // 元信息
    let items: [OutfitItem]  // 全部配件

    func items(in slot: OutfitSlot) -> [OutfitItem] {  // 取某一部位的全部配件
        items.filter { $0.slot == slot }  // 按槽位筛
    }  // 方法结束

    func item(id: String) -> OutfitItem? {  // 按 id 找配件
        items.first { $0.id == id }  // 线性找，数量小无所谓
    }  // 方法结束

    static let empty = OutfitCatalog(  // 兜底空目录，JSON 读失败时用
        meta: .init(version: "0", note: "配件表未加载"),  // 元信息
        items: []  // 没有配件
    )  // 兜底结束

    static let shared = load()  // 全 App 共用一份，避免反复读盘

    static func load() -> OutfitCatalog {  // 从 App 包里读 outfits.json
        guard let url = Bundle.main.url(forResource: "outfits", withExtension: "json"),  // 找文件
              let data = try? Data(contentsOf: url),  // 读字节
              let catalog = try? JSONDecoder().decode(OutfitCatalog.self, from: data) else {  // 解码
            return .empty  // 任何一步失败都退回空目录，不崩
        }  // 分支结束
        return catalog  // 读成功就用它
    }  // load 结束
}  // OutfitCatalog 结束

// MARK: - 当前穿戴                                                    // 分节：穿戴状态

struct CatOutfit: Codable, Equatable {  // 猫当前穿什么
    var chosen: [String: String]  // 槽位原始值 -> 配件 id

    static let `default` = CatOutfit(chosen: [  // 默认：奶白猫 + 学士帽
        OutfitSlot.fur.rawValue: "fur.orange",  // 默认橘猫，与样板一致
        OutfitSlot.hat.rawValue: "hat.graduate"  // 默认戴学士帽，贴考研主题
    ])  // 默认值结束

    func id(for slot: OutfitSlot) -> String? {  // 取某部位的配件 id
        chosen[slot.rawValue]  // 直接查字典
    }  // 方法结束

    mutating func set(_ itemID: String, for slot: OutfitSlot) {  // 换上一件
        chosen[slot.rawValue] = itemID  // 覆盖该槽位
    }  // 方法结束
}  // CatOutfit 结束

// MARK: - 颜色工具                                                    // 分节：颜色

extension UIColor {  // 十六进制转颜色
    convenience init(hex: String) {  // "F5E6D3" 或 "#F5E6D3"
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)  // 去空白
        if text.hasPrefix("#") { text.removeFirst() }  // 去掉井号
        var value: UInt64 = 0  // 解析结果
        Scanner(string: text).scanHexInt64(&value)  // 十六进制转整数
        let r = CGFloat((value & 0xFF0000) >> 16) / 255.0  // 红
        let g = CGFloat((value & 0x00FF00) >> 8) / 255.0  // 绿
        let b = CGFloat(value & 0x0000FF) / 255.0  // 蓝
        self.init(red: r, green: g, blue: b, alpha: 1)  // 组装
    }  // 构造结束
}  // 扩展结束
