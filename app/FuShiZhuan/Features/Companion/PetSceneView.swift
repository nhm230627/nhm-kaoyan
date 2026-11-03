//  PetSceneView.swift —— 伙伴形象：一只直立的猫（程序化几何体）          // 文件说明
//  姿态：直立站姿（用户 2026-11-03 明确要求），两臂垂在身侧、两腿站立、尾巴在身后上翘
//  视觉细节对齐 Web 样板 pet.js：橘猫配色、腮部白毛、ω 嘴、额头三道橘纹、分段流苏、尾尖白
//  颜色与配件来自 outfits.json；形状由代码给，换装只换数据不换形状                  // 数据约定
//  只用 generateSphere / generateCylinder / generateBox 三种网格，避免未验证 API    // 实现约束

import RealityKit  // 3D 引擎
import SwiftUI  // 界面框架
import UIKit  // UIColor

// MARK: - 配色与尺寸                                                  // 分节：常量

enum CatPalette {  // 猫的固定用色（毛色不在这里，来自配件表）
    static let eye = UIColor(hex: "2B3040")  // 眼睛：样板的深灰蓝
    static let eyeShine = UIColor(hex: "FFFFFF")  // 眼里的高光点
    static let pink = UIColor(hex: "FFA8BD")  // 鼻头与内耳：样板粉
    static let paw = UIColor(hex: "FFA8BD")  // 肉垫
    static let whisker = UIColor(hex: "E8E8EE")  // 胡须：近白
    static let mouth = UIColor(hex: "2B3040")  // 嘴：深灰
    static let ground = UIColor(hex: "C9D0DC")  // 地台：浅灰
    static let cord = UIColor(hex: "EF3B30")  // 流苏红
    static let gold = UIColor(hex: "FFC93C")  // 流苏金环
}  // CatPalette 结束

enum CatMetrics {  // 尺寸（直立姿态基准）
    static let petScale: Float = 0.76  // 整只缩放
    static let bodyRadius: Float = 0.26  // 身体半径
    static let headRadius: Float = 0.255  // 头半径
    static let headY: Float = 0.92  // 头心高度（直立后比坐姿高一截）
    static let topY: Float = 1.175  // 头顶，帽子放这里
    static let tailName = "cat.tail"  // 尾巴节点名，动画按名字找
}  // CatMetrics 结束

// MARK: - 视图入口                                                    // 分节：入口

/// 3D 伙伴（直立的猫）。jumpToken / flipToken / wagToken 每加 1 播一次动作
struct PetSceneView: UIViewRepresentable {  // 3D 视图
    let stage: PetStage  // 成长阶段，决定体型与帽子大小
    var outfit: CatOutfit = .default  // 当前穿戴
    var jumpToken: Int = 0  // 投喂时 +1
    var flipToken: Int = 0  // 拨穗时 +1
    var wagToken: Int = 0  // 摸头时 +1，尾巴摆一下

    @Environment(\.accessibilityReduceMotion) private var reduceMotion  // 系统「减弱动态效果」
    @AppStorage("app.pet.static3D") private var staticMode = false  // 应用内省电开关

    private var animationsOff: Bool { staticMode || reduceMotion }  // 两个开关任一打开就不放动画

    func makeUIView(context: Context) -> ARView {  // 建场景
        let view = ARView(frame: .zero,  // 不用 SwiftUI 的 ARView（那是 ARKit 相机视图）
                          cameraMode: .nonAR,  // 不启用摄像头，纯 3D 摆件
                          automaticallyConfigureSession: false)  // 不配置 AR 会话，避免要相机权限
        view.environment.background = .color(UIColor(hex: "F2F3F7"))  // 与卡片底色一致
        view.renderOptions.insert(.disableMotionBlur)  // 关动态模糊，省电也稳
        PetSceneBuilder.installCamera(on: view)  // 放一台固定相机
        let cat = PetSceneBuilder.build(stage: stage, outfit: outfit)  // 搭猫
        let anchor = AnchorEntity()  // 世界原点锚点
        anchor.addChild(cat)  // 挂上猫
        view.scene.addAnchor(anchor)  // 加入场景
        context.coordinator.pet = cat  // 存引用便于播动画
        context.coordinator.tassel = cat.findEntity(named: PetSceneBuilder.tasselName)  // 找流苏节点
        context.coordinator.tail = cat.findEntity(named: CatMetrics.tailName)  // 找尾巴节点
        context.coordinator.stage = stage  // 记下当前阶段
        context.coordinator.outfit = outfit  // 记下当前穿戴
        context.coordinator.animationsOff = animationsOff  // 同步动效开关
        if !animationsOff { context.coordinator.playIdle() }  // 开着就轻微起伏
        return view  // 返回
    }  // makeUIView 结束

    func updateUIView(_ view: ARView, context: Context) {  // 状态变化时
        let coordinator = context.coordinator  // 拿协调器
        if stage != coordinator.stage || outfit != coordinator.outfit {  // 阶段或穿戴变了
            coordinator.stage = stage  // 更新记录
            coordinator.outfit = outfit  // 更新穿戴
            coordinator.rebuild(stage: stage, outfit: outfit)  // 重建猫
        }  // 分支结束
        if animationsOff != coordinator.animationsOff {  // 动效开关变了
            coordinator.animationsOff = animationsOff  // 同步
            coordinator.rebuild(stage: stage, outfit: outfit)  // 重建回静止姿态
        }  // 分支结束
        if jumpToken != coordinator.lastJump {  // 要求跳
            coordinator.lastJump = jumpToken  // 记下
            if jumpToken > 0 { coordinator.jump() }  // 第一次进入不播
        }  // 分支结束
        if flipToken != coordinator.lastFlip {  // 要求拨穗
            coordinator.lastFlip = flipToken  // 记下
            if flipToken > 0 { coordinator.flipTassel() }  // 第一次进入不播
        }  // 分支结束
        if wagToken != coordinator.lastWag {  // 要求摆尾
            coordinator.lastWag = wagToken  // 记下
            if wagToken > 0 { coordinator.wagTail() }  // 第一次进入不播
        }  // 分支结束
    }  // updateUIView 结束

    func makeCoordinator() -> Coordinator { Coordinator() }  // 建协调器

    // MARK: - 协调器                                                  // 分节：协调器

    final class Coordinator {  // 持有节点与动画状态
        var pet: Entity?  // 猫根节点
        var tassel: Entity?  // 流苏节点
        var tail: Entity?  // 尾巴节点
        var stage: PetStage?  // 当前阶段
        var outfit: CatOutfit?  // 当前穿戴
        var lastJump = 0  // 上次跳跃 token
        var lastFlip = 0  // 上次拨穗 token
        var lastWag = 0  // 上次摆尾 token
        var animationsOff = false  // 是否关闭动效

        func rebuild(stage: PetStage, outfit: CatOutfit) {  // 重建猫
            guard let pet = pet, let parent = pet.parent else { return }  // 没节点就不动
            let base = pet.transform  // 记住当前位置（起伏动画改过它）
            pet.removeFromParent()  // 移除旧的
            let fresh = PetSceneBuilder.build(stage: stage, outfit: outfit)  // 建新的
            fresh.transform = base  // 回到同一姿态
            parent.addChild(fresh)  // 挂回去
            self.pet = fresh  // 更新引用
            self.tassel = fresh.findEntity(named: PetSceneBuilder.tasselName)  // 重新找流苏
            self.tail = fresh.findEntity(named: CatMetrics.tailName)  // 重新找尾巴
            if !animationsOff { playIdle() }  // 开着动效才继续起伏
        }  // rebuild 结束

        func playIdle() {  // 轻微上下起伏
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let pet = pet else { return }  // 没节点就退出
            var up = pet.transform  // 上升姿态
            up.translation.y += 0.025  // 抬 2.5 厘米
            let move = FromToByAnimation<Transform>(from: pet.transform,  // 起点
                                                    to: up,  // 终点
                                                    duration: 1.8,  // 单程时长
                                                    timing: .easeInOut,  // 缓入缓出
                                                    bindTarget: .transform)  // 作用在变换上
            guard let resource = try? AnimationResource.generate(with: move) else { return }  // 生成资源
            pet.playAnimation(resource.repeat(count: 9_999))  // 来回起伏
        }  // playIdle 结束

        func jump() {  // 投喂后跳一下
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let pet = pet else { return }  // 没节点就退出
            let base = pet.transform  // 原地姿态
            var up = base  // 上升姿态
            up.translation.y += 0.16  // 抬 16 厘米
            let lift = FromToByAnimation<Transform>(from: base, to: up,  // 起跳
                                                    duration: 0.18, timing: .easeOut, bindTarget: .transform)  // 快起
            let fall = FromToByAnimation<Transform>(from: up, to: base,  // 落下
                                                    duration: 0.26, timing: .easeIn, bindTarget: .transform)  // 慢落
            guard let first = try? AnimationResource.generate(with: lift),  // 起跳资源
                  let second = try? AnimationResource.generate(with: fall) else { return }  // 落下资源
            pet.playAnimation(first)  // 播起跳
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {  // 起跳结束后
                pet.playAnimation(second)  // 播落下
            }  // 延迟结束
        }  // jump 结束

        func flipTassel() {  // 拨穗：流苏从右拨到左
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let tassel = tassel else { return }  // 没流苏就退出
            let start = tassel.transform  // 起始姿态
            var end = start  // 结束姿态
            end.rotation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * start.rotation  // 绕自身竖轴转半圈
            let swing = FromToByAnimation<Transform>(from: start, to: end,  // 拨动
                                                     duration: 0.7, timing: .easeInOut, bindTarget: .transform)  // 慢速划过
            guard let resource = try? AnimationResource.generate(with: swing) else { return }  // 生成资源
            tassel.playAnimation(resource)  // 播一次
        }  // flipTassel 结束

        func wagTail() {  // 摸头：尾巴摆一下
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let tail = tail else { return }  // 没尾巴就退出
            let start = tail.transform  // 起始姿态
            var end = start  // 结束姿态
            end.rotation = simd_quatf(angle: .pi / 5, axis: [0, 1, 0]) * start.rotation  // 绕竖轴摆 36 度
            let swing = FromToByAnimation<Transform>(from: start, to: end,  // 摆出去
                                                     duration: 0.22, timing: .easeOut, bindTarget: .transform)  // 快摆
            let back = FromToByAnimation<Transform>(from: end, to: start,  // 摆回来
                                                    duration: 0.28, timing: .easeInOut, bindTarget: .transform)  // 慢回
            guard let first = try? AnimationResource.generate(with: swing),  // 摆出资源
                  let second = try? AnimationResource.generate(with: back) else { return }  // 摆回资源
            tail.playAnimation(first)  // 先摆出去
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {  // 到最外侧
                tail.playAnimation(second)  // 再摆回来
            }  // 延迟结束
        }  // wagTail 结束
    }  // Coordinator 结束
}  // PetSceneView 结束

// MARK: - 建模                                                        // 分节：建模

enum PetSceneBuilder {  // 猫建模器
    static let tasselName = "cat.tassel"  // 流苏节点名
    static let catalog = OutfitCatalog.shared  // 配件表全局共用

    /// 放一台固定相机：略高于猫、正前方 1.6 米（直立后要抬眼看）
    static func installCamera(on view: ARView) {  // 装相机
        let camera = PerspectiveCamera()  // 相机实体
        camera.camera.fieldOfViewInDegrees = 44  // 视角
        let holder = AnchorEntity(world: [0, 0.72, 1.62])  // 相机位置
        holder.addChild(camera)  // 挂上相机
        view.scene.addAnchor(holder)  // 加入场景
    }  // installCamera 结束

    /// 搭一只直立的猫，朝 +Z 面向相机
    static func build(stage: PetStage, outfit: CatOutfit) -> Entity {  // 搭猫
        let root = Entity()  // 根节点
        root.name = "pet.root"  // 便于调试查找
        let fur = furColor(outfit: outfit, accent: false)  // 毛色
        let cream = furColor(outfit: outfit, accent: true)  // 肚皮与腮的浅色

        root.addChild(torso(fur: fur, cream: cream))  // 躯干
        root.addChild(arms(fur: fur, cream: cream))  // 两臂
        root.addChild(legs(fur: fur, cream: cream))  // 两腿
        root.addChild(head(fur: fur, cream: cream))  // 头与五官
        root.addChild(tail(fur: fur, cream: cream))  // 尾巴
        root.addChild(wearables(stage: stage, outfit: outfit))  // 可换配件

        let ground = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.34),  // 地台
                                 materials: [material(CatPalette.ground)])  // 灰色
        ground.position = [0, 0.006, 0]  // 贴地
        root.addChild(ground)  // 挂上

        root.scale = [CatMetrics.petScale, CatMetrics.petScale, CatMetrics.petScale]  // 整体缩放
        return root  // 返回整只
    }  // build 结束

    // MARK: - 躯干与四肢                                            // 分节：身体

    static func torso(fur: UIColor, cream: UIColor) -> Entity {  // 躯干
        let group = Entity()  // 躯干整体
        let body = sphere(radius: CatMetrics.bodyRadius, color: fur)  // 身体
        body.position = [0, 0.42, 0]  // 站在地上
        body.scale = [0.92, 1.18, 0.88]  // 竖起来，不是圆球
        group.addChild(body)  // 挂上

        let chest = sphere(radius: 0.185, color: cream)  // 胸前浅色毛
        chest.position = [0, 0.45, 0.135]  // 胸口偏前
        chest.scale = [1, 1.15, 0.55]  // 压成片
        group.addChild(chest)  // 挂上
        return group  // 返回躯干
    }  // torso 结束

    static func arms(fur: UIColor, cream: UIColor) -> Entity {  // 两臂与手
        let group = Entity()  // 手臂整体
        for side in [-1.0, 1.0] {  // 左右各一
            let arm = sphere(radius: 0.062, color: fur)  // 上臂
            arm.position = [Float(side) * 0.225, 0.44, 0.02]  // 垂在身侧
            arm.scale = [0.85, 2.1, 0.85]  // 拉长成手臂
            group.addChild(arm)  // 挂上

            let hand = sphere(radius: 0.068, color: cream)  // 手（白手套）
            hand.position = [Float(side) * 0.238, 0.235, 0.045]  // 手臂末端
            group.addChild(hand)  // 挂上
        }  // 循环结束
        return group  // 返回手臂
    }  // arms 结束

    static func legs(fur: UIColor, cream: UIColor) -> Entity {  // 两腿与脚
        let group = Entity()  // 腿整体
        for side in [-1.0, 1.0] {  // 左右各一
            let leg = sphere(radius: 0.075, color: fur)  // 腿
            leg.position = [Float(side) * 0.105, 0.16, 0.01]  // 身体下方
            leg.scale = [0.95, 1.7, 0.95]  // 拉长
            group.addChild(leg)  // 挂上

            let foot = sphere(radius: 0.072, color: cream)  // 脚掌
            foot.position = [Float(side) * 0.105, 0.052, 0.06]  // 落地并往前伸
            foot.scale = [1, 0.6, 1.35]  // 压扁拉长
            group.addChild(foot)  // 挂上

            let pad = sphere(radius: 0.028, color: CatPalette.paw)  // 肉垫
            pad.position = [Float(side) * 0.105, 0.048, 0.13]  // 脚掌前缘
            pad.scale = [1, 0.5, 0.8]  // 扁平
            group.addChild(pad)  // 挂上
        }  // 循环结束
        return group  // 返回腿
    }  // legs 结束

    // MARK: - 头与五官                                              // 分节：头部

    static func head(fur: UIColor, cream: UIColor) -> Entity {  // 头与五官
        let group = Entity()  // 头部整体
        let skull = sphere(radius: CatMetrics.headRadius, color: fur)  // 头
        skull.position = [0, CatMetrics.headY, 0]  // 躯干上方
        skull.scale = [1.06, 0.98, 0.98]  // 略宽，像猫脸
        group.addChild(skull)  // 挂上

        group.addChild(ears(fur: fur))  // 两只尖耳
        group.addChild(face(fur: fur, cream: cream))  // 腮白毛与五官
        return group  // 返回头部
    }  // head 结束

    static func ears(fur: UIColor) -> Entity {  // 尖耳
        let group = Entity()  // 耳朵整体
        for side in [-1.0, 1.0] {  // 左右各一
            let ear = sphere(radius: 0.088, color: fur)  // 外耳
            ear.position = [Float(side) * 0.155, 1.115, -0.01]  // 头顶两侧
            ear.scale = [0.85, 1.55, 0.5]  // 拉长压扁成尖
            ear.orientation = simd_quatf(angle: Float(side) * 0.28, axis: [0, 0, 1])  // 向外倾
            group.addChild(ear)  // 挂上

            let inner = sphere(radius: 0.052, color: CatPalette.pink)  // 内耳
            inner.position = [Float(side) * 0.152, 1.105, 0.03]  // 稍前稍下
            inner.scale = [0.8, 1.4, 0.35]  // 比外耳小一圈
            inner.orientation = simd_quatf(angle: Float(side) * 0.28, axis: [0, 0, 1])  // 同角度
            group.addChild(inner)  // 挂上
        }  // 循环结束
        return group  // 返回耳朵
    }  // ears 结束

    static func face(fur: UIColor, cream: UIColor) -> Entity {  // 腮、眼、鼻、嘴、胡须、额纹
        let group = Entity()  // 面部整体
        for side in [-1.0, 1.0] {  // 左右对称的部分
            let cheek = sphere(radius: 0.098, color: cream)  // 腮部白毛（没有这个猫脸就是块圆面包）
            cheek.position = [Float(side) * 0.175, 0.855, 0.155]  // 脸下方两侧
            cheek.scale = [1, 0.85, 0.55]  // 压成片
            group.addChild(cheek)  // 挂上

            let eye = sphere(radius: 0.047, color: CatPalette.eye)  // 眼睛
            eye.position = [Float(side) * 0.095, 0.945, 0.222]  // 脸前方
            eye.scale = [1, 1.18, 0.66]  // 竖椭圆
            group.addChild(eye)  // 挂上

            let shine = sphere(radius: 0.014, color: CatPalette.eyeShine)  // 高光点
            shine.position = [Float(side) * 0.108, 0.962, 0.252]  // 眼睛右上
            group.addChild(shine)  // 挂上

            for i in 0..<3 {  // 每侧三根胡须
                let whisker = ModelEntity(mesh: .generateCylinder(height: 0.12, radius: 0.0035),  // 细杆
                                          materials: [material(CatPalette.whisker)])  // 近白色
                whisker.position = [Float(side) * 0.175, 0.875 + Float(i) * 0.02, 0.20]  // 腮两侧
                whisker.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])  // 转成横向
                whisker.orientation *= simd_quatf(angle: Float(side) * 0.24, axis: [0, 1, 0])  // 向外撇
                group.addChild(whisker)  // 挂上
            }  // 胡须循环结束

            let lip = ModelEntity(mesh: .generateCylinder(height: 0.055, radius: 0.005),  // ω 嘴的半边
                                  materials: [material(CatPalette.mouth)])  // 深灰
            lip.position = [Float(side) * 0.032, 0.848, 0.245]  // 鼻子下方左右
            lip.orientation = simd_quatf(angle: Float(side) * 0.55, axis: [0, 0, 1])  // 斜成八字
            group.addChild(lip)  // 挂上
        }  // 循环结束

        let nose = sphere(radius: 0.027, color: CatPalette.pink)  // 鼻头
        nose.position = [0, 0.882, 0.248]  // 脸中央略下
        nose.scale = [1.15, 0.9, 0.8]  // 压成小三角
        group.addChild(nose)  // 挂上

        for dx in [Float(-0.062), 0, 0.062] {  // 额头三道橘纹
            let stripe = ModelEntity(mesh: .generateCylinder(height: 0.075, radius: 0.009),  // 细纹
                                     materials: [material(darken(fur, by: 0.16))])  // 比毛色深一档
            stripe.position = [dx, 1.045, 0.165]  // 额头偏前
            stripe.orientation = simd_quatf(angle: -0.5, axis: [1, 0, 0])  // 顺着额头斜面
            group.addChild(stripe)  // 挂上
        }  // 循环结束
        return group  // 返回面部
    }  // face 结束

    // MARK: - 尾巴                                                  // 分节：尾巴

    static func tail(fur: UIColor, cream: UIColor) -> Entity {  // 尾巴：从身后向右上方翘
        let pivot = Entity()  // 尾巴根部节点，摆动转它
        pivot.name = CatMetrics.tailName  // 起名方便查找
        pivot.position = [0.13, 0.30, -0.17]  // 身体右后下方
        var radius: Float = 0.058  // 起始粗细
        for i in 0..<7 {  // 七段串成弧线
            let t = Float(i)  // 段序号
            let isTip = i == 6  // 最后一段
            let seg = sphere(radius: radius, color: isTip ? cream : fur)  // 尾尖是白毛
            seg.position = [0.028 * t, 0.052 * t + 0.008 * t * t, -0.035 * t]  // 向上向右翘
            pivot.addChild(seg)  // 挂上
            radius *= 0.9  // 越末端越细
        }  // 循环结束
        return pivot  // 返回尾巴根
    }  // tail 结束

    // MARK: - 配件                                                  // 分节：配件

    static func wearables(stage: PetStage, outfit: CatOutfit) -> Entity {  // 按穿戴装配件
        let group = Entity()  // 配件整体
        let hat = catalog.item(id: outfit.id(for: .hat) ?? "")  // 头顶配件
        if let hat, hat.id != "hat.none" {  // 不是「不戴」
            group.addChild(hatEntity(hat, stage: stage))  // 装帽子
        }  // 分支结束
        let faceItem = catalog.item(id: outfit.id(for: .face) ?? "")  // 脸部配件
        if let faceItem, faceItem.id != "face.none" {  // 不是「不戴」
            group.addChild(glassesEntity(faceItem))  // 装眼镜
        }  // 分支结束
        let neck = catalog.item(id: outfit.id(for: .neck) ?? "")  // 颈部配件
        if let neck, neck.id != "neck.none" {  // 不是「不戴」
            group.addChild(neckEntity(neck))  // 装围巾或项圈
        }  // 分支结束
        let back = catalog.item(id: outfit.id(for: .back) ?? "")  // 背部配件
        if let back, back.id != "back.none" {  // 不是「不戴」
            group.addChild(backEntity(back))  // 装背包或披风
        }  // 分支结束
        return group  // 返回配件组
    }  // wearables 结束

    static func hatEntity(_ item: OutfitItem, stage: PetStage) -> Entity {  // 帽子
        let group = Entity()  // 帽子整体
        group.position = [0, CatMetrics.topY, 0]  // 头顶
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id == "hat.graduate" {  // 学士帽（样板样子：帽围 + 45° 帽板 + 红流苏）
            let crown = ModelEntity(mesh: .generateCylinder(height: 0.062, radius: 0.135),  // 帽围
                                    materials: [material(main)])  // 主色
            group.addChild(crown)  // 挂上
            let board = ModelEntity(mesh: .generateBox(width: 0.32, height: 0.016, depth: 0.32, cornerRadius: 0.004),  // 帽板
                                    materials: [material(main)])  // 主色
            board.position = [0, 0.042, 0]  // 帽围上方
            board.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])  // 转 45°，与样板一致
            group.addChild(board)  // 挂上
            let edge = ModelEntity(mesh: .generateBox(width: 0.335, height: 0.006, depth: 0.335, cornerRadius: 0.002),  // 帽板亮边
                                   materials: [material(accent)])  // 点缀色
            edge.position = [0, 0.052, 0]  // 帽板之上
            edge.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])  // 同角度
            group.addChild(edge)  // 挂上
            group.addChild(tasselNode())  // 挂流苏
        } else if item.id == "hat.beanie" {  // 毛线帽
            let dome = sphere(radius: 0.152, color: main)  // 半球
            dome.scale = [1, 0.72, 1]  // 压扁
            dome.position = [0, 0.012, 0]  // 盖住头顶
            group.addChild(dome)  // 挂上
            let brim = ModelEntity(mesh: .generateCylinder(height: 0.035, radius: 0.155),  // 帽檐
                                   materials: [material(main)])  // 主色
            group.addChild(brim)  // 挂上
            let pom = sphere(radius: 0.055, color: accent)  // 绒球
            pom.position = [0, 0.135, 0]  // 顶部
            group.addChild(pom)  // 挂上
        } else if item.id == "hat.crown" {  // 小皇冠
            let band = ModelEntity(mesh: .generateCylinder(height: 0.045, radius: 0.13),  // 冠环
                                   materials: [material(main, metallic: true)])  // 金属
            group.addChild(band)  // 挂上
            for i in 0..<5 {  // 五个尖
                let angle = Float(i) * (2 * .pi / 5)  // 均分一圈
                let spike = sphere(radius: 0.03, color: main)  // 尖（用球拉长）
                spike.scale = [0.7, 2.0, 0.7]  // 拉高
                spike.position = [cos(angle) * 0.11, 0.055, sin(angle) * 0.11]  // 沿环排布
                group.addChild(spike)  // 挂上
            }  // 循环结束
            let gem = sphere(radius: 0.022, color: accent)  // 正中宝石
            gem.position = [0, 0.01, 0.132]  // 正面
            group.addChild(gem)  // 挂上
        } else if item.id == "hat.headphones" {  // 耳机
            let band = ModelEntity(mesh: .generateBox(width: 0.30, height: 0.028, depth: 0.035, cornerRadius: 0.012),  // 横梁
                                   materials: [material(main)])  // 主色
            band.position = [0, 0.06, 0]  // 头顶上方
            group.addChild(band)  // 挂上
            for side in [-1.0, 1.0] {  // 左右耳罩
                let cup = ModelEntity(mesh: .generateCylinder(height: 0.05, radius: 0.055),  // 耳罩
                                      materials: [material(main)])  // 主色
                cup.position = [Float(side) * 0.15, -0.03, 0]  // 两侧
                cup.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])  // 横放
                group.addChild(cup)  // 挂上
                let glow = sphere(radius: 0.02, color: accent)  // 指示灯光
                glow.position = [Float(side) * 0.175, -0.03, 0.02]  // 耳罩外侧
                group.addChild(glow)  // 挂上
            }  // 循环结束
        }  // 分支结束

        if stage == .seed { group.scale = [0.88, 0.88, 0.88] }  // 幼体帽子小一号
        return group  // 返回帽子
    }  // hatEntity 结束

    static func tasselNode() -> Entity {  // 流苏（样板是分段拼接，不是单根棍）
        let tassel = Entity()  // 流苏节点
        tassel.name = tasselName  // 起名方便拨穗
        tassel.position = [0, 0.05, 0]  // 帽顶

        let knot = sphere(radius: 0.024, color: CatPalette.gold)  // 帽顶金扣
        knot.position = [0, 0.008, 0]  // 正上方
        tassel.addChild(knot)  // 挂上

        let cordA = ModelEntity(mesh: .generateCylinder(height: 0.15, radius: 0.006),  // 帽顶到帽檐
                                materials: [material(CatPalette.cord)])  // 红绳
        cordA.position = [0.075, -0.02, 0.05]  // 斜向帽檐
        cordA.orientation = simd_quatf(angle: 0.6, axis: [0, 0, 1])  // 往右下斜
        tassel.addChild(cordA)  // 挂上

        let cordB = ModelEntity(mesh: .generateCylinder(height: 0.16, radius: 0.005),  // 垂直垂下
                                materials: [material(CatPalette.cord)])  // 红绳
        cordB.position = [0.14, -0.13, 0.05]  // 帽檐外侧
        tassel.addChild(cordB)  // 挂上

        let ring = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.022),  // 金环
                               materials: [material(CatPalette.gold, metallic: true)])  // 金属
        ring.position = [0.14, -0.215, 0.05]  // 绳末端
        tassel.addChild(ring)  // 挂上

        for dx in [Float(-0.016), 0, 0.016] {  // 三根穗子
            let strand = ModelEntity(mesh: .generateCylinder(height: 0.075, radius: 0.006),  // 穗
                                     materials: [material(CatPalette.cord)])  // 红色
            strand.position = [0.14 + dx, -0.265, 0.05]  // 金环下方
            strand.orientation = simd_quatf(angle: dx * 5, axis: [0, 0, 1])  // 微微散开
            tassel.addChild(strand)  // 挂上
        }  // 循环结束
        return tassel  // 返回流苏
    }  // tasselNode 结束

    static func glassesEntity(_ item: OutfitItem) -> Entity {  // 眼镜
        let group = Entity()  // 眼镜整体
        group.position = [0, 0.945, 0.215]  // 眼睛位置
        let frame = UIColor(hex: item.hex)  // 框色
        let lens = UIColor(hex: item.accent)  // 镜片色
        for side in [-1.0, 1.0] {  // 左右镜片
            let glass = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.058),  // 镜片盘
                                    materials: [material(lens)])  // 镜片色
            glass.position = [Float(side) * 0.095, 0, 0.03]  // 对应眼睛
            glass.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 立起来
            group.addChild(glass)  // 挂上
            let rim = ModelEntity(mesh: .generateCylinder(height: 0.008, radius: 0.066),  // 镜圈
                                  materials: [material(frame)])  // 框色
            rim.position = [Float(side) * 0.095, 0, 0.026]  // 镜片后一点
            rim.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 同镜片
            group.addChild(rim)  // 挂上
            let leg = ModelEntity(mesh: .generateCylinder(height: 0.10, radius: 0.005),  // 镜腿
                                  materials: [material(frame)])  // 框色
            leg.position = [Float(side) * 0.155, 0, -0.02]  // 往耳朵方向
            leg.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])  // 横向
            group.addChild(leg)  // 挂上
        }  // 循环结束
        let bridge = ModelEntity(mesh: .generateBox(width: 0.07, height: 0.008, depth: 0.008),  // 鼻梁
                                 materials: [material(frame)])  // 框色
        bridge.position = [0, 0.01, 0.03]  // 两镜片之间
        group.addChild(bridge)  // 挂上
        return group  // 返回眼镜
    }  // glassesEntity 结束

    static func neckEntity(_ item: OutfitItem) -> Entity {  // 围巾或项圈
        let group = Entity()  // 颈部整体
        group.position = [0, 0.70, 0.02]  // 脖子位置（头与身之间）
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id.hasPrefix("neck.scarf") {  // 围巾
            let band = ModelEntity(mesh: .generateCylinder(height: 0.055, radius: 0.165),  // 围一圈
                                   materials: [material(main)])  // 主色
            band.scale = [1, 1, 0.86]  // 前后压薄
            group.addChild(band)  // 挂上
            let hang = ModelEntity(mesh: .generateBox(width: 0.07, height: 0.15, depth: 0.02, cornerRadius: 0.008),  // 垂下一截
                                   materials: [material(main)])  // 主色
            hang.position = [0.055, -0.10, 0.145]  // 胸前
            hang.orientation = simd_quatf(angle: 0.16, axis: [0, 0, 1])  // 稍微歪
            group.addChild(hang)  // 挂上
            let tip = ModelEntity(mesh: .generateBox(width: 0.073, height: 0.02, depth: 0.022, cornerRadius: 0.006),  // 流苏边
                                  materials: [material(accent)])  // 点缀色
            tip.position = [0.068, -0.175, 0.145]  // 垂片末端
            group.addChild(tip)  // 挂上
        } else if item.id == "neck.bell" {  // 铃铛项圈
            let band = ModelEntity(mesh: .generateCylinder(height: 0.032, radius: 0.162),  // 项圈
                                   materials: [material(main)])  // 主色
            band.scale = [1, 1, 0.88]  // 压薄
            group.addChild(band)  // 挂上
            let bell = sphere(radius: 0.04, color: accent)  // 铃铛
            bell.position = [0, -0.035, 0.155]  // 脖子正前
            group.addChild(bell)  // 挂上
            let hole = sphere(radius: 0.011, color: main)  // 铃铛上的孔
            hole.position = [0, -0.05, 0.19]  // 铃铛下方
            group.addChild(hole)  // 挂上
        } else if item.id == "neck.bowtie" {  // 领结
            for side in [-1.0, 1.0] {  // 左右两片
                let wing = ModelEntity(mesh: .generateBox(width: 0.072, height: 0.052, depth: 0.022, cornerRadius: 0.01),  // 一片翅膀
                                       materials: [material(main)])  // 主色
                wing.position = [Float(side) * 0.052, 0, 0.155]  // 分列两侧
                wing.orientation = simd_quatf(angle: Float(side) * 0.35, axis: [0, 1, 0])  // 微微外张
                group.addChild(wing)  // 挂上
            }  // 循环结束
            let knot = ModelEntity(mesh: .generateBox(width: 0.028, height: 0.04, depth: 0.026, cornerRadius: 0.01),  // 结
                                   materials: [material(accent)])  // 点缀色
            knot.position = [0, 0, 0.163]  // 正中
            group.addChild(knot)  // 挂上
        }  // 分支结束
        return group  // 返回颈部配件
    }  // neckEntity 结束

    static func backEntity(_ item: OutfitItem) -> Entity {  // 背包或披风
        let group = Entity()  // 背部整体
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id == "back.backpack" {  // 小书包
            group.position = [0, 0.46, -0.22]  // 背后
            let bag = ModelEntity(mesh: .generateBox(width: 0.20, height: 0.20, depth: 0.11, cornerRadius: 0.03),  // 包体
                                  materials: [material(main)])  // 主色
            group.addChild(bag)  // 挂上
            let flap = ModelEntity(mesh: .generateBox(width: 0.19, height: 0.10, depth: 0.02, cornerRadius: 0.02),  // 翻盖
                                   materials: [material(accent)])  // 点缀色
            flap.position = [0, 0.055, -0.058]  // 背面顶部
            group.addChild(flap)  // 挂上
            for side in [-1.0, 1.0] {  // 两条肩带
                let strap = ModelEntity(mesh: .generateCylinder(height: 0.24, radius: 0.012),  // 带子
                                        materials: [material(accent)])  // 点缀色
                strap.position = [Float(side) * 0.085, 0.0, 0.09]  // 绕到胸前
                strap.orientation = simd_quatf(angle: 0.2, axis: [1, 0, 0])  // 略微前倾
                group.addChild(strap)  // 挂上
            }  // 循环结束
        } else if item.id == "back.cape" {  // 披风
            group.position = [0, 0.66, -0.17]  // 肩后
            let cloth = ModelEntity(mesh: .generateBox(width: 0.34, height: 0.42, depth: 0.014, cornerRadius: 0.02),  // 披风布
                                    materials: [material(main)])  // 主色
            cloth.position = [0, -0.18, 0]  // 向下垂
            cloth.orientation = simd_quatf(angle: -0.18, axis: [1, 0, 0])  // 后摆
            group.addChild(cloth)  // 挂上
            let clasp = sphere(radius: 0.033, color: accent)  // 领扣
            clasp.position = [0, 0.03, 0.03]  // 颈部
            group.addChild(clasp)  // 挂上
        }  // 分支结束
        return group  // 返回背部配件
    }  // backEntity 结束

    // MARK: - 小工具                                                // 分节：工具

    static func furColor(outfit: CatOutfit, accent: Bool) -> UIColor {  // 取毛色
        let id = outfit.id(for: .fur) ?? "fur.orange"  // 当前毛色 id
        let item = catalog.item(id: id)  // 查配件表
        let hex = accent ? (item?.accent ?? "FFF7EE") : (item?.hex ?? "EC9440")  // 主色或点缀色
        return UIColor(hex: hex)  // 转成颜色
    }  // furColor 结束

    static func darken(_ color: UIColor, by amount: CGFloat) -> UIColor {  // 把颜色压暗一档
        var r: CGFloat = 0  // 红分量
        var g: CGFloat = 0  // 绿分量
        var b: CGFloat = 0  // 蓝分量
        var a: CGFloat = 0  // 透明度
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return color }  // 取不到就原样返回
        return UIColor(red: max(0, r - amount), green: max(0, g - amount), blue: max(0, b - amount), alpha: a)  // 三通道同减
    }  // darken 结束

    static func sphere(radius: Float, color: UIColor) -> ModelEntity {  // 造一个球
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)])  // 直接返回
    }  // sphere 结束

    static func material(_ color: UIColor, metallic: Bool = false) -> SimpleMaterial {  // 造一个材质
        SimpleMaterial(color: color, roughness: .float(0.62), isMetallic: metallic)  // 哑光为主，像毛绒
    }  // material 结束
}  // PetSceneBuilder 结束
