# 蘑菇要塞：源码、运行与部署

## 1. 源码在哪里

本项目目录就是完整 Godot 工程：

```text
/home/ubuntu/mushroomfort/
```

主要入口和目录：

- `project.godot`：Godot 项目配置，主场景为 `scenes/main.tscn`
- `scenes/main.tscn`：游戏主入口场景
- `scripts/`：主流程、塔防战斗、炮塔、敌人、投射物、UI、设置与本地化逻辑
- `data/game/`：游戏数据
  - `balance.json`：经济、生命、波次和评分等平衡参数
  - `towers.json`：四种炮塔、等级和两条分支升级
  - `enemies.json`：敌人属性
  - `levels/level_1.json` 到 `level_3.json`：三张地图、路径和波次
- `assets/mg/`：蘑菇炮塔、敌人、地图、UI、音频等发布版资源
- `localization/en.json`、`localization/zh.json`：英文和简体中文
- `export_presets.cfg`：Godot Web 导出预设
- `data/version.json`：本地开发版版本元数据；正式 Web 构建时由 GitHub Actions 自动写入提交号、构建号和时间
- `web/loading.html`：Web 加载页
- `tests/`、`tools/`：数据检查、自动战斗和原生运行辅助脚本
- `THIRD_PARTY_NOTICES.md`：开源/资源声明

本次下载的原始 ZIP 和解压参考副本也保存在：

```text
/home/ubuntu/mushroomfort/.import/mushroom-garrison-source.zip
/home/ubuntu/mushroomfort/.import/source/mushgarr/
```

`.import/` 是本地参考目录，不会被打进游戏发布包。

### 游戏版本信息

标题页左下角显示当前版本、渠道和短提交号；设置面板会显示完整构建信息。正式 Web 发布后，构建目录根部还会提供：

```text
https://liangrr.github.io/mushroomfort/version.json
```

该文件由 GitHub Actions 在每次 `main` 分支构建时自动生成，不需要手动修改。

## 2. 直接用 Godot 本地运行

要求：

- Godot **4.7.2** 或兼容的 Godot 4.x 版本；本项目已用 4.7.2 验证
- 桌面系统可运行 Godot 的图形环境
- 不需要数据库、后端服务或 API Key；这是离线单机游戏

在项目根目录执行：

```bash
cd /home/ubuntu/mushroomfort
/usr/local/bin/godot --path .
```

也可以用 Godot 编辑器打开 `/home/ubuntu/mushroomfort/project.godot`，然后运行项目（F6/F5）。

## 3. 检查源码

项目提供了数据合同和启动检查：

```bash
cd /home/ubuntu/mushroomfort
export GAME_RUNTIME=/home/ubuntu/.manus-addons/manus-webdev-sha-bd2f870379e4adc3/runtime/game-dev
npm run check
```

当前已验证通过。检查会验证资源导入、主入口、字体绑定及游戏数据合同。

如修改了数据、地图、炮塔或敌人，可额外运行：

```bash
./tools/run_godot_test.sh tests/mg_checks.gd
./tools/run_godot_test.sh tests/mg_autoplay.gd -- balanced
```

## 4. 导出 Web 版本

Web 导出不需要后端。导出命令：

```bash
cd /home/ubuntu/mushroomfort
export GODOT_BIN=/usr/local/bin/godot
npm run export
```

输出目录：

```text
build/web/
```

已验证会生成 `index.html`、`index.wasm`、`index.pck`、`index.js` 和音频工作线程文件，总体约 57 MB（实际大小会随资源变化）。Web 版本包含手机横屏布局、浏览器安全区处理和触摸热区放大；桌面布局与玩法不变。

## 5. 本地预览 Web 版本

不要用 `file://` 直接双击 `index.html`，请用 HTTP 静态服务器：

```bash
cd /home/ubuntu/mushroomfort
python3 -m http.server 8080 --directory build/web
```

然后访问：

```text
http://127.0.0.1:8080/
```

## 6. 自己部署到服务器

这是一个**纯静态 Web 游戏**，不需要 Node 后端、数据库、Redis、Docker 或游戏服务器。把 `build/web/` 整个目录上传到任意静态网站托管即可，例如 Nginx、Caddy、对象存储静态网站、CDN、GitHub Pages、Cloudflare Pages 或其他静态托管平台。

### Nginx 示例

```nginx
server {
    listen 80;
    server_name game.example.com;
    root /var/www/mushroomfort/build/web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.wasm$ {
        default_type application/wasm;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location ~* \.(js|pck|png|jpg|ogg|woff2)$ {
        add_header Cache-Control "public, max-age=31536000, immutable";
    }
}
```

生产环境建议再加 HTTPS。当前 Web 导出关闭线程支持，因此不要求额外的跨源隔离头；如果后续打开线程或接入第三方功能，再按新配置补充响应头。

### 服务器/托管配置要求

- 静态文件空间：至少预留 **100 MB**，建议 200 MB 以上
- 带宽：首次加载约 57 MB，建议启用 Brotli 或 gzip
- HTTPS：生产环境推荐，尤其是自定义域名和移动浏览器访问
- MIME 类型：`.wasm` 应返回 `application/wasm`
- 路由回退：未知路径回退到 `index.html`（如果托管平台需要）
- 不需要开放入站端口给游戏逻辑；只需托管平台的 HTTP/HTTPS 端口
- 不需要环境变量、数据库、登录、排行榜或支付配置

### 实际硬件建议

- 构建机：2 核 CPU、4 GB 内存即可进行普通导出；图形预览需要桌面环境
- 静态服务器：低流量下 1 vCPU、512 MB 内存通常足够，因为只提供文件
- 玩家设备：现代桌面浏览器，以及支持 WebGL 的 Android Chrome / iOS Safari 横屏浏览器；低端移动设备的性能仍取决于浏览器和图形能力
- 移动端交互：按钮和建造环使用至少约 56px 的触摸热区，战斗底部建造栏与波次控制在小屏横屏时自动加高
- 移动端建议：使用 HTTPS、横屏访问，并优先测试 Android Chrome、iOS Safari 和微信内置浏览器的音频解锁行为

## 7. 修改与重新部署

1. 修改 `scripts/` 或 `data/game/`。
2. 执行 `npm run check`。
3. 执行 `npm run export`。
4. 用新生成的 `build/web/` 覆盖服务器上的旧目录。
5. 如使用 CDN，清理或刷新 `index.html` 的缓存；带哈希或版本化资源策略的平台通常只需刷新入口页。

## 8. 许可证与源码边界

源码包中包含 `THIRD_PARTY_NOTICES.md`、`asset-provenance.json` 和 `assets.lock.json`。自行部署或二次修改时请保留这些声明文件，并自行确认你计划使用的域名、CDN 和第三方托管平台符合其条款。
