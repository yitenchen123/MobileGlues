# MobileGlues —— iOS 分支

这是 [MobileGlues](https://github.com/MobileGL-Dev/MobileGlues) 的 iOS 移植分支，
用于 [Air2](https://github.com/Air-Devs/Air2) 启动器的渲染器插件。

---

## 为什么有这个 fork

MobileGlues 的 CMake **已经支持 iOS**（`if(MACOS)` 分支里链接 Metal 框架），
但没有 iOS 的构建脚本与插件打包流程。

本 fork 只加了**构建与打包**，**没有改动任何渲染逻辑**：

| 新增 | 说明 |
|---|---|
| `build-ios.sh` | 用 iphoneos SDK 编译出 arm64 的 `.dylib` |
| `plugin/manifest.json` | Air2 插件描述（格式见下方规范） |
| `.github/workflows/build-ios.yml` | macOS runner 自动构建 |

**渲染核心代码（`MobileGlues-cpp/`）与原仓库完全一致**，
上游更新后可以直接 merge。

---

## 构建

### 本地（需 macOS + Xcode）

```bash
chmod +x build-ios.sh
./build-ios.sh --package
```

产出：
- `plugin/libs/libMobileGlues.dylib` —— arm64 动态库
- `MobileGlues.air2plugin` —— 可直接导入 Air2 的插件包

**脚本会自动做 ad-hoc 签名**（`codesign -f -s -`），
这样 TrollStore / 越狱环境下导入即可用。

### CI

推送后 GitHub Actions 自动构建，产物在 Actions → Artifacts：
- `libMobileGlues-ios` —— 单独的 dylib
- `MobileGlues-air2plugin` —— 插件包

---

## 在 Air2 中使用

```
Air2 → 设置 → 渲染 → 渲染器插件 → 导入插件包
     → 选 MobileGlues.air2plugin
     → 渲染器列表里出现「MobileGlues」
```

**签名说明**：

| 环境 | 能否直接加载 |
|---|---|
| TrollStore | ✅ 可以（ad-hoc 签名即可） |
| 越狱 | ✅ 可以 |
| 正规签名 | ❌ 需要与 Air2 同签名 → 见下方 |

**正规签名环境**：用下面的方式把它编进 Air2 再一起签名，

```bash
# 把 dylib 放进 ipa 并重签
unzip Air2.ipa -d work
cp plugin/libs/libMobileGlues.dylib work/Payload/Air2.app/Frameworks/
codesign -f -s "$IDENTITY" work/Payload/Air2.app/Frameworks/libMobileGlues.dylib
codesign -f -s "$IDENTITY" --deep work/Payload/Air2.app
cd work && zip -r ../Air2-mg.ipa Payload
```

---

## 插件 manifest

```json
{
  "formatVersion": 1,
  "rendererId": "com.airdevs.mobileglues",
  "displayName": "MobileGlues",
  "rendererGLPath": "libs/libMobileGlues.dylib",
  "rendererEGLPath": "libs/libMobileGlues.dylib",
  "minMCVer": "1.17",
  "env": [
    { "type": "ToggleableEnv", "key": "MG_DEBUG", "value": "1",
      "title": "调试日志", "toggle": false },
    { "type": "SelectableEnv", "key": "MG_PRECISION", "title": "着色器精度",
      "items": { "defaultValue": "highp", "values": [...] } },
    { "type": "CustomizableEnv", "key": "MG_SHADER_CACHE_SIZE",
      "title": "着色器缓存大小", "defaultValue": "512M" }
  ]
}
```

完整规范见 Air2 仓库的
[`docs/RENDERER_PLUGIN_SPEC.md`](https://github.com/Air-Devs/Air2/blob/main/docs/RENDERER_PLUGIN_SPEC.md)。

**`env` 格式与 FCL 的 v2 插件格式完全兼容** —— 如果你有 FCL 的插件配置，
字段可以直接搬过来。

---

## 关于环境变量

`env` 里声明的是**用户可配置项**，Air2 会在设置页自动生成对应控件：

| type | 控件 |
|---|---|
| `NormalEnv` | 无（固定值） |
| `ToggleableEnv` | 开关 |
| `SelectableEnv` | 单选 |
| `CustomizableEnv` | 输入框 |

用户在 UI 里改的值会存起来，启动游戏时拼成环境变量 `setenv` 进去。

---

## 许可

**LGPL-2.1**（与原仓库一致）

这意味着：如果你修改了 MobileGlues 的源码并分发，
**必须开源你的修改**。作为启动器插件分发不影响 Air2 本身的许可（GPL-3.0）。

---

## 上游

- 原仓库：https://github.com/MobileGL-Dev/MobileGlues
- 发行版：https://github.com/MobileGL-Dev/MobileGlues-release
