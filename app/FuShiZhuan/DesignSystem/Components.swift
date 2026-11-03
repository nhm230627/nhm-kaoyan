//  Components.swift —— 基础组件库                                    // 文件说明
//  新页面只能拼这些组件，不许自己画按钮卡片，否则 5 个 Tab 长出 5 种圆角  // 使用约束

import SwiftUI  // 界面框架

// MARK: - 卡片                                                        // 分节：卡片

struct Card<Content: View>: View {  // 通用卡片容器
    var padding: CGFloat = Metrics.cardPadding  // 内边距
    @ViewBuilder var content: Content  // 内容

    var body: some View {  // 视图主体
        content  // 放内容
            .padding(padding)  // 加内边距
            .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽度左对齐
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 白底圆角
            .cardShadow()  // 加投影
    }  // body 结束
}  // Card 结束

// MARK: - 按钮                                                        // 分节：按钮

struct PrimaryButton: View {  // 主按钮
    let title: String  // 按钮文字
    var systemImage: String? = nil  // 左侧图标
    var enabled: Bool = true  // 是否可用
    let action: () -> Void  // 点击回调

    var body: some View {  // 视图主体
        Button(action: action) {  // 按钮
            HStack(spacing: Space.xs) {  // 横向排列
                if let systemImage {  // 有图标才显示
                    Image(systemName: systemImage)  // 图标
                }  // 分支结束
                Text(title)  // 文字
                    .font(AppFont.bodyStrong)  // 加粗正文
            }  // 排列结束
            .frame(maxWidth: .infinity)  // 撑满宽度
            .frame(minHeight: Metrics.minTap)  // 最小触控高度
            .foregroundStyle(.white)  // 白字
            .background(  // 背景
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)  // 圆角底
                    .fill(enabled ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(Color.textTertiary))  // 可用渐变，禁用灰
            )  // 背景结束
        }  // 按钮结束
        .disabled(!enabled)  // 禁用态
        .accessibilityLabel(title)  // 无障碍标签
    }  // body 结束
}  // PrimaryButton 结束

struct GhostButton: View {  // 次级按钮
    let title: String  // 文字
    var systemImage: String? = nil  // 图标
    var enabled: Bool = true  // 是否可用
    let action: () -> Void  // 回调

    var body: some View {  // 视图主体
        Button(action: action) {  // 按钮
            HStack(spacing: Space.xxs) {  // 横向排列
                if let systemImage {  // 有图标才显示
                    Image(systemName: systemImage)  // 图标
                }  // 分支结束
                Text(title).font(AppFont.bodyStrong)  // 文字
            }  // 排列结束
            .frame(maxWidth: .infinity)  // 撑满宽度
            .frame(minHeight: Metrics.minTap)  // 最小触控高度
            .foregroundStyle(Color.appBrand)  // 品牌色文字
            .background(  // 背景
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)  // 圆角
                    .stroke(Color.appBrand.opacity(0.35), lineWidth: 1)  // 描边
            )  // 背景结束
        }  // 按钮结束
        .disabled(!enabled)  // 不可用时禁用点击
        .opacity(enabled ? 1 : 0.4)  // 不可用时变淡
        .accessibilityLabel(title)  // 无障碍标签
    }  // body 结束
}  // GhostButton 结束

// MARK: - 标签                                                        // 分节：标签

struct Chip: View {  // 小标签
    let text: String  // 文字
    var tint: Color = .appBrand  // 主色
    var filled: Bool = false  // 是否实心

    var body: some View {  // 视图主体
        Text(text)  // 文字
            .font(AppFont.captionStrong)  // 小字加粗
            .padding(.horizontal, Space.s)  // 左右内边距
            .padding(.vertical, Space.xxs)  // 上下内边距
            .foregroundStyle(filled ? .white : tint)  // 实心白字，否则主色字
            .background(  // 背景
                Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)))  // 胶囊底
            )  // 背景结束
    }  // body 结束
}  // Chip 结束

// MARK: - 进度条                                                      // 分节：进度条

struct Meter: View {  // 数值条
    let value: Double  // 0 到 1 的进度
    var tint: Color = .appBrand  // 填充色
    var label: String? = nil  // 语义标签

    var body: some View {  // 视图主体
        VStack(alignment: .leading, spacing: Space.xxs) {  // 纵向排列
            GeometryReader { geo in  // 取可用宽度
                ZStack(alignment: .leading) {  // 叠放
                    Capsule().fill(Color.separator)  // 底槽
                    Capsule()  // 填充条
                        .fill(tint)  // 填充色
                        .frame(width: max(0, min(1, value)) * geo.size.width)  // 按比例算宽度
                }  // 叠放结束
            }  // 几何读取结束
            .frame(height: 8)  // 条高 8
            if let label {  // 有标签才显示
                Text(label).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明文字
            }  // 分支结束
        }  // 排列结束
        .accessibilityElement(children: .ignore)  // 合并为单个元素
        .accessibilityLabel(label ?? "进度")  // 无障碍名
        .accessibilityValue("\(Int(value * 100))%")  // 无障碍值
    }  // body 结束
}  // Meter 结束

// MARK: - 指标块                                                      // 分节：指标

struct StatTile: View {  // 数字指标块
    let value: String  // 数值文本
    let title: String  // 说明
    var tint: Color = .textPrimary  // 数值颜色

    var body: some View {  // 视图主体
        VStack(spacing: Space.xxs) {  // 纵向排列
            Text(value)  // 数值
                .font(AppFont.metric)  // 指标字号
                .foregroundStyle(tint)  // 上色
                .monospacedDigit()  // 等宽数字防跳动
            Text(title)  // 说明
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
        }  // 排列结束
        .frame(maxWidth: .infinity)  // 撑满
    }  // body 结束
}  // StatTile 结束

// MARK: - 环形进度                                                    // 分节：环形进度

struct ProgressRing: View {  // 圆环倒计时，首页蓝卡用
    let progress: Double  // 0…1，已走过的比例
    let center: String  // 圆内主文字（天数）
    let caption: String  // 圆内副文字（天后复试）
    var size: CGFloat = 96  // 直径
    var lineWidth: CGFloat = 8  // 环的粗细
    var tint: Color = .white  // 环颜色

    var body: some View {  // 视图主体
        ZStack {  // 叠放
            Circle()  // 底环
                .stroke(tint.opacity(0.25), lineWidth: lineWidth)  // 半透明底
            Circle()  // 进度环
                .trim(from: 0, to: max(0.02, min(1, progress)))  // 至少留一点，避免看不见
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))  // 圆头描边
                .rotationEffect(.degrees(-90))  // 从 12 点开始转
            VStack(spacing: 0) {  // 圆内文字
                Text(center)  // 天数
                    .font(.system(size: 30, weight: .bold, design: .rounded))  // 大号圆体
                    .monospacedDigit()  // 等宽防跳动
                Text(caption)  // 说明
                    .font(.system(size: 11, weight: .medium))  // 小字
                    .opacity(0.9)  // 略淡
            }  // 文字区结束
            .foregroundStyle(tint)  // 文字同色
        }  // 叠放结束
        .frame(width: size, height: size)  // 固定尺寸
        .accessibilityElement(children: .ignore)  // 合并为一个元素
        .accessibilityLabel("\(center) \(caption)")  // 无障碍朗读
    }  // body 结束
}  // ProgressRing 结束

// MARK: - 圆形图标按钮                                                // 分节：圆钮

struct CircleIconButton: View {  // 页头右上角的圆钮
    let systemImage: String  // 图标名
    var tint: Color = .appBrand  // 图标色
    var background: Color = .white  // 圆形底
    var active: Bool = false  // 是否高亮（例如今天已打卡）
    let action: () -> Void  // 点击回调

    var body: some View {  // 视图主体
        Button(action: action) {  // 按钮
            Image(systemName: systemImage)  // 图标
                .font(.system(size: 15, weight: .semibold))  // 图标大小
                .foregroundStyle(tint)  // 上色
                .frame(width: 36, height: 36)  // 圆形尺寸
                .background(  // 背景
                    Circle().fill(active ? tint.opacity(0.14) : background)  // 高亮淡底
                )  // 背景结束
        }  // 按钮结束
        .buttonStyle(.plain)  // 去除默认样式
        .accessibilityLabel(systemImage)  // 无障碍标签
    }  // body 结束
}  // CircleIconButton 结束

// MARK: - 五种状态                                                    // 分节：状态视图

struct LoadingState: View {  // 加载态
    var text: String = "加载中…"  // 提示文字
    var body: some View {  // 视图主体
        VStack(spacing: Space.m) {  // 纵向排列
            ProgressView()  // 转圈
            Text(text).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 提示
        }  // 排列结束
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 撑满
        .accessibilityLabel(text)  // 无障碍标签
    }  // body 结束
}  // LoadingState 结束

struct EmptyState: View {  // 空态
    let icon: String  // 图标
    let title: String  // 标题
    let message: String  // 说明
    var actionTitle: String? = nil  // 按钮文字
    var action: (() -> Void)? = nil  // 按钮回调

    var body: some View {  // 视图主体
        VStack(spacing: Space.m) {  // 纵向排列
            Image(systemName: icon)  // 图标
                .font(.system(size: 40))  // 图标大小
                .foregroundStyle(Color.textTertiary)  // 弱化色
            Text(title).font(AppFont.section).foregroundStyle(Color.textPrimary)  // 标题
            Text(message)  // 说明
                .font(AppFont.body)  // 正文字号
                .foregroundStyle(Color.textSecondary)  // 次要色
                .multilineTextAlignment(.center)  // 居中
            if let actionTitle, let action {  // 有按钮才显示
                GhostButton(title: actionTitle, action: action)  // 次级按钮
                    .frame(maxWidth: 220)  // 限宽
            }  // 分支结束
        }  // 排列结束
        .padding(Space.xl)  // 内边距
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 撑满
    }  // body 结束
}  // EmptyState 结束

struct ErrorState: View {  // 错误态
    let error: AppError  // 错误对象
    var retry: (() -> Void)? = nil  // 重试回调

    var body: some View {  // 视图主体
        VStack(spacing: Space.m) {  // 纵向排列
            Image(systemName: "exclamationmark.triangle.fill")  // 警告图标
                .font(.system(size: 36))  // 图标大小
                .foregroundStyle(Color.appWarn)  // 警示色
            Text(error.title).font(AppFont.section)  // 错误标题
            Text(error.action)  // 下一步动作
                .font(AppFont.body)  // 正文字号
                .foregroundStyle(Color.textSecondary)  // 次要色
                .multilineTextAlignment(.center)  // 居中
            if let retry {  // 有重试才显示
                GhostButton(title: "重试", systemImage: "arrow.clockwise", action: retry)  // 重试按钮
                    .frame(maxWidth: 200)  // 限宽
            }  // 分支结束
        }  // 排列结束
        .padding(Space.xl)  // 内边距
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 撑满
    }  // body 结束
}  // ErrorState 结束

// MARK: - 页头                                                        // 分节：页头

struct PageHeader<Trailing: View>: View {  // 统一页头
    let title: String  // 标题
    var subtitle: String?  // 副标题
    @ViewBuilder var trailing: Trailing  // 右侧动作位

    var body: some View {  // 视图主体
        HStack(alignment: .firstTextBaseline) {  // 横向排列
            VStack(alignment: .leading, spacing: Space.xxs) {  // 文字区
                Text(title).font(AppFont.title)  // 标题
                if let subtitle {  // 有副标题才显示
                    Text(subtitle).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 副标题
                }  // 分支结束
            }  // 文字区结束
            Spacer()  // 撑开
            trailing  // 右侧动作
        }  // 排列结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右边距
        .padding(.top, Space.xs)  // 上边距
    }  // body 结束
}  // PageHeader 结束

extension PageHeader where Trailing == EmptyView {  // 无右侧动作的便捷构造
    init(title: String, subtitle: String? = nil) {  // 只传标题副标题
        self.init(title: title, subtitle: subtitle) { EmptyView() }  // 右侧留空
    }  // 构造结束
}  // 扩展结束
