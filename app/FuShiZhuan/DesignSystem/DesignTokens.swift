//  DesignTokens.swift —— 设计令牌：与 Web 样板 CSS 变量一一对应            // 文件说明
//  改这里等于改全局皮肤；新页面禁止硬编码颜色、字号、圆角，一律引用本文件    // 使用约束

import SwiftUI  // 引入 SwiftUI

// MARK: - 颜色                                                          // 分节：颜色

extension Color {  // 给 Color 加静态色
    static let appBG = Color(hex: 0xF2F2F7)  // 页面底色
    static let appCard = Color(hex: 0xFFFFFF)  // 卡片白
    static let appBrand = Color(hex: 0x2B54E8)  // 主品牌蓝
    static let appBrand2 = Color(hex: 0x6B4BF0)  // 次品牌紫蓝
    static let appViolet = Color(hex: 0x7C4DFF)  // 强调紫
    static let appOK = Color(hex: 0x0F9D58)  // 成功绿
    static let appErr = Color(hex: 0xE2402F)  // 失败红
    static let appWarn = Color(hex: 0xE8890C)  // 警示橙

    static let textPrimary = Color(hex: 0x1C1C1E)  // 主文字
    static let textSecondary = Color(hex: 0x6B6B70)  // 次文字
    static let textTertiary = Color(hex: 0x9A9AA0)  // 弱化文字
    static let separator = Color(hex: 0xE5E5EA)  // 分割线

    static var brandGradient: LinearGradient {  // 主题渐变
        LinearGradient(  // 构造渐变对象
            colors: [.appBrand, .appBrand2],  // 渐变两端颜色
            startPoint: .topLeading,  // 起点左上
            endPoint: .bottomTrailing  // 终点右下
        )  // 渐变构造结束
    }  // 渐变属性结束

    init(hex: UInt32, alpha: Double = 1) {  // 十六进制转 Color
        self.init(  // 调系统构造器
            .sRGB,  // 色彩空间
            red: Double((hex >> 16) & 0xFF) / 255,  // 取红色分量
            green: Double((hex >> 8) & 0xFF) / 255,  // 取绿色分量
            blue: Double(hex & 0xFF) / 255,  // 取蓝色分量
            opacity: alpha  // 透明度
        )  // 构造结束
    }  // 初始化结束
}  // Color 扩展结束

// MARK: - 间距                                                          // 分节：间距

enum Space {  // 4 的倍数刻度
    static let xxs: CGFloat = 4  // 4 点
    static let xs: CGFloat = 8  // 8 点
    static let s: CGFloat = 10  // 10 点
    static let m: CGFloat = 12  // 12 点
    static let ml: CGFloat = 14  // 14 点
    static let l: CGFloat = 16  // 16 点
    static let xl: CGFloat = 22  // 22 点
    static let xxl: CGFloat = 32  // 32 点
}  // Space 结束

// MARK: - 圆角                                                          // 分节：圆角

enum Radius {  // 圆角刻度
    static let chip: CGFloat = 10  // 小标签圆角
    static let card: CGFloat = 16  // 卡片默认圆角
    static let sheet: CGFloat = 22  // 弹层圆角
    static let button: CGFloat = 14  // 按钮圆角
}  // Radius 结束

// MARK: - 字体                                                          // 分节：字体

enum AppFont {  // 语义化字号
    static let hero = Font.system(size: 28, weight: .bold, design: .rounded)  // 超大标题
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)  // 页面标题
    static let section = Font.system(size: 17, weight: .semibold)  // 区段标题
    static let body = Font.system(size: 15, weight: .regular)  // 正文
    static let bodyStrong = Font.system(size: 15, weight: .semibold)  // 正文加重
    static let caption = Font.system(size: 13, weight: .regular)  // 辅助说明
    static let captionStrong = Font.system(size: 13, weight: .semibold)  // 辅助加重
    static let metric = Font.system(size: 24, weight: .bold, design: .rounded)  // 数字指标
}  // AppFont 结束

// MARK: - 阴影                                                          // 分节：阴影

extension View {  // 给所有视图加投影
    func cardShadow() -> some View {  // 卡片统一投影
        self.shadow(  // 加阴影
            color: Color.black.opacity(0.06),  // 阴影颜色与浓度
            radius: 10,  // 模糊半径
            x: 0,  // 水平偏移
            y: 4  // 垂直偏移
        )  // 阴影构造结束
    }  // 方法结束
}  // View 扩展结束

// MARK: - 尺寸与可访问性                                                // 分节：尺寸

enum Metrics {  // 统一尺寸常量
    static let minTap: CGFloat = 44  // HIG 最小触控区
    static let pagePadding: CGFloat = Space.l  // 页面左右边距
    static let cardPadding: CGFloat = Space.l  // 卡片内边距
}  // Metrics 结束
