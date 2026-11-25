# 技术说明

这份文档记录 NVLITE 的实现细节和踩过的坑，给想改代码或者想确认它到底做了什么的人看。

代码由 AI 生成，测试范围和风险另见 [DISCLAIMER.md](../DISCLAIMER.md)。

## 设计约定

改代码前先读这四条。每一条都是踩过坑之后定下来的。

**1. 全程不用延迟展开。**

所有变量一律 `%VAR%`，脚本开头显式 `setlocal DisableDelayedExpansion`。

为什么：开着延迟展开时，路径里的 `!` 会被当成变量标记吃掉。一个叫 `我的!备份` 的文件夹
就能让脚本找不到文件，而且报错信息完全看不出原因。

代价：括号块内不能"赋值后立刻读自己刚写的值"。所以脚本刻意不在块内回读，改用独立行或
`goto` 结构。

**2. 括号块内不出现裸的 echo 路径变量。**

路径含右括号时，`if ... ( echo %OUT% )` 会在 `)` 处把块截断，后面的语法全乱。

要么加引号（引号内的括号是字面量），要么改成 `goto` 跳转。

**3. `rem` 注释里不写尖括号、竖线、和号。**

cmd 会把它们当重定向符或命令分隔符。`rem 支持 WinRAR > 7-Zip` 这一行会真的创建一个名叫
`7-Zip` 的文件。

**4. 删除逻辑必须内联，不能提取成 `call :sub`。**

这条最反直觉。把删除循环提取成子程序后，实测删除数量从 312 变成 0，屏幕上完全看不出异常。
原因不明，但现象稳定复现。所以删除相关的代码老老实实写在原地。

## 编码

源文件是 **GBK + CRLF**。

- UTF-8 保存会导致中文全部乱码
- LF 换行会导致 `goto` 标签和 `if` 块解析异常
- 仓库里的 `.gitattributes` 固定了 `*.bat text eol=crlf`

`Install_Silent.bat` 生成时跟随系统默认码页，不要给它加 `chcp 65001`——主脚本输出的是
GBK 字节，切成 UTF-8 只会让中文注释变乱码。

## 变量展开的几个坑

### `for` 的 DO 子句只解析一次

```bat
rem 错：多个缺失项会互相覆盖，只报最后一个
set "MISS="
for %%F in (a b c) do if not exist "%%F" set "MISS=%MISS% %%F"

rem 对：一行一个
set "MISS="
if not exist "a" set "MISS=%MISS% a"
if not exist "b" set "MISS=%MISS% b"
if not exist "c" set "MISS=%MISS% c"
```

### `findstr /b` 匹配的是行首

```bat
rem 错：echo 输出以引号开头，永远不匹配，提取逻辑从不执行
echo "!FN!" | findstr /b /c:"-" >nul && for /f "delims=-" %%A in ("!FN!") do set "VER=%%A"

rem 对：直接 for /f。没有连字符时 delims 不分割，取整串
for /f "delims=-" %%A in ("%FN%") do set "VER=%%A"
```

这个 bug 存活了好几个版本，表现是输出文件夹名变成
`621.40-desktop-win10-win11-64bit-international-nsd-dch-whql-Desktop-Win11`。

### `for %%F in ()` 是语法错误

配置项清空后必须加守卫：

```bat
if not defined DROP goto :skip
for %%F in (%DROP%) do ...
:skip
```

### `setlocal` 会继承外部状态

只写 `setlocal` 不带参数时，会沿用父环境的延迟展开设置。所以必须写
`setlocal DisableDelayedExpansion`。

## 为什么不能删 Display.Driver 内部的文件

**实测证据**：v4.1 把 `DROPDIR` 设成 `NvCamera`，621.40 安装时在"系统"检查阶段报
"所需文件丢失"，安装器直接中止。v4.2 清空后，同一个包安装正常。

`Display.Driver` 下只有 5 个子目录，一个都不能删：

| 目录 | 作用 | 删了会怎样 |
|---|---|---|
| `NvCamera` | Ansel 游戏内截图 | 实测装不上 |
| `NVCPL` | 经典控制面板本体 | 面板打不开 |
| `Display.NvContainer` | 控制面板依赖的后台服务 | 面板打不开 |
| `ngx-builtins` | DLSS 依赖 | 开 DLSS 的游戏出问题 |
| `NVWMI` | IT 管理用的 WMI 接口 | 能装，但 HWiNFO 读不到显卡温度 |

参考：NVCleanstall 这类工具走的是**组件级**删除（改安装配置让安装器不装某个组件），
不是删驱动目录里的文件。它对 Ansel 的处理是**禁用**——用 `NvCameraConfiguration` 工具，
不是删目录。

结论：想省空间只能改 `EXTRA` 那行。

## 关于 setup.cfg 过滤

脚本用 `findstr /v` 删掉包含 `EulaHtmlFile` / `FunctionalConsentFile` / `PrivacyPolicyFile`
这三个字符串的所有行。

在 621.x 上实际删掉 79 行（89361 → 77694 字节）：

- 三个变量定义本身
- 三个拼好路径的变量（`EulaHtmlFileFullPath` 等）
- 30 种语言的 `EULAandPrivacyPolicyText`（value 里含 `EulaHtmlFile` 子串，被一并命中）
- 两个 UI 控件定义（`eulaBoxWithNvApp`、`eulaLink`）
- `<manifest>` 段的三个 `<file>` 声明

**为什么必须删**：这些变量指向 `NvApp\Unified_EULA\*.html`，而 `NvApp` 目录不会被解压。
不删的话安装器会去找不存在的文件。

**副作用**：引用它们的界面文字被一并删掉，许可页可能显示不全。但实测双击 `Setup.exe`
在两个驱动版本上都能正常装完，没有阻碍。

**保护**：过滤结果为空时绝不覆盖原文件，否则 `Setup.exe` 直接报错。覆盖失败会打警告。

`setup.cfg` 里的 `<setup version="621.24">` **不代表驱动包版本**。621.40 的 setup.cfg
与 621.24 的字节完全相同（md5 一致），NVIDIA 没更新这个属性。判断版本要看文件名和 md5。

## 安装参数

`setup.cfg` 的 `<options>` 段定义了官方支持的参数：

```xml
<bool name="enableTelemetry" property="EnableTelemetry"/>
<bool name="clean" property="CleanInstall"/>
<bool name="forcereboot" property="RebootRequired"/>
<bool name="noreboot" property="IgnoreReboot"/>
<bool name="passive" property="ProgressOnly"/>
<bool name="noeula" property="SkipEula"/>
<bool name="nofinish" property="SkipFinish"/>
<bool name="ignorepnp" property="IgnorePnpFlag"/>
<bool name="nosplash" property="NoSplashScreen"/>
```

生成的 `Install_Silent.bat` 用 `Setup.exe -s -noeula -noreboot -nofinish`。

**注意**：这些参数只在安装流程层面生效（跳过页面、静默运行），管不了安装器启动时的文件
自检。所以"用静默脚本绕过文件缺失"这个思路是错的——v4.1 那次失败加 `-noeula` 也救不了。

## 解压器支持

NVIDIA 的包是 7-Zip 自解压格式，所以只认能读 7z 的命令行工具。

| 工具 | 程序 | 语法 |
|---|---|---|
| NanaZip | `NanaZipC.exe` | 7z |
| 7-Zip | `7z.exe` / `7za.exe` / `7zz.exe` / `7zr.exe` | 7z |
| Bandizip | `bz.exe` | bz |
| WinRAR | `WinRAR.exe` | rar |

三种语法差异：

```bat
rem 7z 系
"%Z%" x "%P%" -o"%OUT%" %REQ% %EXTRA% -aoa -mmt=%TH%

rem Bandizip：参数顺序不同，没有 -mmt
"%Z%" x -y -o:"%OUT%" "%P%" %REQ% %EXTRA%

rem WinRAR：目标目录放最后且不带 -o，-ibck 后台运行不弹窗
"%Z%" x -y -ibck "%P%" %REQ% %EXTRA% "%OUT%"
```

查找顺序：`ZMANUAL` 手动指定 → 脚本同目录 → 常见安装位置 → `PATH`。

用 `goto` 分派而不是 `if/else` 嵌套，每种分支里单独取 `errorlevel`，避免跳转干扰取值时机。

不支持的：Windows 自带 `tar`/`expand`（读不了 7z）、各类 GUI 版（没有稳定命令行接口）。

## 版本演进

| 版本 | 行数 | 说明 |
|---|---|---|
| 最初版本 | 67 | 只认 7-Zip，双击闪退，出错无提示 |
| v1.0.2 | 300 | 堆功能。其中"删老系统目录"占 65 行，但实测匹配 0 个 |
| v2.0 | 181 | 砍掉空操作和过度设计 |
| v3.1.1 | 178 | 含 2 个静默失效的 bug |
| v4.2 | 232 | 修掉 4 个 bug，真机验证通过 |
| v4.3 | 236 | 稳定性加固 |
| v4.4 | 285 | 解压器支持扩展 |

**一个教训**：为了把行数从 300 压到 165，把校验逻辑塞进 `for` 循环，直接埋了
`%MISS%` 被覆盖的 bug。从那以后不再追求行数少——每一行都得能说清为什么存在。

## 实测记录

### 621.24 桌面版（2026-11-22）

生成正常，安装正常。结果页显示 PhysX 9.26.0904 / HD 音频 1.4.6.6 / 图形驱动 621.24
三项都是"已安装"。

### 621.40 桌面版（2026-11-25）

- v4.1（删 NvCamera）→ 安装失败，"所需文件丢失"
- v4.2（清空 DROPDIR）→ 安装正常
- 包内已不含 `nvdrsdb0.bin` / `nvdrsdb1.bin`，所以 `DROP` 默认为空

## 待验证

- Bandizip `bz.exe` 和 WinRAR 能否解开 NVIDIA 的 SFX 包
- 笔记本场景（NVPCF / Optimus 缺失后 Dynamic Boost 的实际影响）
- 610+ 驱动上用 Microsoft Store 版控制面板搭配精简驱动是否可行
- `Install_Silent.bat` 的静默安装路径（目前一直用 `Setup.exe` 手动装）
