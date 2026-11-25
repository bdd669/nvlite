# NVLITE

一个把 NVIDIA 驱动包拆开、只留驱动的批处理脚本。

把官方驱动 `.exe` 拖到它上面，得到一个比全量解压小 700 MB 左右的文件夹，里面是驱动、
安装程序和必要文件，没有别的东西。

[English](README.en.md)

> **这个项目的代码是 AI 写的。** 测过什么、没测过什么、有哪些风险，都写在
> [DISCLAIMER.md](DISCLAIMER.md) 里。用之前建议看一眼。

---

## 为什么写这个

NVIDIA 的驱动包越做越大，里面塞了 App、遥测、自动更新器、截图工具，大部分人从来不碰。
官方安装方式里也没有"只装驱动"这个选项——自定义安装能去掉一部分，但去不干净。

这个脚本做的事很简单：按白名单解压，其余的连解压都不解压。

它不改驱动本身。输出文件夹里每个文件都是 NVIDIA 原包里的原始签名文件，一个字节没动。

## 用法

1. 把官方 NVIDIA 驱动 `.exe` 拖到 `NVLITE.bat` 上
2. 等一两分钟
3. 打开它生成的文件夹（名字类似 `621.40-Desktop-Win11`）
4. 双击里面的 `Setup.exe`

第 4 步还有个省事的选择：右键 `Install_Silent.bat`，以管理员身份运行。结果一样，不用点
下一步，但出问题时你只能看到一个退出码，没有对话框。我一般还是用 `Setup.exe`。

驱动包是 7-Zip 自解压格式，所以需要装下面任意一个：

- **NanaZip** — `NanaZipC.exe`（已测试）
- **7-Zip** — `7z.exe`、`7za.exe`、`7zz.exe`、`7zr.exe`
- **Bandizip** — `bz.exe`
- **WinRAR** — `WinRAR.exe`

只认命令行版本。Windows 自带的右键"全部解压缩"读不了这个格式。脚本会依次在脚本所在
目录、常见安装位置、`PATH` 里找。都找不到就往脚本顶部 `ZMANUAL` 里填一个完整路径。

## 保留什么

```
Display.Driver      驱动本体，加上控制面板依赖的服务
NVI2                安装器引擎，没有它 Setup.exe 打不开
setup.exe           安装入口
setup.cfg           安装配置
ListDevices.txt     设备列表
EULA.txt            许可文本
PhysX               物理引擎        （可选，见配置）
HDAudio             HDMI/DP 音频     （可选，见配置）
```

## 丢掉什么

解压范围就上面那几项，所以下面这些根本没有被解压出来：

- NVIDIA App / GeForce Experience
- NVIDIA App 依赖的后台容器服务
- 遥测
- 自动更新器
- Ansel

另外还有一步过滤：删掉 `setup.cfg` 里指向许可协议网页的声明。那些网页在 NVIDIA App 的
目录里，我们不解压它，留着这些声明会让安装器去找不存在的文件然后失败。

## 配置

脚本顶部三个变量：

```bat
set "REQ=Display.Driver NVI2 setup.exe setup.cfg ListDevices.txt"
set "EXTRA=PhysX HDAudio EULA.txt"
set "DROP="
set "DROPDIR="
```

想再省点空间就改 `EXTRA`。去掉 `PhysX` 省约 50 MB（只有少数老游戏用 GPU 物理）。去掉
`HDAudio` 省约 20 MB（只有用显示器或电视喇叭出声才需要，耳机和桌面音箱不走这个）。

**`DROP` 和 `DROPDIR` 保持空。** 我试过删 `Display.Driver` 里的文件，不行。删掉
`NvCamera` 之后安装器在"系统"检查阶段直接报"所需文件丢失"，装不下去。具体过程写在
[docs/technical-notes-zh.md](docs/technical-notes-zh.md)。

## 关于控制面板

从驱动 `32.0.16.1060`（大约 610 系）开始，NVIDIA 不再把经典控制面板打包进驱动了，
它变成了 NVIDIA App 的一个子组件。

所以在新驱动上用这个脚本，装完是没有控制面板的。两个选择：

1. 装完驱动后去 Microsoft Store 装 **NVIDIA Control Panel**，那是独立应用，不需要
   NVIDIA App
2. 需要 App 的话就用官方完整包

第 1 个方案我自己还没试过。它依赖的容器服务 `Display.NvContainer` 在 `Display.Driver`
里面，会被解压出来，理论上能用，但我不能保证。

610 之前的驱动不受影响，控制面板还在包里，这一节可以直接跳过。

## 笔记本

别用。`NVPCF` 没有被解压，Dynamic Boost 可能失效，插电玩游戏会比以前慢一些。
笔记本直接用官方包。

## 其他几个可能会问的

- **会不会掉帧或者不稳？** 驱动文件是 NVIDIA 没动过的二进制。自己验证：
  ```powershell
  (Get-AuthenticodeSignature C:\Windows\System32\drivers\nvlddmkm.sys).Status
  ```
  显示 `Valid` 就是原厂签名的文件。

- **会被反作弊封吗？** 反作弊查的是驱动签名和运行中的服务。签名完整，而且这个脚本是
  少装一个服务（遥测），不是多装。

- **会不会删我的文件？** 输出文件夹名是固定的，脚本只删它自己创建的目录——判断依据是
  目录里有没有 `nvlite_log.txt`。如果有同名目录但没有这个标记，它会停下来让你自己改名
  或删除。

- **怎么更新驱动？** 下载新包再拖一次。没有自动更新器，这是故意的。

- **只支持 `.exe`**，不支持 `.zip`。

- **路径限制**：驱动包路径不能带圆括号。`for /f` 解析 `('...')` 里的命令时，括号会提前
  结束循环头。空格、中文、`&`、`!` 都没问题。

## 实测过的

| 驱动版本 | 包 | 结果 |
|---|---|---|
| 621.24 | 桌面版，991 MiB | 生成、安装、驱动生效 |
| 621.40 | 桌面版，988 MiB | 生成、安装、驱动生效 |

Windows 11 x64，解压器用 NanaZip（Microsoft Store 版）。Bandizip 和 WinRAR 的支持代码
写了但没测过，如果这两个失败就用 NanaZip。

## 许可

MIT，见 [LICENSE](LICENSE)。

与 NVIDIA 无关。NVIDIA、GeForce 及相关标识是 NVIDIA Corporation 的商标。

## 给接手维护的人

这个项目的约定、状态、待办和历史决策，见 [`AGENTS.md`](AGENTS.md) 和 [`HANDOFF.md`](HANDOFF.md)。
