//  ShopView.swift —— 严选好物（对齐 Web 样板 page-shop）                   // 文件说明
//  结构：顶部横幅 → 商品网格 4 件 → 商家合作两行 → 底部演示说明            // 页面结构
//  ⚠️ 样板是纯展示，没有下单与支付流程；这里也不做假下单，点卡片只给如实提示   // 诚实约束
//  商品名称 / 副标题 / 现价 / 划线价 / 渐变配色 / 图标，逐条照抄样板 GOODS 数组 // 数据来源

import SwiftUI  // 界面框架

struct ShopView: View {  // 商店页

    @State private var showRule = false  // 选品规则弹层是否打开
    @State private var toast: String?  // 底部轻提示文字

    // 商品清单，逐条照抄样板 app.js 的 GOODS 数组，顺序与配色都不改  // 数据说明
    private static let goods: [Goods] = [  // 四件商品
        Goods(name: "税务专硕复试真题解析（近 5 年）",  // 名称
              detail: "含 40 所院校复试原题",  // 副标题
              price: 99,  // 现价
              origin: 168,  // 划线原价
              colors: [Color(hex: 0x4A6BFF), Color(hex: 0x7B5CFF)],  // 样板渐变 #4a6bff → #7b5cff
              icon: "book.closed.fill"),  // 书本图标
        Goods(name: "复试英语口语 30 天打卡营",  // 名称
              detail: "每天 15 分钟跟读",  // 副标题
              price: 199,  // 现价
              origin: 299,  // 划线原价
              colors: [Color(hex: 0xFF9B3D), Color(hex: 0xFF6B6B)],  // 样板渐变
              icon: "headphones"),  // 耳机图标对应样板的 ear
        Goods(name: "1v1 模拟面试（学长学姐）",  // 名称
              detail: "在职税务师，40 分钟",  // 副标题
              price: 299,  // 现价
              origin: 499,  // 划线原价
              colors: [Color(hex: 0x12B981), Color(hex: 0x2BB3C0)],  // 样板渐变
              icon: "mic.fill"),  // 话筒图标
        Goods(name: "税务热点月度手册",  // 名称
              detail: "政策更新 + 观点梳理",  // 副标题
              price: 39,  // 现价
              origin: 59,  // 划线原价
              colors: [Color(hex: 0xFF6F91), Color(hex: 0xFF9A76)],  // 样板渐变
              icon: "newspaper.fill")  // 报纸图标
    ]  // 商品数组结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(alignment: .leading, spacing: Space.l) {  // 纵向排列
                banner  // 顶部横幅
                goodsGrid  // 商品网格
                merchantGroup  // 商家合作
                serviceNote  // 底部说明
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 页面左右边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 页面底色
        .navigationTitle("严选好物")  // 导航标题
        .navigationBarTitleDisplayMode(.inline)  // 小标题
        .sheet(isPresented: $showRule) { ruleSheet }  // 选品规则弹层
        .overlay(alignment: .bottom) { toastLayer }  // 轻提示浮在底部
    }  // body 结束

    // MARK: - 横幅                                                    // 分节：横幅

    private var banner: some View {  // 顶部横幅，对应样板 .shop-banner
        VStack(alignment: .leading, spacing: Space.xxs) {  // 纵向排列
            Text("课程与资料严选")  // 主标题
                .font(AppFont.section)  // 区段标题字号
                .foregroundStyle(.white)  // 深底白字
            Text("机构内容分销 · 平台抽成 40% 模型已预留")  // 副标题，与样板文案一致
                .font(AppFont.caption)  // 小字
                .foregroundStyle(.white.opacity(0.85))  // 略淡的白
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽度靠左
        .padding(Space.l)  // 内边距
        .background(  // 品牌渐变底
            LinearGradient(colors: [.appBrand, .appBrand2],  // 两端品牌色
                           startPoint: .topLeading,  // 左上
                           endPoint: .bottomTrailing)  // 右下
        )  // 背景结束
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 圆角
        .cardShadow()  // 统一投影
    }  // banner 结束

    // MARK: - 商品网格                                                // 分节：商品

    private var goodsGrid: some View {  // 两列网格
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.m),  // 左列
                            GridItem(.flexible())],  // 右列
                  spacing: Space.m) {  // 行间距
            ForEach(Array(Self.goods.enumerated()), id: \.offset) { index, item in  // 逐件渲染
                Button {  // 点卡片
                    toast = "样板演示：下单与支付未接入"  // 如实说明，不假装能买
                } label: {  // 卡片外观
                    goodsCard(item)  // 单件卡片
                }  // 标签结束
                .buttonStyle(.plain)  // 不用默认高亮
                .accessibilityIdentifier("shop-goods-\(index)")  // 便于 UI 测试定位
            }  // 遍历结束
        }  // 网格结束
    }  // goodsGrid 结束

    private func goodsCard(_ item: Goods) -> some View {  // 单件商品卡
        Card {  // 白卡容器
            VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
                ZStack {  // 图标方块
                    LinearGradient(colors: item.colors,  // 商品专属渐变
                                   startPoint: .topLeading,  // 左上
                                   endPoint: .bottomTrailing)  // 右下
                    Image(systemName: item.icon)  // 白色图标
                        .font(.system(size: 24, weight: .regular))  // 图标大小
                        .foregroundStyle(.white.opacity(0.95))  // 白色
                }  // 图标区结束
                .frame(height: 62)  // 与样板 goods-img 比例接近
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))  // 圆角
                Text(item.name)  // 商品名
                    .font(AppFont.bodyStrong)  // 加粗正文
                    .foregroundStyle(Color.textPrimary)  // 主文字色
                    .lineLimit(2)  // 最多两行
                    .multilineTextAlignment(.leading)  // 左对齐
                    .frame(maxWidth: .infinity, alignment: .leading)  // 靠左撑满
                Text(item.detail)  // 副标题
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次文字色
                    .lineLimit(1)  // 单行
                HStack(alignment: .firstTextBaseline, spacing: Space.xxs) {  // 价格行
                    Text("¥\(item.price)")  // 现价
                        .font(.system(size: 16, weight: .bold, design: .rounded))  // 突出显示
                        .foregroundStyle(Color.appErr)  // 价格用醒目色
                    Text("¥\(item.origin)")  // 原价
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化
                        .strikethrough()  // 划线，与样板 s 标签一致
                }  // 价格行结束
            }  // 排列结束
        }  // 卡片结束
    }  // goodsCard 结束

    // MARK: - 商家合作                                                // 分节：商家

    private var merchantGroup: some View {  // 商家合作两行
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            Text("商家合作")  // 区段标题，与样板 group-title 一致
                .font(AppFont.section)  // 区段字号
                .foregroundStyle(Color.textPrimary)  // 主文字色
            Card {  // 卡片容器
                VStack(spacing: Space.m) {  // 纵向排列
                    NavigationLink {  // 申请入驻
                        MerchantEntryView()  // 复用已有入驻页
                    } label: {  // 行外观
                        merchantRow(title: "申请入驻",  // 名称
                                    detail: "提交资质",  // 右侧说明
                                    icon: "building.2.fill")  // 图标
                    }  // 标签结束
                    .buttonStyle(.plain)  // 不用默认高亮
                    Divider()  // 分隔线
                    Button {  // 选品规则
                        showRule = true  // 打开弹层
                    } label: {  // 行外观
                        merchantRow(title: "选品规则与分账",  // 名称
                                    detail: "准入 · 佣金 · 结算",  // 右侧说明
                                    icon: "doc.text.fill")  // 图标
                    }  // 标签结束
                    .buttonStyle(.plain)  // 不用默认高亮
                    .accessibilityIdentifier("shop-rule")  // 便于 UI 测试定位
                }  // 排列结束
            }  // 卡片结束
        }  // 排列结束
    }  // merchantGroup 结束

    private func merchantRow(title: String, detail: String, icon: String) -> some View {  // 通用入口行
        HStack(spacing: Space.m) {  // 横向排列
            Image(systemName: icon)  // 图标
                .font(.system(size: 15))  // 图标大小
                .foregroundStyle(Color.appBrand)  // 品牌色
                .frame(width: 24)  // 固定宽度对齐
            Text(title)  // 行标题
                .font(AppFont.bodyStrong)  // 加粗正文
                .foregroundStyle(Color.textPrimary)  // 主文字色
            Spacer()  // 撑开
            Text(detail)  // 右侧说明
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次文字色
            Image(systemName: "chevron.right")  // 箭头
                .font(.system(size: 11, weight: .semibold))  // 小箭头
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .contentShape(Rectangle())  // 整行可点
    }  // merchantRow 结束

    // MARK: - 说明与弹层                                              // 分节：说明

    private var serviceNote: some View {  // 底部说明，样板 SERVICE_NOTE 原文
        Text("样板演示页面，正式版对接考试院 / 机构接口。")  // 与样板一字不差
            .font(AppFont.caption)  // 小字
            .foregroundStyle(Color.textTertiary)  // 弱化色
            .frame(maxWidth: .infinity, alignment: .center)  // 居中
    }  // serviceNote 结束

    private var ruleSheet: some View {  // 选品规则弹层，内容照抄样板 infoSheet
        NavigationStack {  // 带导航栏的弹层
            ScrollView {  // 可滚动
                VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                    ruleRow(label: "准入类目", value: "考研公共课 / 专业课 / 复试辅导 / 资料印刷品")  // 第一行
                    ruleRow(label: "资质要求", value: "营业执照 + 办学许可（课程类）")  // 第二行
                    ruleRow(label: "平台抽成", value: "40%（课程）/ 25%（资料）")  // 第三行
                    ruleRow(label: "结算周期", value: "T+7，学到 7 天无理由退款期结束")  // 第四行
                    ruleRow(label: "选品权重", value: "完课率 + 好评率 + 退费率")  // 第五行
                    Text("样板演示页面，正式版对接考试院 / 机构接口。")  // 样板末尾说明
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                        .padding(.top, Space.xs)  // 与上面隔开
                }  // 排列结束
                .padding(Metrics.pagePadding)  // 内边距
            }  // 滚动结束
            .background(Color.appBG)  // 底色
            .navigationTitle("选品规则与分账")  // 弹层标题
            .navigationBarTitleDisplayMode(.inline)  // 小标题
            .toolbar {  // 导航栏按钮
                ToolbarItem(placement: .confirmationAction) {  // 右上角
                    Button("知道了") { showRule = false }  // 关闭，同样板 confirmText
                }  // 按钮结束
            }  // 工具栏结束
        }  // 导航栈结束
    }  // ruleSheet 结束

    private func ruleRow(label: String, value: String) -> some View {  // 一条规则
        VStack(alignment: .leading, spacing: Space.xxs) {  // 纵向排列
            Text(label)  // 左侧标签
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次文字色
            Text(value)  // 右侧内容
                .font(AppFont.body)  // 正文字号
                .foregroundStyle(Color.textPrimary)  // 主文字色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 靠左
        .padding(Space.m)  // 内边距
        .background(Color.appCard)  // 卡片白
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))  // 圆角
    }  // ruleRow 结束

    private var toastLayer: some View {  // 底部轻提示
        Group {  // 条件包裹
            if let toast {  // 有提示才显示
                Text(toast)  // 提示文字
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(.white)  // 白字
                    .padding(.horizontal, Space.l)  // 横向内边距
                    .padding(.vertical, Space.s)  // 纵向内边距
                    .background(Color.black.opacity(0.78))  // 半透明黑底
                    .clipShape(Capsule())  // 胶囊
                    .padding(.bottom, 110)  // 让开悬浮 TabBar
                    .transition(.opacity)  // 淡入淡出
                    .onTapGesture { self.toast = nil }  // 点一下收起
            }  // 分支结束
        }  // 包裹结束
        .animation(.easeInOut(duration: 0.2), value: toast)  // 联动动画
        .task(id: toast) {  // 自动消失
            guard toast != nil else { return }  // 没有就退出
            try? await Task.sleep(nanoseconds: 1_800_000_000)  // 1.8 秒
            toast = nil  // 清掉
        }  // 任务结束
    }  // toastLayer 结束
}  // ShopView 结束

struct Goods: Identifiable {  // 商品数据
    let id = UUID()  // 列表标识
    let name: String  // 名称
    let detail: String  // 副标题
    let price: Int  // 现价
    let origin: Int  // 划线原价
    let colors: [Color]  // 渐变两端
    let icon: String  // SF Symbol 名
}  // Goods 结束
