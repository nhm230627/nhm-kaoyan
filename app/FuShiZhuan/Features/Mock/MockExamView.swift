//  MockExamView.swift —— 院校模考（对齐样板 page-mock + js/mock.js）    // 文件说明
//  结构：通用模考卡 → 三个卷别 Tab → 搜索 → 筛选 → 院校列表 → 数据说明
//  出卷走后端无关的本地算法（MockPaperBuilder），同一院校同一卷每次抽题一致。
//
//  ⚠️ 两处与样板的已知偏离，都写在这里免得后人以为是漏做：
//   1) 面试模考：样板点院校后直接跳面试间（ctx.go('room')）。iOS 的面试间在
//      另一个 Tab，这里不代跳，只如实提示「到面试间进行」，不假装能开卷。
//   2) 列表副标题：样板写死「每周三 20:00 开考 · 1,286 人已报名」，那是运营
//      文案，本工程没有这个活动，照抄等于对用户撒谎，所以改成真实口径。

import SwiftUI  // 界面框架

/// 一次开卷请求（交给 QuizRunView 用固定题序）
struct MockRun: Identifiable {  // 开卷配置
    let id = UUID()  // 每次开卷都是一个新实例
    let questions: [Question]  // 已经抽好的题（顺序固定）
    let title: String  // 卷名，如「中国人民大学 · 初试仿真卷 A」
}  // MockRun 结束

struct MockExamView: View {  // 院校模考页
    @Environment(AppState.self) private var app  // 全局状态
    @State private var kind: MockKind = .initial  // 当前卷别
    @State private var keyword = ""  // 搜索关键词
    @State private var filter = "全部"  // 当前筛选
    @State private var picking: School?  // 正在选卷的院校
    @State private var run: MockRun?  // 正在做的卷
    @State private var toast: String?  // 轻提示

    private let filters = ["全部", "985", "211", "双一流", "财经类"]  // 五个筛选项（照样板按钮）

    private var schools: [School] { SchoolCatalog.load() }  // 全部院校

    /// 筛选后的院校。规则与样板 mock.js 的 renderList 一致：
    /// 关键词同时匹配校名、城市、标签；筛选按 tier 与 tags 判。
    private var rows: [School] {  // 过滤结果
        let kw = keyword.trimmingCharacters(in: .whitespaces)  // 去掉首尾空格
        return schools.filter { s in  // 逐所过滤
            if !kw.isEmpty {  // 有关键词
                let hit = s.name.contains(kw)  // 校名命中
                    || s.city.contains(kw)  // 或城市命中
                    || s.tags.joined().contains(kw)  // 或标签命中
                if !hit { return false }  // 都不中就去掉
            }  // 关键词分支结束
            switch filter {  // 按筛选分支
            case "985": return s.tier == "985"  // 只看 985
            case "211": return s.tier == "211"  // 只看 211
            case "双一流": return s.tags.contains("双一流")  // 看标签
            case "财经类": return s.tags.contains("财经")  // 看标签
            default: return true  // 全部
            }  // 分支结束
        }  // 过滤结束
    }  // rows 结束

    var body: some View {  // 视图主体
        ScrollView {  // 整页可滚
            VStack(alignment: .leading, spacing: 0) {  // 纵向排列
                hero  // 通用模考卡
                tabBar  // 三个卷别
                searchBar  // 搜索 + 数量
                filterBar  // 五个筛选
                list  // 院校列表
                note  // 数据说明
            }  // 排列结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
            .padding(.top, 8)  // 顶部留白
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 会压住最后两行
        }  // 滚动结束
        .background(Color.appBG)  // 页面底色
        .navigationTitle("模考板块")  // 照样板标题
        .navigationBarTitleDisplayMode(.inline)  // 内联标题
        .toolbar {  // 工具栏
            ToolbarItem(placement: .topBarTrailing) { TrackChip() }  // 右上角方向胶囊
        }  // 工具栏结束
        .sheet(item: $picking) { school in  // 选卷弹层
            SchoolPaperSheet(school: school, app: app,  // 传院校与状态
                             kind: kind,  // 当前卷别
                             onStart: { list, title in  // 开卷回调
                                 run = MockRun(questions: list, title: title)  // 记下这一套
                             },  // 回调结束
                             onNeedRoom: { toast = "面试模考在「面试」Tab 的面试间里，5 位导师轮着问" })  // 面试卷的提示
                .presentationDetents([.medium, .large])  // 半屏到全屏
                .presentationDragIndicator(.visible)  // 顶部小横条
        }  // 弹层结束
        .fullScreenCover(item: $run) { cfg in  // 开卷
            NavigationStack {  // 套导航栈，才有标题栏
                QuizRunView(pool: cfg.questions,  // 抽好的题
                            size: cfg.questions.count,  // 题量就是卷长
                            revealEach: false,  // 模考交卷后统一看
                            title: cfg.title,  // 标题显示卷名
                            fixed: true)  // 题序固定，不重抽
            }  // 栈结束
        }  // 覆盖层结束
        .overlay(alignment: .bottom) {  // 轻提示浮在底部
            if let msg = toast {  // 有提示才显示（用局部常量，闭包里才能改 toast）
                Text(msg)  // 提示内容
                    .font(.system(size: 12))  // 12 号
                    .foregroundStyle(.white)  // 白字
                    .padding(.horizontal, 14)  // 左右
                    .padding(.vertical, 9)  // 上下
                    .background(Capsule().fill(Color.black.opacity(0.78)))  // 深色胶囊
                    .padding(.bottom, 28)  // 离底边
                    .task {  // 出现后计时
                        try? await Task.sleep(nanoseconds: 2_600_000_000)  // 2.6 秒
                        toast = nil  // 自动消失
                    }  // 任务结束
            }  // 分支结束
        }  // 覆盖层结束
    }  // body 结束

    // MARK: - 通用模考卡                                              // 分节：通用卷

    private var hero: some View {  // 深蓝渐变卡（样板 .mk-hero）
        Button {  // 点整张卡开通用卷
            startCommon()  // 不分院校，四块均衡
        } label: {  // 卡片外观
            VStack(alignment: .leading, spacing: 0) {  // 纵向排列
                Text("通用模考 · 不分院校")  // 角标
                    .font(.system(size: 9.5, weight: .semibold))  // 9.5 号
                    .foregroundStyle(.white)  // 白字
                    .padding(.horizontal, 9)  // 左右
                    .frame(height: 18)  // 高度
                    .background(Capsule().fill(Color.white.opacity(0.16)))  // 白 16% 胶囊

                Text("先摸底，再挑院校")  // 标题
                    .font(.system(size: 16.5, weight: .bold))  // 16.5 加粗
                    .foregroundStyle(.white)  // 白字
                    .padding(.top, 8)  // 上间距

                Text("整套 20 题，交卷给分数、正确率与薄弱板块；错题自动进错题本。")  // 说明（样板原话）
                    .font(.system(size: 10.5))  // 10.5 号
                    .foregroundStyle(.white.opacity(0.7))  // 白 70%
                    .lineSpacing(2)  // 行距
                    .padding(.top, 5)  // 上间距

                Text("\(app.currentTrack.name) · 覆盖 \(schools.count) 所院校")  // 橙胶囊（样板 mk-hero-go）
                    .font(.system(size: 10, weight: .semibold))  // 10 号
                    .foregroundStyle(.white)  // 白字
                    .padding(.horizontal, 10)  // 左右
                    .frame(height: 22)  // 高度
                    .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFB020), Color(hex: 0xFF7A45)],  // 橙渐变
                                                             startPoint: .topLeading, endPoint: .bottomTrailing)))  // 左上到右下
                    .padding(.top, 10)  // 上间距
            }  // 排列结束
            .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
            .padding(.horizontal, 16)  // 左右内边距
            .padding(.top, 15)  // 上内边距
            .padding(.bottom, 14)  // 下内边距
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)  // 圆角 20
                .fill(LinearGradient(colors: [Color(hex: 0x2B3A6B), Color(hex: 0x1B2547), Color(hex: 0x31265C)],  // 三段深色
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))  // 140 度方向
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统样式
    }  // hero 结束

    // MARK: - 卷别 Tab                                                // 分节：Tab

    private var tabBar: some View {  // 三段控件
        HStack(spacing: 6) {  // 三个等宽
            ForEach(MockKind.allCases) { item in  // 逐卷别
                Button {  // 切换
                    kind = item  // 记下当前卷别
                } label: {  // 按钮外观
                    Text(item.tabTitle)  // Tab 名
                        .font(.system(size: 11.5, weight: .semibold))  // 11.5 号
                        .foregroundStyle(kind == item ? Color(hex: 0x1C2438) : Color(hex: 0x6B7288))  // 选中深色
                        .frame(maxWidth: .infinity)  // 等宽撑满
                        .frame(height: 32)  // 32 高
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)  // 圆角 11
                            .fill(kind == item ? Color.white : Color.clear))  // 选中白底
                }  // 按钮结束
                .buttonStyle(.plain)  // 去掉系统样式
            }  // 循环结束
        }  // 横排结束
        .padding(4)  // 内边距 4（样板 padding:4px）
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
            .fill(Color(hex: 0xEEF0F6)))  // 浅灰底
        .padding(.top, 12)  // 与上方卡片留白
    }  // tabBar 结束

    // MARK: - 搜索                                                    // 分节：搜索

    private var searchBar: some View {  // 搜索框 + 数量
        HStack(spacing: 9) {  // 横向排列
            HStack(spacing: 6) {  // 搜索框内部
                Image(systemName: "magnifyingglass")  // 放大镜
                    .font(.system(size: 11, weight: .bold))  // 小图标
                    .foregroundStyle(Color(hex: 0x9AA1B2))  // 灰蓝
                TextField("搜院校 / 城市", text: $keyword)  // 输入框（样板 placeholder）
                    .font(.system(size: 11.5))  // 11.5 号
                    .textInputAutocapitalization(.never)  // 不自动大写
                    .autocorrectionDisabled()  // 不自动纠错
            }  // 横排结束
            .padding(.horizontal, 11)  // 左右内边距
            .frame(height: 34)  // 34 高
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)  // 圆角 12
                .fill(Color(hex: 0xF4F5F9)))  // 浅灰底

            Text("\(rows.count) 所")  // 命中数量
                .font(.system(size: 10))  // 10 号
                .foregroundStyle(Color(hex: 0x8A90A2))  // 灰
        }  // 横排结束
        .padding(.top, 11)  // 上间距（样板 margin 11 0 8）
        .padding(.bottom, 8)  // 下间距
    }  // searchBar 结束

    // MARK: - 筛选                                                    // 分节：筛选

    private var filterBar: some View {  // 横向胶囊
        ScrollView(.horizontal, showsIndicators: false) {  // 可横滑
            HStack(spacing: 5) {  // 5 的间距
                ForEach(filters, id: \.self) { item in  // 逐项
                    Button {  // 点选
                        filter = item  // 记下筛选
                    } label: {  // 胶囊外观
                        Text(item)  // 文字
                            .font(.system(size: 10.5, weight: .semibold))  // 10.5 号
                            .foregroundStyle(filter == item ? .white : Color(hex: 0x6B7288))  // 选中白字
                            .padding(.horizontal, 10)  // 左右
                            .frame(height: 25)  // 25 高
                            .background(Capsule().fill(filter == item ? Color(hex: 0x23305A) : Color(hex: 0xF1F2F7)))  // 选中深蓝
                    }  // 按钮结束
                    .buttonStyle(.plain)  // 去掉系统样式
                }  // 循环结束
            }  // 横排结束
        }  // 滚动结束
        .padding(.bottom, 8)  // 下间距
    }  // filterBar 结束

    // MARK: - 院校列表                                                // 分节：列表

    private var list: some View {  // 院校行
        LazyVStack(spacing: 7) {  // 7 的间距
            if rows.isEmpty {  // 没匹配
                Text("没有匹配的院校，换个关键词试试")  // 样板空态文案
                    .font(.system(size: 11))  // 11 号
                    .foregroundStyle(Color(hex: 0x9AA1B2))  // 灰蓝
                    .frame(maxWidth: .infinity)  // 撑满居中
                    .padding(.vertical, 26)  // 上下留白
            } else {  // 有结果
                ForEach(rows) { school in  // 逐校
                    row(school)  // 一行
                }  // 循环结束
            }  // 分支结束
        }  // 排列结束
    }  // list 结束

    private func row(_ school: School) -> some View {  // 一所院校
        let papers = school.papers.list(for: kind)  // 该卷别下有几套卷
        return Button {  // 点开选卷
            picking = school  // 弹出选卷层
        } label: {  // 行外观
            HStack(spacing: 10) {  // 横向排列
                Text(school.badge)  // 左侧角标（985 / 211 / 财 / 研）
                    .font(.system(size: 9.5, weight: .heavy))  // 9.5 特粗
                    .foregroundStyle(.white)  // 白字
                    .frame(width: 30, height: 30)  // 30 方块
                    .background(LinearGradient(colors: badgeColors(school),  // 按档次取色
                                               startPoint: .topLeading, endPoint: .bottomTrailing))  // 渐变
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))  // 圆角 10

                VStack(alignment: .leading, spacing: 2) {  // 校名 + 副标题
                    Text(school.name)  // 校名
                        .font(.system(size: 12.5, weight: .bold))  // 12.5 加粗
                        .foregroundStyle(Color(hex: 0x1C2438))  // 深色
                    Text("\(school.city) · \(papers.count) 套\(kind.shortLabel)卷\(school.isHot ? " · 热门" : "")")  // 副标题
                        .font(.system(size: 9.5))  // 9.5 号
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 竖排结束

                Spacer(minLength: 0)  // 撑开

                Image(systemName: "chevron.right")  // 右侧箭头
                    .font(.system(size: 11, weight: .semibold))  // 图标
                    .foregroundStyle(Color(hex: 0xC3C9D6))  // 浅灰
            }  // 横排结束
            .padding(.horizontal, 12)  // 左右内边距
            .padding(.vertical, 10)  // 上下内边距
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                .fill(Color.appCard))  // 白底
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统样式
    }  // row 结束

    private func badgeColors(_ school: School) -> [Color] {  // 角标配色（照样板 .ms-badge.a/b/c）
        switch school.tier {  // 按档次分支
        case "985": [Color(hex: 0xE2402F), Color(hex: 0xFF7A45)]  // 红橙
        case "211": [Color(hex: 0x2B54E8), Color(hex: 0x5B7CFF)]  // 蓝
        default: [Color(hex: 0x0F9D58), Color(hex: 0x2BB3A0)]  // 绿
        }  // 分支结束
    }  // badgeColors 结束

    private var note: some View {  // 页脚数据说明
        Text(SchoolCatalog.note)  // 直接取 schools.json 的 meta.note
            .font(.system(size: 9.5))  // 9.5 号
            .foregroundStyle(Color.textTertiary)  // 弱化色
            .lineSpacing(1.5)  // 行距
            .padding(.top, 10)  // 上间距
            .padding(.horizontal, 2)  // 左右微调
    }  // note 结束

    // MARK: - 开卷                                                    // 分节：开卷

    private func startCommon() {  // 开通用卷
        guard let bank = app.bank else {  // 题库没好
            toast = "题库还在加载，稍等一下"  // 提示
            return  // 直接返回
        }  // 分支结束
        let count = min(20, bank.questions.count)  // 最多 20 题（样板同）
        let list = MockPaperBuilder.build(school: MockPaperBuilder.commonSchool(trackID: app.data.track),  // 假院校
                                          kindKey: "common",  // 通用卷键
                                          count: count,  // 题量
                                          bank: bank,  // 当前方向题库
                                          trackID: app.data.track)  // 方向 id
        guard !list.isEmpty else {  // 一题都没抽到
            toast = "这套卷暂时没有题，换个方向试试"  // 提示
            return  // 返回
        }  // 分支结束
        run = MockRun(questions: list, title: "通用模考 · \(app.currentTrack.name)")  // 开卷
    }  // startCommon 结束
}  // MockExamView 结束

// MARK: - 选卷弹层                                                      // 分节：选卷

struct SchoolPaperSheet: View {  // 院校下的卷别列表
    let school: School  // 哪所院校
    let app: AppState  // 全局状态（取题库与方向）
    let kind: MockKind  // 当前卷别
    let onStart: ([Question], String) -> Void  // 开卷回调
    let onNeedRoom: () -> Void  // 面试卷的提示回调
    @Environment(\.dismiss) private var dismiss  // 关掉自己

    private var papers: [String] { school.papers.list(for: kind) }  // 该卷别的卷名

    var body: some View {  // 视图主体
        VStack(alignment: .leading, spacing: 0) {  // 纵向排列
            HStack {  // 标题行
                Text(school.name)  // 校名当标题
                    .font(.system(size: 17, weight: .bold))  // 17 加粗
                Spacer()  // 撑开
                Button {  // 关闭
                    dismiss()  // 收起
                } label: {  // 按钮外观
                    Image(systemName: "xmark")  // 叉
                        .font(.system(size: 13, weight: .semibold))  // 图标
                        .foregroundStyle(Color.textSecondary)  // 次要色
                        .frame(width: 28, height: 28)  // 点击区域
                        .background(Circle().fill(Color(hex: 0xF2F3F7)))  // 灰圆底
                }  // 按钮结束
                .buttonStyle(.plain)  // 去掉系统样式
            }  // 横排结束
            .padding(.horizontal, 18)  // 左右
            .padding(.top, 18)  // 上
            .padding(.bottom, 12)  // 下

            ScrollView {  // 内容可滚
                VStack(alignment: .leading, spacing: 0) {  // 纵向排列
                    tags  // 标签与城市
                    Text(tipText)  // 说明（照样板 mks-tip）
                        .font(.system(size: 10))  // 10 号
                        .foregroundStyle(Color.textSecondary)  // 次要色
                        .lineSpacing(1.5)  // 行距
                        .padding(.bottom, 10)  // 下间距

                    if papers.isEmpty {  // 该卷别没卷
                        Text("这所学校暂无该卷别")  // 样板 toast 文案
                            .font(.system(size: 11))  // 11 号
                            .foregroundStyle(Color(hex: 0x9AA1B2))  // 灰蓝
                            .padding(.vertical, 12)  // 上下留白
                    } else {  // 有卷
                        ForEach(Array(papers.enumerated()), id: \.offset) { index, name in  // 逐卷
                            paperRow(index: index, name: name)  // 一行卷
                        }  // 循环结束
                    }  // 分支结束
                }  // 排列结束
                .padding(.horizontal, 18)  // 左右
                .padding(.bottom, 16)  // 底部留白
            }  // 滚动结束
        }  // 排列结束
        .background(Color.appBG)  // 底色
    }  // body 结束

    private var tipText: String {  // 说明文案（照样板 mks-tip 结构）
        if kind == .interview {  // 面试卷
            return "面试模考是 5 位导师轮着问，不是做题，所以放在面试间里进行。"  // 如实说明
        }  // 分支结束
        return "该院校卷按「\(school.focusLabel)」侧重抽题，每套 \(kind.questionCount) 题，同一院校每次抽到的题一致。"  // 照样板原话
    }  // tipText 结束

    private var tags: some View {  // 标签胶囊行
        HStack(spacing: 5) {  // 5 的间距
            ForEach(school.tags, id: \.self) { tag in  // 每个标签
                Text(tag)  // 标签文字
                    .font(.system(size: 9.5, weight: .semibold))  // 9.5 号
                    .foregroundStyle(Color(hex: 0x5D6478))  // 灰蓝
                    .padding(.horizontal, 8)  // 左右
                    .frame(height: 18)  // 高度
                    .background(Capsule().fill(Color(hex: 0xEEF0F6)))  // 浅灰底
            }  // 循环结束
            Text(school.city)  // 城市也算一个标签（样板同）
                .font(.system(size: 9.5, weight: .semibold))  // 9.5 号
                .foregroundStyle(Color(hex: 0x5D6478))  // 灰蓝
                .padding(.horizontal, 8)  // 左右
                .frame(height: 18)  // 高度
                .background(Capsule().fill(Color(hex: 0xEEF0F6)))  // 浅灰底
        }  // 横排结束
        .padding(.bottom, 9)  // 下间距
    }  // tags 结束

    private func paperRow(index: Int, name: String) -> some View {  // 一套卷
        Button {  // 点开卷
            open(index: index, name: name)  // 抽题并开卷
        } label: {  // 行外观
            HStack(spacing: 10) {  // 横向排列
                Text(String(format: "%02d", index + 1))  // 序号补零（样板 mksp-no）
                    .font(.system(size: 11, weight: .heavy))  // 11 特粗
                    .foregroundStyle(Color.appBrand.opacity(0.55))  // 品牌蓝半透明

                VStack(alignment: .leading, spacing: 2) {  // 卷名 + 说明
                    Text(name)  // 卷名
                        .font(.system(size: 12.5, weight: .bold))  // 12.5 加粗
                        .foregroundStyle(Color.textPrimary)  // 主文字色
                    Text(subtitle)  // 「20 题 · 仿真初试」
                        .font(.system(size: 9.5))  // 9.5 号
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 竖排结束

                Spacer(minLength: 0)  // 撑开

                Image(systemName: "chevron.right")  // 箭头
                    .font(.system(size: 10, weight: .semibold))  // 图标
                    .foregroundStyle(Color(hex: 0xC3C9D6))  // 浅灰
            }  // 横排结束
            .padding(.horizontal, 12)  // 左右
            .padding(.vertical, 11)  // 上下
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous)  // 圆角 13
                .fill(Color(hex: 0xF6F7FB)))  // 浅灰底
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统样式
        .padding(.bottom, 7)  // 卷间距
    }  // paperRow 结束

    private var subtitle: String {  // 卷下方那行小字
        kind == .initial ? "\(kind.questionCount) 题 · 仿真初试"  // 初试
                         : "\(kind.questionCount) 题 · 复试笔试"  // 笔试
    }  // subtitle 结束

    private func open(index: Int, name: String) {  // 开某套卷
        if kind == .interview {  // 面试卷不在这里做
            dismiss()  // 先关弹层
            onNeedRoom()  // 交给外层提示去面试间
            return  // 返回
        }  // 分支结束
        guard let bank = app.bank else { return }  // 题库没好就不动
        // 卷别键带序号：同一院校的「卷 A」和「卷 B」必须是两套不同的题
        let kindKey = "\(kind.rawValue)-\(index)"  // 如 initial-0
        let list = MockPaperBuilder.build(school: school,  // 院校（决定种子与权重）
                                          kindKey: kindKey,  // 卷别键
                                          count: kind.questionCount,  // 20 或 10
                                          bank: bank,  // 题库
                                          trackID: app.data.track)  // 方向
        guard !list.isEmpty else { return }  // 抽不到就不开
        dismiss()  // 关掉弹层
        onStart(list, "\(school.name) · \(name)")  // 交给外层开卷
    }  // open 结束
}  // SchoolPaperSheet 结束
