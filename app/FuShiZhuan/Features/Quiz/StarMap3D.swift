//  StarMap3D.swift —— 闯关地图的 3D 星海（RealityKit）                      // 文件说明
//  逐条移植样板 public/js/game3d.js：4 座知识岛 = 4 章，每岛 3 颗水晶 = 3 关。  // 移植来源
//  交互：左右拖动转视角（样板 rotY 夹在 ±0.55），点水晶进关。                // 交互说明
//  水晶三态照样板 paint：已通关金 / 可打本色 / 未解锁同色系暗版。            // 状态说明
//  三处如实降级，均不改交互：① 样板光晕用 WebGL 的 Sprite 加叠加混合，        // 降级说明
//     RealityKit 没有叠加混合，改用半透明扁球；② 样板用 TubeGeometry 画岛面   // 降级说明
//     轨迹，这里用一串小球连成虚线；③ 样板把「1-1」做成 DOM 浮层跟随相机投影， // 降级说明
//     iOS 这边没有可靠的静态相机投影接口，编号改放场景下方的胶囊行。         // 降级说明

import RealityKit  // 3D 引擎
import SwiftUI  // 界面框架
import UIKit  // UIColor 与手势

// MARK: - 常量                                                          // 分节：常量

enum StarMapPalette {  // 与样板同一套色
    static let dust = UIColor(hex: "CFD9FF")  // 星尘淡蓝
    static let passed = UIColor(hex: "FFC247")  // 已通关金
    static let lockedCore = UIColor(hex: "B9C2D4")  // 锁定态内核灰
    static let white = UIColor(hex: "FFFFFF")  // 内核白
}  // StarMapPalette 结束

enum StarMapLayout {  // 样板布局常量，逐条照抄 game3d.js
    static let islandGap: Float = 1.12  // ISLAND_GAP 岛与岛的纵向间距
    static let islandTopY: Float = 1.3  // ISLAND_TOP_Y 第一座岛的高度
    static let islandR: Float = 1.46  // ISLAND_R 岛盘半径
    static let nodeX: [Float] = [-1.06, 0, 1.06]  // NODE_X 每岛三颗水晶的横向位置
    static let zStep: Float = -0.4  // Z_STEP 每往后一座稍微退远
    static let fov: Float = 46  // 样板 camera.fov
    static let cameraY: Float = 2.15  // 视觉改良：样板 1.0 几乎与顶层岛同高，四座岛被压成一摞扁盘；抬到 2.15 才有俯角看清水晶
    static let look = SIMD3<Float>(0, -0.5, 0)  // 视觉改良：样板 (0,-0.34,0)，跟着相机一起下压，视线更居中
    static let fitHeight: Float = 4.95  // 样板 resize：纵向要装下 4.95
    static let fitWidth: Float = 4.4  // 样板 resize：横向要装下 4.4
    static let dragLimit: Float = 0.55  // 样板 clamp 的左右极限
    static let dragGain: Float = 0.0038  // 样板 dx 换算成弧度的系数
}  // StarMapLayout 结束

enum StarCrystalState {  // 水晶三态，照样板 paint 的判断
    case passed  // 已通关，金
    case open  // 现在能打，本色
    case locked  // 还没解锁，暗
}  // StarCrystalState 结束

// MARK: - 运行时节点                                                     // 分节：节点

struct CrystalNode {  // 一颗水晶的运行时引用
    let id: String  // 关卡 id，例如 tax-system-1
    let group: Entity  // 浮动容器，上下浮动用它
    let gem: Entity  // 宝石本体，自转用
    let ring: Entity  // 能量环，自转速度随状态变
    let pulse: Entity?  // 地面涟漪，只有可打的关卡才有
    let baseY: Float  // 浮动的基准高度
    let phase: Float  // 相位，让 12 颗错开节奏
    let state: StarCrystalState  // 当前状态
}  // CrystalNode 结束

struct IslandNode {  // 一座岛的运行时引用
    let group: Entity  // 岛整组
    let baseY: Float  // 浮动基准高度
    let phase: Float  // 相位
    let debris: [DebrisNode]  // 环岛碎块
}  // IslandNode 结束

struct DebrisNode {  // 一块环岛碎块
    let entity: Entity  // 实体
    let angle: Float  // 初始角度
    let radius: Float  // 轨道半径
    let speed: Float  // 角速度
}  // DebrisNode 结束

// MARK: - 建模                                                          // 分节：建模

enum StarMapBuilder {  // 星海建模器

    static let crystalPrefix = "star.crystal."  // 水晶节点名前缀，点中后按它取关卡 id

    /// 算每关状态：第一关默认开，之后要看前一关有没有星（样板 game.js 的解锁规则）
    static func states(stars: [String: Int]) -> [String: StarCrystalState] {  // 状态表
        var out: [String: StarCrystalState] = [:]  // 结果
        let order = SortCatalog.order  // 全部关卡 id 的先后顺序
        for (index, id) in order.enumerated() {  // 逐关
            let star = stars[id] ?? 0  // 这一关拿了几颗星
            let unlocked = index == 0 || (stars[order[index - 1]] ?? 0) > 0  // 第一关默认开，其余看前一关
            out[id] = star > 0 ? .passed : (unlocked ? .open : .locked)  // 三态归位
        }  // 循环结束
        return out  // 返回
    }  // states 结束

    /// 搭一整片星海：岛 + 水晶 + 星尘
    static func build(stars: [String: Int]) -> (root: Entity, crystals: [CrystalNode], islands: [IslandNode]) {  // 搭场景
        let root = Entity()  // 根节点
        let stateMap = states(stars: stars)  // 先算状态
        var crystals: [CrystalNode] = []  // 水晶收集
        var islands: [IslandNode] = []  // 岛收集

        for (ci, chapter) in SortCatalog.chapters.enumerated() {  // 逐章 = 逐岛
            let baseY = StarMapLayout.islandTopY - Float(ci) * StarMapLayout.islandGap  // 样板 baseY 公式
            let z = Float(ci) * StarMapLayout.zStep  // 样板景深
            let tint = UIColor(hex: chapter.color)  // 章节主题色
            let island = makeIsland(tint: tint, baseY: baseY, z: z, index: ci)  // 造岛
            root.addChild(island.group)  // 挂上
            islands.append(island)  // 记下

            for (ni, nx) in StarMapLayout.nodeX.enumerated() {  // 每岛三颗水晶
                let id = "\(chapter.id)-\(ni + 1)"  // 关卡 id
                let state = stateMap[id] ?? .locked  // 取状态
                let node = makeCrystal(id: id, tint: tint, state: state)  // 造水晶
                let y = baseY + 0.3  // 样板 group.position.y
                let cz = z + 0.34 - Float(ni) * 0.34  // 样板 z 错位，近大远小看得清
                node.group.position = [nx, y, cz]  // 摆到位
                node.group.generateCollisionShapes(recursive: true)  // 加碰撞才点得到
                root.addChild(node.group)  // 挂上
                crystals.append(CrystalNode(id: id,  // 记下引用
                                            group: node.group,  // 浮动容器
                                            gem: node.gem,  // 自转宝石
                                            ring: node.ring,  // 能量环
                                            pulse: node.pulse,  // 涟漪容器
                                            baseY: baseY + 0.46,  // 样板 baseY 比摆放高度高 0.46
                                            phase: Float(ci) * 1.3 + Float(ni) * 0.9,  // 与水晶相位一致
                                            state: state))  // 状态
            }  // 循环结束
        }  // 循环结束
        root.addChild(makeDust())  // 星尘
        return (root: root, crystals: crystals, islands: islands)  // 返回
    }  // build 结束

    static func makeIsland(tint: UIColor, baseY: Float, z: Float, index: Int) -> IslandNode {  // 一座岛
        let group = Entity()  // 岛整组
        let r = StarMapLayout.islandR  // 半径

        let disc = ModelEntity(mesh: .generateCylinder(height: 0.2, radius: r),  // 盘体是薄圆柱
                               materials: [material(UIColor(white: 1, alpha: 0.16), roughness: 0.2)])  // 半透明玻璃感
        group.addChild(disc)  // 挂上

        for i in 0..<28 {  // 上沿发光圈：样板是 TorusGeometry，这里用 28 颗小球串出来
            let a = Float(i) / 28 * .pi * 2  // 均分一圈
            let dot = ModelEntity(mesh: .generateSphere(radius: 0.022), materials: [material(tint, roughness: 0.4)])  // 一颗光点
            dot.position = [cos(a) * r, 0.07, sin(a) * r]  // 落在圆周上，高度同样板
            group.addChild(dot)  // 挂上
        }  // 循环结束

        let trackPoints: [SIMD3<Float>] = [  // 样板 CatmullRomCurve3 的五个控制点
            [-1.34, 0, 0.02],  // 左端
            [-0.6, 0, 0.1],  // 左中
            [0, 0, 0.14],  // 中间
            [0.6, 0, 0.1],  // 右中
            [1.34, 0, 0.02]  // 右端
        ]  // 数组结束
        for seg in 0..<(trackPoints.count - 1) {  // 逐段插值，连成虚线轨迹
            for step in 0...4 {  // 每段四份
                let t = Float(step) / 4  // 0 到 1
                let p = trackPoints[seg] + (trackPoints[seg + 1] - trackPoints[seg]) * t  // 线性插值
                let bead = ModelEntity(mesh: .generateSphere(radius: 0.016), materials: [material(tint, roughness: 0.5)])  // 一颗小珠
                bead.position = [p.x, 0.115, p.z]  // 样板 track.position.y
                group.addChild(bead)  // 挂上
            }  // 内层循环结束
        }  // 外层循环结束

        let halo = ModelEntity(mesh: .generateSphere(radius: 1),  // 岛底光晕：扁球代替 Sprite
                               materials: [material(tint.withAlphaComponent(0.3), roughness: 0.6)])  // 淡主题色
        halo.scale = [r * 1.55, r * 0.3, r * 0.75]  // 压扁铺在盘下，同样板 3.1 × 1.5 的比例
        halo.position = [0, -0.02, 0]  // 样板 halo.position.y
        group.addChild(halo)  // 挂上

        var debris: [DebrisNode] = []  // 环岛碎块
        for i in 0..<5 {  // 五块
            let a = Float(i) / 5 * .pi * 2 + Float(index) * 0.6  // 样板角度分布
            let rr = r * (1.12 + Float(i % 3) * 0.1)  // 轨道半径
            let chunk = ModelEntity(mesh: .generateSphere(radius: 0.062), materials: [material(tint, roughness: 0.4)])  // 一块碎石
            chunk.position = [cos(a) * rr, -0.16 - Float(i % 2) * 0.06, sin(a) * rr * 0.5]  // 样板同位置
            group.addChild(chunk)  // 挂上
            debris.append(DebrisNode(entity: chunk, angle: a, radius: rr, speed: 0.12 + Float(i) * 0.02))  // 记下，逐帧绕圈
        }  // 循环结束

        group.position = [0, baseY, z]  // 整座岛摆到样板位置
        return IslandNode(group: group, baseY: baseY, phase: Float(index) * 1.2, debris: debris)  // 返回
    }  // makeIsland 结束

    static func makeCrystal(id: String, tint: UIColor, state: StarCrystalState) -> (group: Entity, gem: Entity, ring: Entity, pulse: Entity?) {  // 一颗水晶
        let group = Entity()  // 浮动容器
        group.name = crystalPrefix + id  // 命名，点中后据此取关卡 id
        let color = tintOf(state: state, tint: tint)  // 按状态取颜色

        let gem = Entity()  // 宝石本体（两块圆锥拼成八面体，样板用的是 Icosahedron）
        let up = ModelEntity(mesh: .generateCone(height: 0.26, radius: 0.235), materials: [material(color, roughness: 0.22)])  // 上半锥
        up.position = [0, 0.13, 0]  // 抬到赤道以上
        gem.addChild(up)  // 挂上
        let down = ModelEntity(mesh: .generateCone(height: 0.26, radius: 0.235), materials: [material(color, roughness: 0.22)])  // 下半锥
        down.position = [0, -0.13, 0]  // 落到赤道以下
        down.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])  // 翻过来，锥尖朝下
        gem.addChild(down)  // 挂上
        group.addChild(gem)  // 挂上

        let core = ModelEntity(mesh: .generateSphere(radius: 0.1),  // 内核小球，做出「里面有光」
                               materials: [material(state == .locked ? StarMapPalette.lockedCore : StarMapPalette.white, roughness: 0.3)])  // 锁定态内核转灰
        core.scale = [1, 1, 1]  // 保持球体
        group.addChild(core)  // 挂上

        let ring = Entity()  // 能量环：样板 TorusGeometry，这里用 18 颗小球
        ring.orientation = simd_quatf(angle: .pi / 2.35, axis: [1, 0, 0])  // 样板 ring.rotation.x
        for i in 0..<18 {  // 一圈
            let a = Float(i) / 18 * .pi * 2  // 均分
            let bead = ModelEntity(mesh: .generateSphere(radius: 0.011), materials: [material(color, roughness: 0.3)])  // 一颗
            bead.position = [cos(a) * 0.47, sin(a) * 0.47, 0]  // 半径同样板 0.47
            ring.addChild(bead)  // 挂上
        }  // 循环结束
        group.addChild(ring)  // 挂上

        let halo = ModelEntity(mesh: .generateSphere(radius: 0.55),  // 光晕
                               materials: [material(color.withAlphaComponent(state == .locked ? 0.06 : 0.32), roughness: 0.6)])  // 锁定态几乎看不见
        halo.scale = [1, 1, 1]  // 保持球形
        group.addChild(halo)  // 挂上

        let foot = ModelEntity(mesh: .generateSphere(radius: 0.5),  // 底座光点，告诉你这里能点
                               materials: [material(color.withAlphaComponent(state == .locked ? 0.05 : 0.3), roughness: 0.6)])  // 淡
        foot.scale = [0.72, 0.14, 0.72]  // 压成一块光斑
        foot.position = [0, -0.42, 0]  // 样板 foot.position.y
        group.addChild(foot)  // 挂上

        var pulseEntity: Entity?  // 地面涟漪容器，只有可打的关卡才建
        if state == .open {  // 只有现在能打的关卡才有涟漪
            let pulseRing = Entity()  // 一圈小球
            pulseRing.name = "pulse"  // 命名，逐帧要整体缩放
            for i in 0..<12 {  // 一圈小球，逐帧放大做扩散
                let a = Float(i) / 12 * .pi * 2  // 均分
                let bead = ModelEntity(mesh: .generateSphere(radius: 0.02),  // 涟漪点
                                       materials: [material(color.withAlphaComponent(0.5), roughness: 0.4)])  // 半透明
                bead.position = [cos(a) * 0.42, -0.44, sin(a) * 0.42]  // 样板半径 0.4 到 0.44，贴在地面高度
                pulseRing.addChild(bead)  // 挂上
            }  // 循环结束
            group.addChild(pulseRing)  // 挂上
            pulseEntity = pulseRing  // 记下来给帧循环用
        }  // 分支结束

        group.scale = [1, 1, 1]  // 初始比例
        return (group: group, gem: gem, ring: ring, pulse: pulseEntity)  // 返回
    }  // makeCrystal 结束

    static func makeDust() -> Entity {  // 星尘
        let group = Entity()  // 一组星尘
        group.name = "star.dust"  // 命名，帧循环里要整体慢转
        var seed: UInt64 = 20261103  // 固定种子，保证每次布局一样
        func rand() -> Float {  // 线性同余伪随机，免得每帧位置乱跳
            seed = seed &* 6364136223846793005 &+ 1442695040888963407  // 推进种子
            return Float((seed >> 33) % 10000) / 10000  // 归到 0 到 1
        }  // rand 结束
        for _ in 0..<110 {  // 一百一十颗，样板是 520 个点，这里球太贵只能减量
            let dot = ModelEntity(mesh: .generateSphere(radius: 0.014),  // 一颗星尘
                                  materials: [material(StarMapPalette.dust.withAlphaComponent(0.65), roughness: 0.5)])  // 淡蓝半透明
            dot.position = [(rand() - 0.5) * 16, (rand() - 0.5) * 12, (rand() - 0.5) * 9 - 2]  // 样板同范围
            group.addChild(dot)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // makeDust 结束

    static func tintOf(state: StarCrystalState, tint: UIColor) -> UIColor {  // 按状态取色
        switch state {  // 分支
        case .passed: StarMapPalette.passed  // 通关金
        case .open: tint  // 本色
        case .locked: dim(tint)  // 同色系暗版，比灰石头好看
        }  // 分支结束
    }  // tintOf 结束

    static func dim(_ color: UIColor) -> UIColor {  // 把颜色压到 0.42 倍，同样板 multiplyScalar
        var r: CGFloat = 0  // 红
        var g: CGFloat = 0  // 绿
        var b: CGFloat = 0  // 蓝
        var a: CGFloat = 0  // 透明度
        color.getRed(&r, green: &g, blue: &b, alpha: &a)  // 取出分量
        return UIColor(red: r * 0.42, green: g * 0.42, blue: b * 0.42, alpha: a)  // 压暗
    }  // dim 结束

    static func material(_ color: UIColor, roughness: Float) -> SimpleMaterial {  // 统一材质
        SimpleMaterial(color: color, roughness: .float(roughness), isMetallic: false)  // 哑光，颜色里的 alpha 就是透明度
    }  // material 结束
}  // StarMapBuilder 结束

// MARK: - 相机                                                            // 分节：相机

enum StarMapCamera {  // 相机摆放，照样板 resize 与 loop

    static func distance(aspect: Float) -> Float {  // 让 4 座岛刚好落进画面
        let half = StarMapLayout.fov / 2 * .pi / 180  // 半视角转弧度
        let tanHalf = tan(half)  // 半视角正切
        let distV = (StarMapLayout.fitHeight / 2) / tanHalf  // 纵向要装下的距离
        let distH = (StarMapLayout.fitWidth / 2) / (tanHalf * max(0.2, aspect))  // 横向要装下的距离
        return max(distV, distH) * 1.02  // 取大的再留 2 个百分点，同样板
    }  // distance 结束

    static func place(on holder: Entity, angle: Float, dist: Float, time: Float) {  // 摆相机
        let eyeY = StarMapLayout.cameraY + sin(time * 0.5) * 0.015  // 样板相机上下微呼吸
        let eye = SIMD3<Float>(sin(angle) * dist, eyeY, cos(angle) * dist)  // 绕原点转
        let forward = simd_normalize(StarMapLayout.look - eye)  // 看向样板 lookAt
        holder.position = eye  // 放到眼睛位置
        holder.orientation = simd_quatf(from: [0, 0, -1], to: forward)  // 把相机 -Z 对齐视线
    }  // place 结束
}  // StarMapCamera 结束

// MARK: - 视图入口                                                       // 分节：视图

/// 3D 星海关卡地图。点水晶回调关卡 id
struct StarMap3DView: UIViewRepresentable {  // 星海

    let stars: [String: Int]  // 各关星数，决定三态
    var animationsOff: Bool  // 省电：只摆不动
    let onPick: (String) -> Void  // 点中水晶的回报

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }  // 建协调器

    func makeUIView(context: Context) -> ARView {  // 建场景
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)  // 不启用相机
        view.environment.background = .color(UIColor(hex: "0B1024"))  // 深空底色
        view.renderOptions.insert(.disableMotionBlur)  // 关动态模糊，水晶棱角更干净
        view.isUserInteractionEnabled = true  // 要能拖能点

        let camera = PerspectiveCamera()  // 相机实体
        camera.camera.fieldOfViewInDegrees = StarMapLayout.fov  // 样板 fov
        camera.camera.near = 0.1  // 样板近平面
        camera.camera.far = 100  // 样板远平面
        let holder = AnchorEntity(world: [0, StarMapLayout.cameraY, 6])  // 相机锚点
        holder.addChild(camera)  // 挂上相机
        view.scene.addAnchor(holder)  // 入场

        let content = AnchorEntity(world: [0, 0, 0])  // 内容锚点单独一个，避免和相机抢第一个 anchor
        view.scene.addAnchor(content)  // 入场
        let built = StarMapBuilder.build(stars: stars)  // 搭星海
        content.addChild(built.root)  // 挂上

        context.coordinator.view = view  // 存视图
        context.coordinator.holder = holder  // 存相机锚点
        context.coordinator.root = built.root  // 存根节点
        context.coordinator.crystals = built.crystals  // 存水晶
        context.coordinator.islands = built.islands  // 存岛
        context.coordinator.dust = built.root.children.first { $0.name == "star.dust" }  // 存星尘

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))  // 拖动转视角
        view.addGestureRecognizer(pan)  // 挂上
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))  // 点水晶
        tap.require(toFail: pan)  // 拖过就不算点击，同样板 moved 判断
        view.addGestureRecognizer(tap)  // 挂上

        if !animationsOff { context.coordinator.startTicking() }  // 省电模式下不动
        StarMapCamera.place(on: holder, angle: 0, dist: 5.95, time: 0)  // 先摆一次，避免首帧在原点
        return view  // 返回
    }  // makeUIView 结束

    func updateUIView(_ view: ARView, context: Context) {  // 状态变化时
        context.coordinator.onPick = onPick  // 更新回调
        context.coordinator.applyAspect(view: view)  // 尺寸变了就重算相机距离
    }  // updateUIView 结束

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {  // 离场清理
        coordinator.stopTicking()  // 停帧循环，别让定时器活着
    }  // dismantleUIView 结束

    final class Coordinator: NSObject {  // 协调器
        weak var view: ARView?  // 场景视图
        var holder: AnchorEntity?  // 相机锚点
        var root: Entity?  // 星海根节点
        var crystals: [CrystalNode] = []  // 水晶
        var islands: [IslandNode] = []  // 岛
        var dust: Entity?  // 星尘整组，逐帧慢转
        var onPick: (String) -> Void  // 点中回调
        private var timer: Timer?  // 帧循环
        private var elapsed: Float = 0  // 已累计秒数
        private var distance: Float = 5.95  // 相机到原点的距离
        private var rotY: Float = 0  // 当前角度
        private var rotTarget: Float = 0  // 拖动目标角度
        private var panStart: Float = 0  // 按下时的角度
        private var dragged = false  // 这次手势是不是拖动

        init(onPick: @escaping (String) -> Void) {  // 构造
            self.onPick = onPick  // 存回调
        }  // init 结束

        func applyAspect(view: ARView) {  // 按视图比例重算距离
            let w = Float(view.bounds.width)  // 宽
            let h = Float(view.bounds.height)  // 高
            guard w > 1, h > 1 else { return }  // 还没布局就算了
            distance = StarMapCamera.distance(aspect: w / h)  // 样板 resize 的公式
        }  // applyAspect 结束

        func startTicking() {  // 开始逐帧
            guard timer == nil else { return }  // 已经在跑
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in  // 30 帧够用
                self?.tick()  // 走一帧
            }  // 定时器结束
        }  // startTicking 结束

        func stopTicking() {  // 停止逐帧
            timer?.invalidate()  // 停掉
            timer = nil  // 清引用
        }  // stopTicking 结束

        private func tick() {  // 一帧
            elapsed += 1.0 / 30.0  // 累计时间
            let t = elapsed  // 短名字
            if let view { applyAspect(view: view) }  // 旋屏时也要跟上

            rotY += (rotTarget - rotY) * 0.12  // 样板同样的平滑系数
            let breathe = sin(t * 0.42) * 0.022  // 待机时轻微呼吸
            if let holder { StarMapCamera.place(on: holder, angle: rotY + breathe, dist: distance, time: t) }  // 摆相机

            for c in crystals {  // 逐颗水晶
                c.group.position.y = c.baseY + sin(t * 1.25 + c.phase) * 0.055  // 上下浮动，同样板幅度
                let spin: Float = c.state == .passed ? 1.5 : 0.85  // 通关的转得快；必须显式写 Float，否则被推断成 Double
                c.gem.orientation = simd_quatf(angle: t * spin + c.phase, axis: [0, 1, 0])  // 自转
                let tilt = sin(t * 0.7 + c.phase) * 0.12  // 轻微点头
                c.gem.orientation = simd_quatf(angle: tilt, axis: [1, 0, 0]) * c.gem.orientation  // 叠加上去
                let ringSpin: Float = c.state == .locked ? 0.15 : 0.8  // 锁定的转得慢；同样必须显式 Float
                c.ring.orientation = simd_quatf(angle: -t * ringSpin + c.phase, axis: [0, 0, 1])  // 能量环自转
                if c.state == .open {  // 可打的关卡加一点呼吸感
                    let pulse = 1 + sin(t * 2.6 + c.phase) * 0.07  // 样板 pulse 幅度
                    c.group.scale = [pulse, pulse, pulse]  // 整体缩一点
                    let k = (t * 0.62 + c.phase * 0.31).truncatingRemainder(dividingBy: 1)  // 样板涟漪 0 到 1 的循环
                    let spread = 0.58 + k * 1.2  // 由小到大扩散
                    c.pulse?.scale = [spread, 1, spread]  // 只放大水平方向，像贴地的一圈波纹
                }  // 分支结束
            }  // 循环结束

            for (i, isle) in islands.enumerated() {  // 逐岛
                isle.group.position.y = isle.baseY + sin(t * 0.62 + Float(i) * 1.2) * 0.028  // 整岛轻微浮动
                for d in isle.debris {  // 每块碎块绕圈
                    let a = d.angle + t * d.speed  // 当前角度
                    d.entity.position = [cos(a) * d.radius, d.entity.position.y, sin(a) * d.radius * 0.5]  // 椭圆轨道，同样板
                    d.entity.orientation = simd_quatf(angle: t * 0.5, axis: [0, 1, 0])  // 自转
                }  // 循环结束
            }  // 循环结束

            dust?.orientation = simd_quatf(angle: t * 0.012, axis: [0, 1, 0])  // 星尘极慢转，样板 y 轴 0.012 弧度每秒
            dust?.position.y = sin(t * 0.2) * 0.16  // 星尘整片轻微上下漂
        }  // tick 结束
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {  // 拖动转视角
            guard let view else { return }  // 没视图就算了
            switch gesture.state {  // 按手势阶段
            case .began:  // 按下
                panStart = rotTarget  // 记下起点角度
                dragged = false  // 还没拖动
            case .changed:  // 拖动中
                let dx = Float(gesture.translation(in: view).x)  // 水平位移
                if abs(dx) > 6 { dragged = true }  // 超过 6 点就算拖动，同样板判断
                rotTarget = min(StarMapLayout.dragLimit, max(-StarMapLayout.dragLimit, panStart + dx * StarMapLayout.dragGain))  // 夹在 ±0.55
            default:  // 抬手或取消
                break  // 什么都不做
            }  // 分支结束
        }  // handlePan 结束

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {  // 点水晶
            guard let view, !dragged else { return }  // 拖动过就不算点击
            let point = gesture.location(in: view)  // 点在哪
            let hits = view.hitTest(point, query: .all, mask: .all)  // 所有命中，由近到远
            for hit in hits {  // 由近到远找
                var node: Entity? = hit.entity  // 从命中的实体往上找
                while let current = node {  // 逐层向上
                    if current.name.hasPrefix(StarMapBuilder.crystalPrefix) {  // 命中了水晶
                        let id = current.name.replacingOccurrences(of: StarMapBuilder.crystalPrefix, with: "")  // 取关卡 id
                        onPick(id)  // 回报给页面
                        return  // 结束
                    }  // 分支结束
                    node = current.parent  // 继续往上
                }  // 循环结束
            }  // 循环结束
        }  // handleTap 结束
    }  // Coordinator 结束
}  // StarMap3DView 结束
