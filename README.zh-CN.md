# 蘑菇要塞 Mushroom Garrison

[English](README.md) · **简体中文**

[![Godot CI and Web Deploy](https://github.com/Liangrr/mushroomfort/actions/workflows/godot-web.yml/badge.svg)](https://github.com/Liangrr/mushroomfort/actions/workflows/godot-web.yml)

一款使用 **Godot 4** 开发、支持 Web/H5 导出的手绘风格 2D 塔防游戏。玩家需要沿着森林小径种植会成长的蘑菇炮塔，抵御害虫波次，保护种子仓库。

在线试玩：[https://liangrr.github.io/mushroomfort/](https://liangrr.github.io/mushroomfort/)

GitHub 仓库：[https://github.com/Liangrr/mushroomfort](https://github.com/Liangrr/mushroomfort)

## 游戏特色

| 项目 | 内容 |
| --- | --- |
| 游戏目标 | 阻止害虫抵达种子仓库。每次漏怪会损失生命；首领造成更多损失。根据剩余生命获得 1～3 颗星。 |
| 地图 | 苔藓小径（10 波）、双溪蕨谷（12 波）、月影菌林（15 波）。地图按顺序解锁。 |
| 炮塔 | 孢子菇（范围攻击）、露珠菇（减速）、棘刺菇（穿透）、爆裂菇（溅射，仅攻击地面）。 |
| 升级 | 炮塔先从 1 级升级到 2 级，再选择 A/B 分支，并继续升级两个分支等级。 |
| 敌人 | 啃叶虫、疾跳螨、甲壳虫、暮影蛾、小黏泥、角刺甲王等。包含飞行敌人、分裂敌人和首领。 |
| 操作 | 支持鼠标、键盘、手柄和触摸操作。移动端支持横屏、全屏和触摸按钮适配。 |
| 语言 | 支持简体中文和 English，可根据浏览器语言自动选择，也可在游戏中手动切换。 |

## 炮塔分支

| 炮塔 | 分支 A | 分支 B |
| --- | --- | --- |
| 孢子菇 | 回响菇：孢子环额外回响一次 | 腐霉菇：释放持续伤害并穿透护甲的毒雾 |
| 露珠菇 | 霜铃菇：减速冰霜波并周期性冻结 | 琥珀菇：树液水洼减速并提高受到的伤害 |
| 棘刺菇 | 长矛菇：远距离穿甲狙击 | 连弩菇：快速扇形攻击，适合清理群体 |
| 爆裂菇 | 散花菇：子炸弹造成连锁爆炸 | 巨雷菇：大范围爆炸并击晕敌人 |

## 本地运行

需要安装：

- Godot 4.7.2
- Node.js / npm（用于项目检查和 Web 导出脚本）

在项目根目录执行：

```bash
npm run check
npm run export
```

导出的 Web 文件位于：

```text
build/web/
```

本地启动试玩服务：

```bash
python3 -m http.server 4173 --bind 0.0.0.0 --directory build/web
```

然后访问：

```text
http://127.0.0.1:4173/
```

## 源码结构

```text
scenes/main.tscn                 # Godot 主场景
scripts/main.gd                  # 页面切换和全局弹窗
scripts/core/                    # 游戏数据、存档、输入、语言、版本
scripts/battle/                  # 地图、炮塔、敌人、波次、战斗逻辑
scripts/screens/                 # 标题页、地图选择、设置、帮助
scripts/ui/                      # UI 主题、按钮、移动端布局
assets/mg/                       # 游戏美术和字体资源
data/game/                      # 地图、炮塔、敌人和数值配置
localization/                   # 中英文语言文件
web/loading.html                 # Web 加载页面
project.godot                   # Godot 项目配置
export_presets.cfg              # Web 导出配置
```

## 数据驱动设计

游戏中的主要内容位于 `data/game/`，无需修改核心战斗代码即可调整：

- `balance.json`：全局规则、生命、评分、速度和经济参数
- `towers.json`：炮塔属性、攻击方式、升级分支和文本键
- `enemies.json`：敌人生命、速度、护甲、奖励和特殊能力
- `levels/level_N.json`：地图地形、路径、装饰物和敌人波次

新增或修改数据后，建议运行：

```bash
npm run check
```

## GitHub Actions 自动构建

工作流文件：`.github/workflows/godot-web.yml`

推送到 `main` 分支后，GitHub Actions 会自动：

1. 检查游戏数据和本地化文件
2. 安装 Godot Web 导出模板
3. 生成 `version.json`
4. 导出 Godot Web 版本
5. 上传 Web 构建产物
6. 发布到 GitHub Pages

在线版本信息：

[https://liangrr.github.io/mushroomfort/version.json](https://liangrr.github.io/mushroomfort/version.json)

游戏标题页和设置页会显示版本号、Build 编号以及北京时间构建时间。

## 部署到自己的服务器

Web 导出结果是静态文件，可以部署到 GitHub Pages、Nginx、Apache、Cloudflare Pages、Vercel 或其他静态网站托管服务。

服务器需要正确提供：

- `index.html`
- `index.wasm`
- `index.pck`
- `index.js`
- `version.json`

建议开启 HTTPS，并确保服务器支持 `.wasm` 文件类型。详细说明见 [`DEPLOYMENT.md`](DEPLOYMENT.md)。

## 版权和资源说明

项目中的美术和音频资源为本项目使用的原创或生成资源；字体及第三方资源说明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。使用或二次开发前，请同时遵守仓库中的许可证和资源声明。

## 开发工作流

推荐的修改流程：

```text
修改代码或数据
    ↓
npm run check
    ↓
npm run export
    ↓
本地浏览器预览
    ↓
git commit / git push
    ↓
GitHub Actions 自动构建
    ↓
GitHub Pages 自动发布
```

英文说明：[README.md](README.md)
