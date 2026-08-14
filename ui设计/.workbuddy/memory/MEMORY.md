# 项目长期备忘

## 真实项目：DSH Remote（重点）
- 路径：/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/
- 已有 UI 设计规范 v0.3：docs/ui-design-spec.md（iOS 17+ SwiftUI 原生、系统色 accent #0A84FF、SF Symbols、8pt 栅格、深浅双模式、基调"专业可信克制"）
- 核心设计决策：审批/目标/任务不是独立页面，而是会话详情内的紧凑组件；发送分排队/插话两模式
- 做正式 UI 工作必须先对齐该规范，勿沿用探索稿的自定义风格

## 概念探索：「掌中鲸 / PocketWhale」（本工作区）
- 用途：DeepSeek Harness 手机端伴生 App 的品牌概念探索（与 DSH Remote 是同一产品的不同方向/阶段）
- 设计系统：潮汐蓝 #0EA5E9 + 浪花青 #22D3EE 渐变、珊瑚 #FF6B57、海藻绿 #10B981、墨蓝 #0B1E33
- 注意：第三方客户端，正式名称避免直接用 "DeepSeek" 商标；"Harness Go" 也有商标冲突（Harness Inc.），避开 Harness 字样
- 域名已定：**aicetus.cn**（AI + Cetus 鲸鱼座，用户已注册，2026-08-14）
- Logo 定稿 v6（design/icon-set-v6/）：皇家蓝 #2563EB 纯色 + 白底，破屏鲸；iOS=撞穿手机框、Mac=压出完整 MacBook 屏，已做包围盒居中校验
- 产出：iOS 4 屏 + Mac 服务端设计稿（design/*.html）；Logo v2 蓝青渐变鲸鱼（design/icon-set/，14 种尺寸；清洗脚本 design/crop_icon.py，alpha 反演法）
