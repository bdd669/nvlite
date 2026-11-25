# NVLITE

**从 NVIDIA 官方驱动包里只提取你需要的部分。**

NVLITE 是一个单文件 Windows 批处理脚本。把官方驱动 `.exe` 拖到它上面，
它会生成一个精简过的安装文件夹 —— 没有 NVIDIA App，没有遥测，没有自动更新器。

```
官方包 988 MB  →  全量解压 3.8 GB  →  NVLITE 留下约 3.1 GB 的干净安装源
```

[English](README.md)

---

## 它到底做什么

它**不是**驱动安装器。它解压驱动包，只保留白名单里的条目。

| 步骤 | 动作 |
|---|---|
| 1 | 接收驱动包 `.exe`（拖放，或粘贴路径） |
| 2 | 查找解压器：NanaZip → 7-Zip → Bandizip |
| 3 | **只解压白名单**，其余内容一个字节都不解压 |
| 4 | 校验必需文件是否齐全 |
| 5 | 过滤 `setup.cfg`，去掉指向未解压文件的同意页声明 |
| 6 | 生成 `Install_Silent.bat` 用于无人值守安装 |
| 7 | 写出 `nvlite_log.txt` 解压日志 |

核心就是**一条 `7z x` 命令**，其余都是保护性检查。

## 保留什么

```
Display.Driver    显卡驱动 + NVIDIA 控制面板
NVI2              安装器引擎（没有它 Setup.exe 打不开）
setup.exe         安装入口
setup.cfg         安装配置
ListDevices.txt   设备列表
EULA.txt          许可文本（可选，部分驱动包不带）
PhysX             物理引擎        （可选，见配置）
HDAudio           HDMI/DP 音频     （可选，见配置）
```

## 丢掉什么

| 丢掉的东西 | 你损失什么 |
|---|---|
| NVIDIA App / GeForce Experience | 录屏、游戏滤镜、自动优化、游戏内覆盖层 |
| NvContainer 后台服务 | NVIDIA App 运行所需（控制面板不受影响） |
| 遥测组件 | 不再向 NVIDIA 上报硬件信息 |
| 自动更新器 | 不会静默推送新驱动 |
| Ansel 目录 | 游戏内截图工具 |
| NVPCF / Display.Optimus（笔记本） | Dynamic Boost、旧式双显卡切换 |
| PPC / USB-C 驱动 | 显卡 USB-C 口的显示输出 |

## 环境要求

- Windows 10 / 11 x64
- 以下任一：**NanaZip**（推荐）、**7-Zip**、**Bandizip**

脚本查找命令行版本：`NanaZipC.exe`、`7z.exe`/`7za.exe`/`7zz.exe` 或 `bz.exe`。
GUI 版本（`NanaZip.exe`、`7zG.exe`、`Bandizip.exe`）**不支持** —— 没有可用的命令行接口。

也可以把 `NanaZipC.exe` 直接放到脚本旁边。

## 用法

```
1. 把官方 NVIDIA 驱动包 .exe 拖到 NVLITE.bat 上
2. 等 1-2 分钟
3. 打开生成的文件夹（比如 621.40-Desktop-Win11）
4. 装驱动，两种方式都行：
   - 双击 Setup.exe 按提示点下一步（推荐，出错有图形界面提示）
   - 或右键 Install_Silent.bat → 以管理员身份运行（全自动）
```

## 配置

脚本顶部三个变量控制保留多少内容：

```bat
rem 必需项，不要动
set "REQ=Display.Driver NVI2 setup.exe setup.cfg ListDevices.txt"

rem 额外组件 —— 不需要哪个就删掉对应词
rem   PhysX    约 50MB，只有少数老游戏用 GPU 物理
rem   HDAudio  约 20MB，只有用显示器/电视喇叭出声才需要
set "EXTRA=PhysX HDAudio EULA.txt"

rem 解压后删除。保持为空。
set "DROP="
set "DROPDIR="
```

**不要填 `DROP` / `DROPDIR`。** 删除 `Display.Driver` 内部的文件会破坏安装器：
删掉 `NvCamera` 会导致 *"所需文件丢失"*，安装在该死的系统检查阶段中止。
完整调查过程见 [docs/technical-notes-zh.md](docs/technical-notes-zh.md)。

## 适用范围 —— 用之前请读

### 适合

- 台式机 + 独立 NVIDIA 显卡（GTX 10 系及更新）
- 只想要驱动本体，不需要 NVIDIA 全家桶
- 想避开遥测和自动更新
- 想省磁盘空间

### 不建议

- **笔记本。** `NVPCF` 没有被提取，Dynamic Boost 可能失效，高负载时游戏帧数可能略降。
  笔记本请直接用官方包。
- 需要 GeForce Experience 功能（录屏、滤镜、自动优化）
- 依赖 `NVWMI` 的 Quadro / IT 管理场景

## 常见问题

**会不会掉帧、卡顿、不稳定？**
不会。驱动文件是 NVIDIA 原厂签名的二进制，一个字节没改。自己验证：

```powershell
(Get-AuthenticodeSignature C:\Windows\System32\drivers\nvlddmkm.sys).Status
```

显示 `Valid` 就是官方原件。

**会被反作弊标记吗？**
不会。反作弊检查驱动签名和运行中的服务。签名完整，而且 NVLITE 是**移除**服务
（遥测），不是添加。

**NVIDIA 控制面板打不开。**
后台容器服务没有安装。去 Microsoft Store 安装 "NVIDIA Control Panel"，
或使用经典控制面板包。

**怎么更新驱动？**
下载新的官方包，再拖一次脚本。没有自动更新器 —— 这正是目的。

**会删我的文件吗？**
不会。输出文件夹名是确定的（`<版本号>-Desktop-Win11` 或 `-Laptops-Win11`），
脚本只删自己创建的目录，靠目录里的 `nvlite_log.txt` 识别。
如果同名目录已存在但没有这个标记，脚本会停下让你手动改名或删除。

## 已验证

| 驱动版本 | 包 | 结果 |
|---|---|---|
| 621.24 | 桌面版，991 MiB | 生成、安装、驱动生效 |
| 621.40 | 桌面版，988 MiB | 生成、安装、驱动生效 |

测试环境：Windows 11 x64，解压器 NanaZip（Microsoft Store 版）。

## 已知限制

- 驱动包路径**不能含圆括号**，因为 `for /f` 解析 `('...')` 里的命令，
  括号会提前结束循环头。空格、中文、`&`、`!` 都没问题。
- Bandizip 的 `bz.exe` 对 NVIDIA 自解压包的支持未验证。
- 只接受 `.exe` 驱动包，不支持 `.zip`。

## 许可

MIT —— 见 [LICENSE](LICENSE)。

与 NVIDIA 无关联。NVIDIA、GeForce 及相关标识是 NVIDIA Corporation 的商标。
