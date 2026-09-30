# GitHub Actions 自动构建与 Web 发布

本项目已配置 `.github/workflows/godot-web.yml`。

## 自动执行规则

| 触发方式 | 执行内容 |
|---|---|
| Pull Request | Godot 数据/本地化检查 + Web 构建检查，不发布线上页面 |
| 推送到 `main` | 检查、导出 Web、上传构建产物，并发布 GitHub Pages |
| 手动 `Run workflow` | 执行同样的构建和发布流程 |

使用的 Godot CI 镜像固定为 `barichello/godot-ci:4.7.2`，与本项目本地验证版本一致。

## 第一次启用 Pages

打开仓库的 **Settings → Pages**，将 **Source** 设为 **GitHub Actions**。之后每次推送 `main` 都会自动发布。

仓库地址：<https://github.com/Liangrr/mushroomfort>

发布完成后，在仓库的 **Actions → Godot CI and Web Deploy → Deploy Web to GitHub Pages** 任务中可以看到最终地址。通常地址形如：

```text
https://liangrr.github.io/mushroomfort/
```

## 构建产物

每次构建还会上传一个可下载的 Actions Artifact，名字类似：

```text
mushroomfort-web-<commit-sha>
```

它包含完整的 `build/web/` 内容，可下载后部署到 Nginx、对象存储、CDN 或其他静态托管服务。

## 本地复现 CI

```bash
cd mushroomfort
./tools/run_godot_test.sh tests/mg_checks.gd
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

## 权限说明

工作流使用：

- `contents: read`：读取仓库代码
- `pages: write`：上传/发布 Pages 内容
- `id-token: write`：让 GitHub Pages 验证部署身份

没有使用任何仓库 Secrets，也不需要数据库、API Key 或外部服务器。
