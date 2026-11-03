//  TrackPicker.swift —— 考试方向切换（chip + 弹层）                  // 文件说明
//  对齐样板：appbar 右侧一个 26 高的小胶囊，点开是「你在考什么」底部弹层。
//  切换后不只是换题库：模考院校、面试间、地图岛名都跟着换，所以这个入口
//  放在刷题页导航栏上，全局可见。

import SwiftUI  // 界面框架

// MARK: - 外观映射                                                     // 分节：外观

enum TrackStyle {  // 方向的视觉标识（颜色只影响观感，不是业务数据）
    static func iconChar(_ id: String) -> String {  // 图标里的那个字
        switch id {  // 按方向分支
        case "tax": "税"  // 税务
        case "fin": "金"  // 金融
        case "law": "法"  // 法硕
        case "cs": "计"  // 计算机
        case "med": "医"  // 医学
        default: "考"  // 兜底
        }  // 分支结束
    }  // iconChar 结束

    static func gradient(_ id: String) -> [Color] {  // 图标底色渐变（照样板 .tk-ico.*）
        switch id {  // 按方向分支
        case "tax": [Color(hex: 0x2B54E8), Color(hex: 0x5B7CFF)]  // 蓝
        case "fin": [Color(hex: 0x0F9D58), Color(hex: 0x2BB3A0)]  // 绿
        case "law": [Color(hex: 0x7C4DFF), Color(hex: 0xA175FF)]  // 紫
        case "cs": [Color(hex: 0x0B84A8), Color(hex: 0x4CC4E0)]  // 青
        case "med": [Color(hex: 0xE2402F), Color(hex: 0xFF7A45)]  // 橙红
        default: [Color(hex: 0x2B54E8), Color(hex: 0x5B7CFF)]  // 兜底蓝
        }  // 分支结束
    }  // gradient 结束
}  // TrackStyle 结束

// MARK: - 顶栏胶囊                                                      // 分节：chip

struct TrackChip: View {  // 导航栏右上角的方向胶囊
    @Environment(AppState.self) private var app  // 全局状态
    @State private var showPicker = false  // 是否弹出选择层

    var body: some View {  // 视图主体
        Button {  // 点开弹层
            showPicker = true  // 打开
        } label: {  // 按钮外观
            HStack(spacing: 3) {  // 文字 + 小三角
                Text(app.currentTrack.short)  // 两字简称
                    .font(.system(size: 11, weight: .bold))  // 11 号加粗
                Image(systemName: "chevron.down")  // 向下的三角
                    .font(.system(size: 7, weight: .bold))  // 缩到很小
                    .opacity(0.75)  // 稍淡
            }  // 横排结束
            .foregroundStyle(Color.appBrand)  // 品牌蓝
            .padding(.horizontal, 8)  // 左右内边距
            .frame(height: 26)  // 照样板 26 高
            .background(Capsule().fill(Color(hex: 0xEEF1FF)))  // 浅蓝底
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统按钮样式
        .sheet(isPresented: $showPicker) {  // 弹出方向选择
            TrackPickerSheet()  // 选择层
                .presentationDetents([.medium])  // 半屏就够
                .presentationDragIndicator(.visible)  // 显示顶部小横条
        }  // 弹层结束
    }  // body 结束
}  // TrackChip 结束

// MARK: - 选择弹层                                                      // 分节：弹层

struct TrackPickerSheet: View {  // 「你在考什么」
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.dismiss) private var dismiss  // 关掉自己

    var body: some View {  // 视图主体
        VStack(alignment: .leading, spacing: 0) {  // 竖排
            HStack {  // 标题行
                Text("你在考什么")  // 标题照样板原话
                    .font(.system(size: 17, weight: .bold))  // 17 号加粗
                Spacer()  // 撑开
                Button {  // 关闭按钮
                    dismiss()  // 收起
                } label: {  // 按钮外观
                    Image(systemName: "xmark")  // 叉
                        .font(.system(size: 13, weight: .semibold))  // 图标大小
                        .foregroundStyle(Color.textSecondary)  // 次要色
                        .frame(width: 28, height: 28)  // 点击区域
                        .background(Circle().fill(Color(hex: 0xF2F3F7)))  // 灰圆底
                }  // 按钮结束
                .buttonStyle(.plain)  // 去掉系统样式
            }  // 横排结束
            .padding(.horizontal, 18)  // 左右
            .padding(.top, 18)  // 上边距
            .padding(.bottom, 12)  // 下边距

            Text("切换后：刷题题库、模考院校、面试间、世界地图上的「你在这里」都会跟着换。")  // 样板原话
                .font(.system(size: 10.5))  // 10.5 号
                .foregroundStyle(Color.textSecondary)  // 次要色
                .lineSpacing(2)  // 行距
                .padding(.horizontal, 18)  // 左右
                .padding(.bottom, 10)  // 下边距

            ScrollView {  // 方��多了也能滚
                VStack(spacing: 7) {  // 7 的间距（照样板 gap）
                    ForEach(Track.all) { track in  // 五个方向
                        row(track)  // 每一行
                    }  // 循环结束
                }  // 竖排结束
                .padding(.horizontal, 18)  // 左右
                .padding(.bottom, 12)  // 底部留白
            }  // 滚动结束
        }  // 竖排结束
        .background(Color.appBG)  // 底色
    }  // body 结束

    private func row(_ track: Track) -> some View {  // 一行方向
        let on = app.data.track == track.id  // 是否当前选中
        return Button {  // 点选
            app.setTrack(track.id)  // 切换（写盘 + 刷新）
            dismiss()  // 收起弹层
        } label: {  // 按钮外观
            HStack(spacing: 10) {  // 图标 + 文字 + 人数
                Text(TrackStyle.iconChar(track.id))  // 图标里的字
                    .font(.system(size: 13, weight: .heavy))  // 13 号特粗
                    .foregroundStyle(.white)  // 白字
                    .frame(width: 32, height: 32)  // 32 方块
                    .background(LinearGradient(colors: TrackStyle.gradient(track.id),  // 渐变底
                                               startPoint: .topLeading, endPoint: .bottomTrailing))  // 左上到右下
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))  // 圆角 11

                VStack(alignment: .leading, spacing: 2) {  // 主标题 + 说明
                    Text(track.name)  // 方向全称
                        .font(.system(size: 12.5, weight: .semibold))  // 12.5 号
                        .foregroundStyle(Color.textPrimary)  // 主文字色
                    Text(track.desc)  // 一句话说明
                        .font(.system(size: 9.5))  // 9.5 号
                        .foregroundStyle(Color.textSecondary)  // 次要色
                        .lineLimit(1)  // 只留一行
                }  // 竖排结束
                Spacer(minLength: 0)  // 撑开
                Text("\(track.people)")  // 备考人数
                    .font(.system(size: 9.5))  // 9.5 号
                    .foregroundStyle(Color(hex: 0x9AA1B2))  // 灰蓝
            }  // 横排结束
            .padding(.horizontal, 12)  // 左右内边距
            .padding(.vertical, 11)  // 上下内边距
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                .fill(on ? Color.appCard : Color(hex: 0xF6F7FB)))  // 选中白底，未选浅灰
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 选中描边
                .strokeBorder(Color.appBrand, lineWidth: on ? 1.5 : 0))  // 只给选中的画
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统样式
    }  // row 结束
}  // TrackPickerSheet 结束
