//  InterviewRoomList.swift —— 三个面试间（对齐样板 interview.js 的 ROOMS）// 文件说明
//  样板房间数据是写死的三间：税务专硕复试间 / 压力面试间 / 英语强化间。
//  ⚠️ 已知差距：英语强化间在样板里是全英文问答，本工程引擎目前只有中文题库
//     与中文播报，进去后仍是中文流程。房卡描述照实写了「题型为中文」，不冒充。

import SwiftUI  // 界面框架

struct InterviewRoom: Identifiable {  // 一个面试间
    let id: String  // 房间 id
    let name: String  // 房间名
    let detail: String  // 一句话说明（样板 desc）
    let tags: [String]  // 三个标签胶囊
    let mentors: Int  // 几位导师
    let mode: InterviewMode  // 面试类型
    let style: MentorStyle  // 导师风格
    let gradient: [Color]  // 图标底色

    static let all: [InterviewRoom] = [  // 三间，顺序与样板一致
        InterviewRoom(id: "tax", name: "税务专硕复试间",  // 标准复试
                      detail: "5 位导师 · 自我介绍 → 专业抽题 → 追问 → 英语 → 综合",  // 样板原话
                      tags: ["标准复试", "约 15 分钟", "中文为主"],  // 样板标签
                      mentors: 5, mode: .professional, style: .standard,  // 专业 + 标准
                      gradient: [Color(hex: 0x2B54E8), Color(hex: 0x5B7CFF)]),  // 蓝
        InterviewRoom(id: "stress", name: "压力面试间",  // 高压
                      detail: "5 位导师 · 追问密集，专挑回答里的空话",  // 样板原话
                      tags: ["高压", "约 12 分钟", "追问密集"],  // 样板标签
                      mentors: 5, mode: .experience, style: .strict,  // 经历追问 + 严格
                      gradient: [Color(hex: 0xE2402F), Color(hex: 0xFF7A45)]),  // 红橙
        InterviewRoom(id: "english", name: "英语强化间",  // 英语
                      detail: "5 位导师 · 英文提问，题型为中文，答完给表达建议",  // 如实改写（样板写「3 位导师全英文」）
                      tags: ["英文提问", "约 10 分钟", "口语"],  // 标签
                      mentors: 5, mode: .general, style: .gentle,  // 综合 + 温和
                      gradient: [Color(hex: 0x0F9D58), Color(hex: 0x2BB3A0)]),  // 绿
    ]  // 房间表结束
}  // InterviewRoom 结束

struct InterviewRoomList: View {  // 面试间列表（样板 page-interview 的「选择面试间」）
    var body: some View {  // 视图主体
        VStack(spacing: 8) {  // 8 的间距（样板 .room-list gap）
            ForEach(InterviewRoom.all) { room in  // 逐间
                NavigationLink {  // 进房间
                    InterviewRoomView(mode: room.mode, style: room.style)  // 面试房间
                } label: {  // 房卡外观
                    card(room)  // 单张房卡
                }  // 链接结束
                .buttonStyle(.plain)  // 去掉系统高亮
            }  // 循环结束
        }  // 排列结束
    }  // body 结束

    private func card(_ room: InterviewRoom) -> some View {  // 一张房卡（样板 .room-card）
        HStack(spacing: 11) {  // 横向排列
            Image(systemName: room.id == "english" ? "character.bubble.fill" : "person.3.fill")  // 图标
                .font(.system(size: 15))  // 图标大小
                .foregroundStyle(.white)  // 白图标
                .frame(width: 34, height: 34)  // 34 方块
                .background(LinearGradient(colors: room.gradient,  // 渐变底
                                           startPoint: .topLeading, endPoint: .bottomTrailing))  // 对角
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))  // 圆角 11

            VStack(alignment: .leading, spacing: 3) {  // 文字区
                Text(room.name)  // 房间名
                    .font(.system(size: 12.5, weight: .bold))  // 12.5 加粗
                    .foregroundStyle(Color.textPrimary)  // 主色
                Text(room.detail)  // 说明
                    .font(.system(size: 10))  // 10 号
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .lineLimit(2)  // 最多两行
                HStack(spacing: 4) {  // 标签胶囊行
                    ForEach(room.tags, id: \.self) { tag in  // 逐个标签
                        Text(tag)  // 标签文字
                            .font(.system(size: 9))  // 9 号
                            .foregroundStyle(Color(hex: 0x5D6478))  // 灰蓝
                            .padding(.horizontal, 6)  // 左右
                            .frame(height: 16)  // 高度
                            .background(Capsule().fill(Color(hex: 0xEEF0F6)))  // 浅灰底
                    }  // 循环结束
                }  // 横排结束
                .padding(.top, 1)  // 与说明留一点
            }  // 竖排结束

            Spacer(minLength: 0)  // 撑开

            Image(systemName: "chevron.right")  // 箭头
                .font(.system(size: 12, weight: .semibold))  // 图标
                .foregroundStyle(Color(hex: 0xC3C9D6))  // 浅灰
        }  // 横排结束
        .padding(.horizontal, 12)  // 左右
        .padding(.vertical, 11)  // 上下
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
            .fill(Color.appCard))  // 白底
    }  // card 结束
}  // InterviewRoomList 结束

struct InterviewRoomsPage: View {  // 面试间列表独立页（今日页「继续学习」会跳这里）
    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.m) {  // 纵向排列
                Text("任选一间进入，进去后 5 位导师轮流提问。")  // 说明
                    .font(.system(size: 11))  // 11 号
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
                InterviewRoomList()  // 三间
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部让开悬浮 TabBar
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("选择面试间")  // 标题
        .navigationBarTitleDisplayMode(.inline)  // 内联
    }  // body 结束
}  // InterviewRoomsPage 结束
